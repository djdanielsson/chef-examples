---
source-path: cookbooks/nginx-multisite
---

# Migration Plan: nginx‑multisite

**TLDR**: This cookbook configures an **NGINX web server** with three virtual hosts (test.cluster.local, ci.cluster.local, status.cluster.local). It installs NGINX, hardens the host (fail2ban, UFW, SSH), generates per‑site SSL certificates, and creates site configuration files and symlinks.

## Service Type and Instances

**Service Type**: Web Server (NGINX)

**Configured Instances**:
- **test.cluster.local**: Primary web site for the test environment  
  - Location/Path: `/opt/server/test`  
  - Port/Socket: `80` (HTTP), `443` (HTTPS)  
  - Key Config: SSL enabled – cert `/etc/ssl/certs/test.cluster.local.crt`, key `/etc/ssl/private/test.cluster.local.key`
- **ci.cluster.local**: Continuous‑integration web interface  
  - Location/Path: `/opt/server/ci`  
  - Port/Socket: `80` (HTTP), `443` (HTTPS)  
  - Key Config: SSL enabled – cert `/etc/ssl/certs/ci.cluster.local.crt`, key `/etc/ssl/private/ci.cluster.local.key`
- **status.cluster.local**: System status dashboard  
  - Location/Path: `/opt/server/status`  
  - Port/Socket: `80` (HTTP), `443` (HTTPS)  
  - Key Config: SSL enabled – cert `/etc/ssl/certs/status.cluster.local.crt`, key `/etc/ssl/private/status.cluster.local.key`

All three sites are enabled via symlinks in `/etc/nginx/sites-enabled/`; the default NGINX site (`/etc/nginx/sites-enabled/default`) is removed.

## File Structure

**MANDATORY: Preserve this section from the original plan.**
```
Recipes:
cookbooks/nginx-multisite/recipes/default.rb
cookbooks/nginx-multisite/recipes/security.rb
cookbooks/nginx-multisite/recipes/nginx.rb
cookbooks/nginx-multisite/recipes/ssl.rb
cookbooks/nginx-multisite/recipes/sites.rb

Attributes:
cookbooks/nginx-multisite/attributes/default.rb

Templates:
cookbooks/nginx-multisite/templates/default/fail2ban.jail.local.erb
cookbooks/nginx-multisite/templates/default/nginx.conf.erb
cookbooks/nginx-multisite/templates/default/security.conf.erb
cookbooks/nginx-multisite/templates/default/site.conf.erb
cookbooks/nginx-multisite/templates/default/sysctl-security.conf.erb
```
*No custom resources or provider files are used in this cookbook.*

## Module Explanation

The cookbook runs in the exact order shown by the execution tree.

1. **default** (`cookbooks/nginx-multisite/recipes/default.rb`):
   - `include_recipe` `nginx-multisite::security`
   - `include_recipe` `nginx-multisite::nginx`
   - `include_recipe` `nginx-multisite::ssl`
   - `include_recipe` `nginx-multisite::sites`

2. **security** (`cookbooks/nginx-multisite/recipes/security.rb`):
   - `package` installs `fail2ban`, `ufw`, `openssh-server`
   - `service[fail2ban]` – enable & start
   - `template[/etc/fail2ban/jail.local]` – renders `fail2ban.jail.local.erb` (mode `0644`)
   - `execute[ufw_default_deny]` – `ufw --force default deny`
   - `execute[ufw_allow_ssh]` – `ufw allow ssh`
   - `execute[ufw_allow_http]` – `ufw allow http`
   - `execute[ufw_allow_https]` – `ufw allow https`
   - `execute[ufw_enable]` – `ufw --force enable`
   - `template[/etc/sysctl.d/99-security.conf]` – renders `sysctl-security.conf.erb` (mode `0644`)
   - `execute[reload_sysctl]` – `sysctl -p /etc/sysctl.d/99-security.conf` (triggered by template)
   - `execute[disable root login]` – edits `/etc/ssh/sshd_config` to set `PermitRootLogin no`
   - `execute[disable password auth]` – edits `/etc/ssh/sshd_config` to set `PasswordAuthentication no`
   - `service[ssh]` – reload/restart when notified

3. **nginx** (`cookbooks/nginx-multisite/recipes/nginx.rb`):
   - `package[nginx]` – installs the `nginx` package
   - `template[/etc/nginx/nginx.conf]` – renders `nginx.conf.erb` (mode `0644`)
   - `template[/etc/nginx/conf.d/security.conf]` – renders `security.conf.erb` (mode `0644`)
   - `service[nginx]` – enable & start
   - `directory[/opt/server]` – creates base directory for document roots (mode `0755`)
   - `group[www-data]` – ensures `www-data` group exists (idempotent)
   - `cookbook_file[/opt/server/<site>/index.html]` – deploys a static `index.html` into each site’s document root (mode `0644`) for:
     - `test.cluster.local`
     - `ci.cluster.local`
     - `status.cluster.local`

4. **ssl** (`cookbooks/nginx-multisite/recipes/ssl.rb`):
   - `package` installs `openssl`
   - `group[ssl-cert]` – creates group `ssl-cert`
   - `directory[/etc/ssl/certs]` – creates certificates directory (mode `0755`)
   - `group[root]` – ensures `root` group exists
   - `directory[/etc/ssl/private]` – creates private‑key directory (mode `0710`, owned `root:ssl-cert`)
   - `group[ssl-cert]` – re‑ensures the group (idempotent)
   - `execute[generate-ssl-cert-test.cluster.local]` – generates self‑signed cert/key for **test.cluster.local**
   - `execute[generate-ssl-cert-ci.cluster.local]` – generates self‑signed cert/key for **ci.cluster.local**
   - `execute[generate-ssl-cert-status.cluster.local]` – generates self‑signed cert/key for **status.cluster.local**

5. **sites** (`cookbooks/nginx-multisite/recipes/sites.rb`):
   - **Site: test.cluster.local**
     - `template[/etc/nginx/sites-available/test.cluster.local]` – renders `site.conf.erb` with variables `server_name=test.cluster.local`, `document_root=/opt/server/test`, `ssl_enabled=true`, `cert_file=/etc/ssl/certs/test.cluster.local.crt`, `key_file=/etc/ssl/private/test.cluster.local.key` (mode `0644`)
     - `link[/etc/nginx/sites-enabled/test.cluster.local]` – creates symlink to the above file
   - **Site: ci.cluster.local**
     - `template[/etc/nginx/sites-available/ci.cluster.local]` – same variables adjusted for **ci.cluster.local**
     - `link[/etc/nginx/sites-enabled/ci.cluster.local]` – symlink
   - **Site: status.cluster.local**
     - `template[/etc/nginx/sites-available/status.cluster.local]` – same variables adjusted for **status.cluster.local**
     - `link[/etc/nginx/sites-enabled/status.cluster.local]` – symlink
   - After the loop:
     - `file[/etc/nginx/sites-enabled/default]` – deletes the default site (`action :delete`)

## Dependencies

- **External cookbook dependencies**: None (only standard Chef resources)
- **System package dependencies**: `nginx`, `fail2ban`, `ufw`, `openssh-server`, `openssl`
- **Service dependencies**: `nginx` (systemd), `fail2ban` (systemd), `ssh` (systemd), `ufw` (CLI firewall)

## Credentials

**Detection Summary**: 0 credentials detected across 0 files.

**Source**:
  - **Provider**: None detected
  - **URL**: N/A
  - **Path**: N/A

No credentials or secrets were detected in this cookbook. All configuration values appear to be non‑sensitive. SSL certificates are generated on‑the‑fly; private keys are stored in `/etc/ssl/private/` with permissions `0710` owned by `root:ssl-cert`.

## Checks for the Migration

**Files to verify**:
- `/etc/nginx/nginx.conf`
- `/etc/nginx/conf.d/security.conf`
- `/etc/nginx/sites-available/test.cluster.local`
- `/etc/nginx/sites-available/ci.cluster.local`
- `/etc/nginx/sites-available/status.cluster.local`
- `/etc/nginx/sites-enabled/test.cluster.local` → symlink
- `/etc/nginx/sites-enabled/ci.cluster.local` → symlink
- `/etc/nginx/sites-enabled/status.cluster.local` → symlink
- `/etc/nginx/sites-enabled/default` (should be absent)
- `/etc/ssl/certs/test.cluster.local.crt`
- `/etc/ssl/certs/ci.cluster.local.crt`
- `/etc/ssl/certs/status.cluster.local.crt`
- `/etc/ssl/private/test.cluster.local.key`
- `/etc/ssl/private/ci.cluster.local.key`
- `/etc/ssl/private/status.cluster.local.key`
- `/opt/server/test/index.html`
- `/opt/server/ci/index.html`
- `/opt/server/status/index.html`
- `/etc/fail2ban/jail.local`
- `/etc/sysctl.d/99-security.conf`

**Service endpoints to check**:
- HTTP `80` (all three sites)
- HTTPS `443` (all three sites)
- SSH `22` (hardening applied)
- UFW firewall rules for `ssh`, `http`, `https`

**Templates rendered**:
- `nginx.conf.erb` → `/etc/nginx/nginx.conf` (once)
- `security.conf.erb` → `/etc/nginx/conf.d/security.conf` (once)
- `site.conf.erb` → three times (once per site)
- `fail2ban.jail.local.erb` → `/etc/fail2ban/jail.local` (once)
- `sysctl-security.conf.erb` → `/etc/sysctl.d/99-security.conf` (once)

## Pre‑flight Checks:
```bash
# 1. Verify NGINX service
systemctl status nginx
ps aux | grep nginx

# 2. Verify security services
systemctl status fail2ban
ufw status verbose
sshd -T | grep PermitRootLogin   # should be "no"
sshd -T | grep PasswordAuthentication # should be "no"

# 3. Verify each site is reachable over HTTP and HTTPS
for site in test.cluster.local ci.cluster.local status.cluster.local; do
  echo "=== $site ==="
  curl -I http://$site/          # expect HTTP 200
  curl -kI https://$site/        # expect HTTPS 200 (self‑signed)
done

# 4. Verify SSL certificate files exist and have correct permissions
ls -l /etc/ssl/certs/*.crt
ls -l /etc/ssl/private/*.key
stat -c "%a %U %G" /etc/ssl/private/*.key   # should be 640 root:ssl-cert

# 5. Verify site configuration files
nginx -t   # should report configuration OK
grep server_name /etc/nginx/sites-available/test.cluster.local
grep ssl_certificate /etc/nginx/sites-available/ci.cluster.local
grep root /etc/nginx/sites-available/status.cluster.local

# 6. Verify document roots contain index.html
for dir in /opt/server/test /opt/server/ci /opt/server/status; do
  echo "Checking $dir"
  ls -l $dir/index.html
done

# 7. Verify firewall allows required ports
ufw status | grep -E "22|80|443"

# 8. Verify sysctl security settings applied
sysctl -a | grep -E "net.ipv4.ip_forward|kernel.randomize_va_space"
```