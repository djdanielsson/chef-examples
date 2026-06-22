# MIGRATION FROM CHEF TO ANSIBLE

**Executive Summary**
The repository contains three Chef cookbooks (`cache`, `fastapi-tutorial`, `nginx-multisite`) plus supporting Vagrant and solo configuration files. The goal is to replace the Chef‑based provisioning with Ansible playbooks and roles while preserving the same functionality (caching service, FastAPI application deployment, and multi‑site Nginx configuration). The migration effort is moderate: three distinct logical modules, each with its own set of attributes, templates, and resources. Estimated timeline is **4‑6 weeks** (1 week for discovery & design, 2‑3 weeks for implementation & testing, 1 week for documentation & hand‑over).

---

## Module Migration Plan

The repository contains Chef cookbooks that need to be migrated individually to Ansible roles.

### MODULE INVENTORY

| Module | Description | Path | Technology | Key Features |
|--------|-------------|------|------------|--------------|
| **cache** | Provides a caching service (likely Memcached or Redis) using community cookbooks (`memcached`, `redisio`). Installs the service, configures ports, and ensures it is running. | `cookbooks/cache` | Chef | Uses external community cookbooks, may include custom attributes for size, bind address, and persistence. |
| **fastapi-tutorial** | Deploys a Python FastAPI tutorial application. Installs Python, creates a virtual environment, installs dependencies, configures a systemd service, and optionally sets up a reverse proxy. | `cookbooks/fastapi-tutorial` | Chef | Uses `python` resources, templates for systemd unit, possibly a sample `requirements.txt`. |
| **nginx-multisite** | Configures Nginx to serve multiple virtual hosts. Includes attributes for site definitions, custom `nginx.conf` template, a custom resource `nginx_site` to create site configs, and SSL handling. | `cookbooks/nginx-multisite` | Chef | Multi‑site support, custom attributes, templates, resource abstraction, optional SSL certificate files. |

### Infrastructure Files

| File | Purpose | Migration Considerations |
|------|---------|--------------------------|
| `Berksfile` | Declares external Chef cookbooks (`nginx`, `memcached`, `redisio`). | Replace with Ansible Galaxy requirements (`requirements.yml`). |
| `Vagrantfile` | Defines a Vagrant VM for local testing. | Translate to an Ansible‑compatible Vagrant provisioning block or keep Vagrant and call Ansible via `provision`.
| `solo.json` / `solo.rb` | Chef Solo configuration (run‑list, cookbook paths). | Convert run‑list to an Ansible playbook that includes the new roles in the correct order.
| `vagrant-provision.sh` | Shell script used by Vagrant to invoke Chef Solo. | Replace with `ansible-playbook` command; ensure idempotent execution.

---

## Target Details

- **Operating System**: The cookbooks reference Linux packages (`memcached`, `redis`, `nginx`, `python3`). No explicit OS version is defined, but the Vagrant box used by the Vagrantfile is likely an Ubuntu/Debian or CentOS image. For the migration we will target **Ubuntu 22.04 LTS** (or the same base box used by Vagrant) unless the original `solo.rb` specifies otherwise.
- **Virtual Machine Technology**: Vagrant (VirtualBox/VMware). The migration will keep Vagrant for local development and use Ansible as the provisioner.
- **Cloud Platform**: Not specified. The playbooks will be cloud‑agnostic.

---

## Migration Approach

### Key Dependencies to Address

1. **External Chef Cookbooks** (`nginx`, `memcached`, `redisio`) – replace with Ansible Galaxy roles:
   - `geerlingguy.nginx`
   - `geerlingguy.memcached`
   - `geerlingguy.redis`
2. **Ruby‑based Chef resources** – translate to Ansible modules (`apt`, `yum`, `service`, `template`, `copy`, `systemd`).
3. **Attributes** – map Chef attribute files to Ansible role defaults (`defaults/main.yml`).
4. **Templates** – keep the existing ERB templates, convert to Jinja2 (`*.j2`).
5. **Custom Resource `nginx_site`** – implement as an Ansible task that creates a site config file from a template and enables it (symlink to `sites-enabled`).

### Security Considerations

- **Credentials / Secrets**: Review attribute files and templates for hard‑coded passwords, API keys, or SSL private keys. None were found in the repository, but verify during code review.
- **SSL Certificates**: If the `nginx-multisite` cookbook includes certificate files, store them in Ansible Vault and reference via `lookup('ansible.builtin.vault')`.
- **Privilege Escalation**: All roles will require `become: true`. Ensure sudo rights are limited to required commands.
- **Package Verification**: Use Ansible’s `apt`/`yum` with `state: present` and `allow_downgrade: false` to avoid unintended package versions.

### Technical Challenges

| Challenge | Description | Mitigation |
|-----------|-------------|-----------|
| **Custom Chef Resource (`nginx_site`)** | Chef’s custom resource abstracts site creation. Ansible does not have a direct equivalent. | Implement a reusable Ansible role (`nginx_site`) that renders a Jinja2 template and creates the symlink. Use `loop` for multiple sites. |
| **Attribute Merging Logic** | Chef attributes can be deep‑merged across environments. | Flatten attribute hierarchy into role defaults and vars; use `set_fact` if dynamic merging is required. |
| **External Cookbook Version Pinning** | Berksfile pins versions (`memcached ~> 6.0`, `redisio ~> 7.2.4`). | Mirror version constraints in `requirements.yml` for Ansible Galaxy roles, or pin specific role versions. |
| **Idempotency of Service Restarts** | Chef may restart services on every run. | Use Ansible’s `notify`/`handlers` pattern to restart only when configuration changes. |

### Migration Order

1. **Infrastructure Bootstrap** – Convert `Vagrantfile` + `vagrant-provision.sh` to run Ansible. Verify VM creation.
2. **Cache Role** – Migrate `cache` cookbook first (least dependencies). Test Memcached/Redis installation.
3. **Nginx‑Multisite Role** – Migrate next, leveraging the already‑available cache role if needed for upstream caching.
4. **FastAPI‑Tutorial Role** – Final, as it depends on Python, systemd, and the Nginx reverse proxy.
5. **Integration Playbook** – Assemble a top‑level playbook that includes the three roles in the correct order, mirroring the original Chef run‑list.

### Assumptions

- The repository does not contain any encrypted data bags or Chef Vault items.
- All external services (e.g., package repositories) are reachable from the Vagrant VM.
- No Windows‑specific resources are present; all cookbooks target Linux.
- The existing ERB templates are compatible with Jinja2 after minor syntax adjustments.
- The Vagrant base box is Ubuntu‑based; if it is CentOS/RHEL, the Ansible package manager tasks will be adjusted accordingly.
- No additional hidden files (e.g., `.chef` directories) contain secrets.

---

## Deliverables

1. **Ansible Galaxy `requirements.yml`** listing external roles.
2. **Three Ansible roles** (`cache`, `fastapi_tutorial`, `nginx_multisite`) with:
   - `defaults/main.yml` (converted attributes)
   - `tasks/main.yml`
   - `templates/*.j2`
   - `handlers/main.yml` for service reloads
3. **Top‑level playbook** (`site.yml`) that replicates the Chef run‑list.
4. **Updated Vagrantfile** that provisions the VM and runs `ansible-playbook`.
5. **Documentation** covering usage, variable reference, and vault integration.

---

*Prepared by the Migration Planning Agent.*