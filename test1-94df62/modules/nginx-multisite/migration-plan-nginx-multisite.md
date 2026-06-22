---
source-path: cookbooks/nginx-multisite
---

# Migration Plan: nginx‑multisite

**TLDR**: This cookbook configures an NGINX web server that hosts three TLS‑enabled virtual hosts – `test.cluster.local`, `ci.cluster.local` and `status.cluster.local`. It installs NGINX, hardens the host (fail2ban, UFW, SSH), creates self‑signed certificates for each site, deploys site‑specific document roots with a default `index.html`, and generates the required NGINX configuration files and symlinks.

## Service Type and Instances

**Service Type**: Web Server (NGINX)

**Configured Instances**:
- **test.cluster.local**: Primary web site for testing
  - Location/Path: `/opt/server/test`
  - Port/Socket: `443` (HTTPS) / `80` (HTTP)
  - Key Config: SSL certificate `/etc/ssl/certs/test.cluster.local.crt`, private key `/etc/ssl/private/test.cluster.local.key`
- **ci.cluster.local**: Continuous‑integration web interface
  - Location/Path: `/opt/server/ci`
  - Port/Socket: `443` (HTTPS) / `80` (HTTP)
  - Key Config: SSL certificate `/etc/ssl/certs/ci.cluster.local.crt`, private key `/etc/ssl/private/ci.cluster.local.key`
- **status.cluster.local**: System status dashboard
  - Location/Path: `/opt/server/status`
  - Port/Socket: `443` (HTTPS) / `80` (HTTP)
  - Key Config: SSL certificate `/etc/ssl/certs/status.cluster.local.crt`, private key `/etc/ssl/private/status.cluster.local.key`

## File Structure

**MANDATORY: Preserve this section from the original plan.**

```
**Recipes**
cookbooks/nginx-multisite/recipes/default.rb
cookbooks/nginx-multisite/recipes/security.rb
cookbooks/nginx-multisite/recipes/nginx.rb
cookbooks/nginx-multisite/recipes/ssl.rb
cookbooks/nginx-multisite/recipes/sites.rb

**Templates**
cookbooks/nginx-multisite/templates/default/nginx.conf.erb
cookbooks/nginx-multisite/templates/default/security.conf.erb
cookbooks/nginx-multisite/templates/default/site.conf.erb
cookbooks/nginx-multisite/templates/default/fail2ban.jail.local.erb
cookbooks/nginx-multisite/templates/default/sysctl-security.conf.erb

**Attributes**
cookbooks/nginx-multisite/attributes/default.rb
```

## Module Explanation

The cookbook performs operations in this order:

1. **default.rb** (`cookbooks/nginx-multisite/recipes/default.rb`):
   - Includes `security.rb`, `nginx.rb`, `ssl.rb`, then `sites.rb` in that exact sequence.

2. **security.rb** (`cookbooks/nginx-multisite/recipes/security.rb`):
   - Installs `fail2ban` package and enables the service.
   - Deploys `/etc/fail2ban/jail.local` from `fail2ban.jail.local.erb`.
   - Executes UFW commands to set default deny, allow SSH, HTTP, HTTPS, and enable the firewall.
   - Deploys `/etc/sysctl.d/99-security.conf` from `sysctl-security.conf.erb` and reloads sysctl.
   - Disables root login and password authentication in `/etc/ssh/sshd_config` and restarts SSH if changed.

3. **nginx.rb** (`cookbooks/nginx-multisite/recipes/nginx.rb`):
   - Installs `nginx` package.
   - Deploys `/etc/nginx/nginx.conf` from `nginx.conf.erb`.
   - Deploys `/etc/nginx/conf.d/security.conf` from `security.conf.erb`.
   - Enables and starts the `nginx` service.
   - **Loop over each site**:
     - `test.cluster.local`:
       - Creates directory `/opt/server/test` (mode `0755`).
       - Copies static `index.html` into `/opt/server/test/index.html`.
     - `ci.cluster.local`:
       - Creates directory `/opt/server/ci` (mode `0755`).
       - Copies static `index.html` into `/opt/server/ci/index.html`.
     - `status.cluster.local`:
       - Creates directory `/opt/server/status` (mode `0755`).
       - Copies static `index.html` into `/opt/server/status/index.html`.

4. **ssl.rb** (`cookbooks/nginx-multisite/recipes/ssl.rb`):
   - Installs `openssl` and `ca-certificates` packages.
   - Creates group `ssl-cert`.
   - Ensures directories `/etc/ssl/certs` (mode `0755`) and `/etc/ssl/private` (mode `0710`) exist.
   - **Loop over each site**:
     - `test.cluster.local`:
       - Executes `openssl req … -keyout /etc/ssl/private/test.cluster.local.key -out /etc/ssl/certs/test.cluster.local.crt …`.
       - Sets permissions `640` and ownership `root:ssl-cert` on the key file.
     - `ci.cluster.local`:
       - Executes analogous command for `ci.cluster.local`.
     - `status.cluster.local`:
       - Executes analogous command for `status.cluster.local`.

5. **sites.rb** (`cookbooks/nginx-multisite/recipes/sites.rb`):
   - **Loop over each site**:
     - `test.cluster.local`:
       - Renders `/etc/nginx/sites-available/test.cluster.local` from `site.conf.erb` with variables `server_name`, `document_root`, `ssl_enabled`, `cert_file`, `key_file`.
       - Creates symlink `/etc/nginx/sites-enabled/test.cluster.local` → `/etc/nginx/sites-available/test.cluster.local`.
     - `ci.cluster.local`:
       - Renders `/etc/nginx/sites-available/ci.cluster.local` and creates corresponding symlink.
     - `status.cluster.local`:
       - Renders `/etc/nginx/sites-available/status.cluster.local` and creates corresponding symlink.
   - Deletes default site file `/etc/nginx/sites-enabled/default`.

## Dependencies

- **External cookbook dependencies**: None (core Chef resources only)
- **System package dependencies**: `nginx`, `openssl`, `ca-certificates`, `fail2ban`, `ufw`
- **Service dependencies**: `nginx` (systemd), `fail2ban` (systemd), `ssh` (systemd), `ufw` (CLI)

## Credentials

**Detection Summary**: 0 credentials detected across 0 files.

No data bags, encrypted data bags, Chef Vault items, Conjur variables, or hard‑coded passwords/keys are present. The only secret‑like material is the self‑signed SSL private keys generated at runtime; they are stored on disk with permissions `640` and owned by `root:ssl-cert`.

## Checks for the Migration

**Files to verify**
- `/etc/nginx/nginx.conf`
- `/etc/nginx/conf.d/security.conf`
- `/etc/nginx/sites-available/test.cluster.local`
- `/etc/nginx/sites-available/ci.cluster.local`
- `/etc/nginx/sites-available/status.cluster.local`
- `/etc/nginx/sites-enabled/*` (symlinks for the three sites, default removed)
- `/etc/ssl/certs/test.cluster.local.crt`
- `/etc/ssl/certs/ci.cluster.local.crt`
- `/etc/ssl/certs/status.cluster.local.crt`
- `/etc/ssl/private/test.cluster.local.key`
- `/etc/ssl/private/ci.cluster.local.key`
- `/etc/ssl/private/status.cluster.local.key`
- Document roots: `/opt/server/test/index.html`, `/opt/server/ci/index.html`, `/opt/server/status/index.html`
- Fail2ban config: `/etc/fail2ban/jail.local`
- Sysctl security config: `/etc/sysctl.d/99-security.conf`

**Service endpoints to check**
- **NGINX HTTP** – port **80**
- **NGINX HTTPS** – port **443**
- **SSH** – port **22** (root login disabled, password auth disabled)
- **UFW** – ensure rules for `ssh`, `http`, `https` are present
- **Fail2ban** – service running, jail active

**Templates rendered**
| Template | Render Count |
|----------|--------------|
| `templates/default/nginx.conf.erb` | 1 |
| `templates/default/security.conf.erb` | 1 |
| `templates/default/site.conf.erb` | 3 |
| `templates/default/fail2ban.jail.local.erb` | 1 |
| `templates/default/sysctl-security.conf.erb` | 1 |

## Pre‑flight checks:
```bash
# 1. Verify required packages are installed
dpkg -l | grep -E 'nginx|openssl|ca-certificates|fail2ban|ufw'

# 2. Verify groups exist
getent group ssl-cert
getent group www-data

# 3. Verify core directories and permissions
ls -ld /etc/nginx /etc/nginx/conf.d /etc/nginx/sites-available /etc/nginx/sites-enabled
ls -ld /etc/ssl/certs /etc/ssl/private
ls -ld /opt/server/test /opt/server/ci /opt/server/status

# 4. Verify SSL certificate and key files for each site
for site in test.cluster.local ci.cluster.local status.cluster.local; do
  echo "Checking $site certificate and key"
  test -f "/etc/ssl/certs/${site}.crt" && echo "  cert OK"
  test -f "/etc/ssl/private/${site}.key" && echo "  key OK"
  ls -l "/etc/ssl/private/${site}.key"
done

# 5. Verify service status
systemctl status nginx
systemctl status fail2ban
systemctl status ssh

# 6. Verify firewall rules (UFW)
ufw status verbose

# 7. Verify NGINX configuration syntax
nginx -t

# 8. Basic HTTP check (plain)
curl -I http://localhost/

# 9. HTTPS checks for each site (skip cert verification)
for site in test.cluster.local ci.cluster.local status.cluster.local; do
  echo "=== $site ==="
  curl -k -I https://$site/
done

# 10. Verify index.html content for each site
for site in test ci status; do
  echo "Content of /opt/server/${site}/index.html:"
  cat "/opt/server/${site}/index.html"
done

# 11. Verify Fail2ban is protecting SSH
fail2ban-client status sshd

# 12. Verify sysctl settings applied
sysctl -p /etc/sysctl.d/99-security.conf
```