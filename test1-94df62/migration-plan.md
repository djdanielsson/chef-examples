# MIGRATION FROM CHEF TO ANSIBLE

**Executive Summary**
The repository contains three lightweight Chef cookbooks (`cache`, `fastapi-tutorial`, `nginx-multisite`) used for provisioning a Vagrant‑based development environment.  All cookbooks are small, contain only a handful of recipes and minimal attribute/template files, and there are no external secrets or complex platform‑specific resources.  Consequently the migration effort is expected to be **low‑complexity** and can be completed within **2 weeks** (analysis, conversion, testing, documentation).  The plan below details each module, its purpose, dependencies, security considerations, and a recommended migration order.

---

## Module Migration Plan

The repository contains the following Chef cookbooks that need to be migrated to Ansible roles/playbooks:

### MODULE INVENTORY

| Module | Description | Path | Technology | Key Features |
|--------|-------------|------|------------|--------------|
| **cache** | Simple cache server (likely a placeholder) – provides a default recipe that could install a caching package (e.g., `memcached` or `redis`). No attributes, templates, or resources are defined. | `cookbooks/cache` | Chef | Minimal default recipe only |
| **fastapi-tutorial** | Sets up a Python FastAPI application for tutorial purposes. Includes metadata, default recipe, and placeholder attribute/template directories. Intended to install Python, create a virtual environment, and run the FastAPI service. | `cookbooks/fastapi-tutorial` | Chef | Python package installation, service setup (implicit) |
| **nginx-multisite** | Configures Nginx to serve multiple sites. Contains attributes, files, resources, templates, and recipes for site configuration. Likely creates site‑specific server blocks, manages SSL certificates, and reloads Nginx. | `cookbooks/nginx-multisite` | Chef | Multi‑site Nginx configuration, custom templates, resource definitions |

### Infrastructure Files

| File | Purpose | Migration Considerations |
|------|---------|--------------------------|
| `Berksfile` | Declares Chef cookbook dependencies (none listed). | Convert to Ansible Galaxy `requirements.yml` if external roles are needed. |
| `Vagrantfile` | Defines the Vagrant VM (base box, provisioning steps). | Translate to Ansible‑compatible Vagrant provisioning (`ansible.provisioner`) or use Ansible playbooks directly on the VM. |
| `solo.rb` / `solo.json` | Chef Solo configuration used by Vagrant provisioning. | Not required for Ansible; replace with Ansible inventory and variable files. |
| `vagrant-provision.sh` | Shell script executed by Vagrant to run Chef Solo. | Replace with Ansible command line (`ansible-playbook`) in Vagrant provisioner. |

---

## Target Details

- **Operating System**: The Vagrant box is not explicitly defined, but the cookbooks use generic package resources (`package`, `service`).  Assume a **Ubuntu 22.04 LTS** or **CentOS/RedHat 9** base.  The final Ansible playbooks will be written to be OS‑agnostic where possible, with conditional tasks for Debian‑based vs. RHEL‑based systems.
- **Virtual Machine Technology**: **Vagrant** (provider‑agnostic).  No specific hypervisor is indicated.
- **Cloud Platform**: None – the environment is local development only.

---

## Migration Approach

### Key Dependencies to Address

- **Berksfile** – currently empty.  If future dependencies are added, map each to an Ansible Galaxy role or a custom role.
- **Chef resources** – the `nginx-multisite` cookbook defines custom resources.  These will be replaced with Ansible modules (`ansible.builtin.template`, `ansible.builtin.service`, `community.general.nginx_site`).

### Security Considerations

- No encrypted data bags, vault usage, or hard‑coded credentials were found in the repository.
- All secrets (e.g., SSL certificates) appear to be referenced via files under `cookbooks/nginx-multisite/files`.  Ensure any private keys are stored securely (e.g., Ansible Vault) after migration.
- Review any future additions for credential handling and migrate them to Ansible Vault or environment‑variable based secrets.

### Technical Challenges

| Challenge | Description | Mitigation |
|-----------|-------------|------------|
| Custom Chef resources (`resources/` in `nginx-multisite`) | Direct equivalents do not exist in Ansible. | Re‑implement logic using Ansible modules and Jinja2 templates; encapsulate in a role. |
| OS‑specific package names | Chef abstracts package names; Ansible tasks must handle Debian vs. RHEL naming. | Use `ansible_os_family` facts to branch package installation. |
| Vagrant provisioning transition | Existing workflow runs a shell script that calls Chef Solo. | Update `Vagrantfile` to use `config.vm.provision "ansible"` with the generated playbook. |

### Migration Order

1. **cache** – Smallest, lowest risk. Convert the default recipe to an Ansible role that installs the chosen cache package.
2. **fastapi-tutorial** – Slightly more complex (Python environment, service). Convert to a role that installs Python, creates a virtualenv, installs dependencies, and configures a systemd service.
3. **nginx-multisite** – Highest complexity due to custom resources and multiple templates. Convert after the simpler roles are stable; use Ansible’s `template` and `nginx` community modules.

---

## Assumptions

- The cookbooks contain only the files listed; no hidden or external scripts are used.
- No external secrets are stored in the repository; any future secret handling will be addressed separately.
- The target environment will continue to be a Vagrant‑managed VM; if migration to a cloud provider occurs later, additional adjustments will be required.
- All package installations are available in the default OS repositories.
- The `Berksfile` will remain empty unless new dependencies are introduced.

---

## Coordination Guidance

1. **Team Assignment** – Allocate one engineer per cookbook to own the conversion, with a lead architect reviewing the final Ansible roles.
2. **Version Control** – Create a new branch `ansible-migration` and add Ansible roles under `roles/` mirroring the cookbook names.
3. **Testing** – Use the existing Vagrant box to spin up a VM, run the Ansible playbook, and compare the resulting system state with the Chef‑provisioned baseline.
4. **Documentation** – Update README with Ansible usage instructions, including how to provision via Vagrant.
5. **Secrets Management** – Introduce Ansible Vault early; store any future credentials there and document the vault password handling process.

---

*Prepared by the Migration Planning Agent*