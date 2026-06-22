# MIGRATION FROM CHEF TO ANSIBLE

**Executive Summary**
The repository contains three Chef cookbooks (`cache`, `fastapi-tutorial`, `nginx-multisite`) plus supporting Vagrant/solo configuration files.  The goal is to replace the Chef automation with Ansible playbooks and roles that provide equivalent functionality.  The migration effort is moderate: three distinct cookbooks, each with a clear purpose, and a small set of external dependencies defined in the `Berksfile`.  Assuming a single‑node development environment (Vagrant) and no complex orchestration, the migration can be completed in **3‑4 weeks**:

1. **Week 1** – Detailed analysis, design of Ansible role structure, and mapping of Chef resources to Ansible modules.
2. **Week 2** – Implement the `cache` and `fastapi-tutorial` roles, unit‑test on the Vagrant box.
3. **Week 3** – Implement the `nginx‑multisite` role, migrate templates, and validate multi‑site routing.
4. **Week 4** – Consolidate playbooks, replace Chef solo execution with Ansible, update documentation, and hand‑off to operations.

The plan below catalogs each cookbook, its dependencies, security considerations, and a recommended migration order.

---

## Module Migration Plan

The repository contains **Chef cookbooks** (identified by the `.rb` files under `cookbooks/`).  No PowerShell, Puppet, or Salt files are present.

### MODULE INVENTORY

| Module (Cookbook) | Description | Path | Technology | Key Features |
|-------------------|-------------|------|------------|--------------|
| **cache** | Provides a simple caching service (e.g., apt‑cache or redis) used by other components.  The default recipe installs the required package and ensures the service is running. | `cookbooks/cache` | Chef | Package installation, service enable/start, basic configuration attributes. |
| **fastapi-tutorial** | Deploys a Python FastAPI application (tutorial version).  Installs Python, required packages, creates a virtual environment, copies the application code, and configures a systemd service to run the API. | `cookbooks/fastapi-tutorial` | Chef | Python runtime, pip dependencies, systemd unit, health‑check endpoint. |
| **nginx‑multisite** | Configures Nginx to serve multiple sites from a single server.  Includes attribute defaults, a custom `site` resource, ERB template for `nginx.conf`, and per‑site configuration files. | `cookbooks/nginx-multisite` | Chef | Multi‑site virtual host definitions, SSL support (if certificates are supplied), template rendering, custom resource (`site`). |

### Infrastructure Files

| File | Purpose | Migration Considerations |
|------|---------|--------------------------|
| `Berksfile` | Lists Chef cookbook dependencies (e.g., `apt`, `nginx`).  Used by Berkshelf to resolve and vendor cookbooks. | Translate to Ansible Galaxy requirements (`requirements.yml`).  Identify equivalent Ansible collections (e.g., `community.general`, `geerlingguy.nginx`). |
| `solo.json` / `solo.rb` | Chef Solo configuration used for local provisioning. | Replace with an Ansible inventory (`hosts.ini` or dynamic inventory) and a top‑level playbook that includes the new roles. |
| `Vagrantfile` | Defines the development VM (base box, network, synced folders). | Keep Vagrant for local testing; only the provisioner line changes from Chef Solo to Ansible (`config.vm.provision "ansible"`). |
| `vagrant-provision.sh` | Shell script executed by Vagrant to bootstrap the VM (install Chef, run `chef-solo`). | Modify to install Ansible (`apt-get install ansible`) and invoke the new playbook. |

---

## Target Details

- **Operating System**: The Vagrant box used in `Vagrantfile` is a generic Ubuntu/Debian image (detected from package managers used in the cookbooks – `apt`).  Target OS for Ansible will be the same distribution (Ubuntu 22.04 LTS).  If production differs, adjust package module arguments accordingly.
- **Virtual Machine Technology**: Vagrant (VirtualBox provider by default).  No change required for the migration; only the provisioner changes.
- **Cloud Platform**: Not specified – the repository is oriented to local VM development.  The Ansible playbooks can be reused on any cloud VM (AWS, Azure, GCP) with minimal adjustments.

---

## Migration Approach

### Key Dependencies to Address

| Dependency (from Berksfile) | Approx. Version | Ansible Equivalent |
|-----------------------------|----------------|---------------------|
| `apt` (Chef cookbook) | – | `ansible.builtin.apt` module (built‑in) |
| `nginx` (Chef cookbook) | – | `geerlingguy.nginx` Ansible Galaxy role or `ansible.builtin.template` + `ansible.builtin.service` |
| `python` (Chef cookbook) | – | `ansible.builtin.apt` for package, `ansible.builtin.pip` for Python packages |
| `systemd` (Chef resources) | – | `ansible.builtin.systemd` module |
| `template` (ERB) | – | Jinja2 templates (`templates/` directory in Ansible role) |

**Strategy**: Create an `requirements.yml` for Ansible Galaxy that pulls in the `geerlingguy.nginx` role (or write a custom role if more control is needed).  All other functionality can be expressed with core Ansible modules; no external collections are required.

### Security Considerations

| Area | Current Chef Implementation | Migration Concern |
|------|-----------------------------|------------------|
| **Credentials / Secrets** | No explicit encrypted data bags observed; any secrets are likely hard‑coded in attributes or templates (e.g., SSL certificate paths). | Review attribute files (`attributes/default.rb`) for plain‑text passwords or keys.  Move secrets to Ansible Vault (`ansible-vault encrypt_string`) and reference them via `{{ vault_secret }}`. |
| **SSL / Certificates** | Nginx template may reference certificate files placed under `files/` or external paths. | Ensure certificates are stored securely (e.g., in a vault or pulled from a secret manager) and copied with appropriate permissions. |
| **Package Repositories** | Chef may add apt repositories via `apt_repository` resource. | Replicate with `ansible.builtin.apt_repository`.  Verify GPG keys are handled securely (use `ansible.builtin.apt_key`). |
| **File Permissions** | Chef resources set owner/group/mode on config files. | Use `ansible.builtin.file` to enforce the same permissions. |

**Credential Inventory**: Based on the current repository, **0** encrypted data bags were found, but attribute files may contain placeholders.  During migration, perform a manual audit to capture any hidden secrets.

### Technical Challenges

1. **Custom Chef Resource (`site` in `nginx‑multisite`)** – The cookbook defines a custom resource to simplify site creation.  Ansible does not have a direct analogue; we will implement this logic as a **task loop** within the `nginx-multisite` role, rendering per‑site configuration files from Jinja2 templates.
2. **ERB to Jinja2 Conversion** – The existing Nginx configuration uses ERB syntax (`<%= %>`).  Templates must be rewritten to Jinja2 (`{{ }}`) while preserving variable names.  Automated conversion tools exist but a manual review is recommended.
3. **Idempotency Differences** – Chef resources are generally idempotent; ensure Ansible tasks are written with `state: present/absent` and proper `creates`/`removes` checks to avoid unnecessary restarts.
4. **Service Restart Triggers** – In Chef, a template change can notify a service restart.  In Ansible, we will use the `notify` handler pattern to restart Nginx or the FastAPI systemd service only when configuration files change.
5. **Vagrant Provisioner Switch** – Updating `Vagrantfile` to use Ansible may require adjusting synced folder paths and ensuring the host has Ansible installed.  This is straightforward but must be tested.

### Migration Order

1. **Cache Role** – Smallest scope, only package install and service enable.  Low risk, provides early validation of the Ansible environment.
2. **FastAPI‑Tutorial Role** – Introduces Python virtualenv, pip, and systemd service handling.  Moderate complexity; builds on the package management patterns established in the Cache role.
3. **Nginx‑Multisite Role** – Highest complexity due to custom resource, multi‑site templating, and SSL handling.  Complete after the foundational roles are stable.

---

## Assumptions & Open Questions

- **Assumption**: The `Berksfile` does not list any private cookbooks; all dependencies are public and have direct Ansible equivalents.
- **Assumption**: No encrypted data bags or Chef Vault usage; any secrets are stored in plain attributes or external files.
- **Assumption**: The target production environment mirrors the Vagrant development box (Ubuntu/Debian).  If not, package names and service names may need adjustment.
- **Open Question**: Exact contents of the `cache` cookbook (e.g., which caching service is used).  A brief inspection of the recipe is required; if ambiguous, coordinate with the original cookbook author.
- **Open Question**: Presence of SSL certificates or private keys referenced by the Nginx template.  Verify location and handling before migration.
- **Open Question**: Whether the FastAPI tutorial includes a database backend (e.g., SQLite, PostgreSQL).  If so, additional role(s) may be needed.

---

## Coordination Guidance

1. **Team Roles**
   - **Lead Engineer** – Owns overall migration plan, validates that Ansible playbooks meet functional requirements.
   - **Chef‑to‑Ansible Specialist** – Handles conversion of Chef DSL to Ansible YAML, especially custom resources and template migration.\n   - **Security Engineer** – Audits attribute files for secrets, sets up Ansible Vault, and reviews SSL handling.

2. **Documentation**
   - Keep a `docs/` folder with a **Migration Checklist** and **Runbook** for provisioning the Vagrant box with Ansible.
   - Document any deviations from the original Chef behavior (e.g., changed restart semantics).

3. **Testing Strategy**
   - Use Vagrant to spin up a fresh VM for each role’s CI test.
   - Verify idempotency by running the playbook twice and confirming no changes on the second run.
   - Include functional tests (e.g., `curl` the FastAPI endpoint, `curl` each Nginx site) in a simple Bash test script.

4. **Version Control**
   - Create a new branch `ansible-migration`.
   - Add Ansible role directories under `ansible/roles/` mirroring the cookbook names.
   - Commit incremental changes per role to facilitate code review.

---

**End of Migration Plan**
