---
source-path: cookbooks/fastapi-tutorial
---

# Migration Plan: fastapi-tutorial

**TLDR**: This cookbook deploys a FastAPI tutorial web application. It installs required system packages, clones the source repository, creates a Python virtual environment, installs Python dependencies, configures a PostgreSQL database, writes an `.env` file with DB credentials, creates a systemd service unit for the FastAPI app, and ensures both PostgreSQL and the FastAPI service are enabled and started.

## Service Type and Instances

**Service Type**: Web Application (FastAPI) with a PostgreSQL backend database.

**Configured Instances**:
- **fastapi-tutorial.service** – FastAPI tutorial service running under systemd.
  - Location/Path: `/etc/systemd/system/fastapi-tutorial.service`
  - Port/Socket: `8000` (HTTP)
  - Key Config: Runs as `root`, uses virtual environment at `/opt/fastapi-tutorial/venv`, `ExecStart=/opt/fastapi-tutorial/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000`, `After=postgresql.service`.

- **postgresql** – PostgreSQL database service.
  - Location/Path: system service managed by OS package (default data directory `/var/lib/postgresql/...`)
  - Port/Socket: `5432`
  - Key Config: Database `fastapi_db` owned by user `fastapi`; user `fastapi` created with password `fastapi_password`.

- **System User / Group** – All resources run as the `root` user/group (as defined in the cookbook).

## File Structure

**MANDATORY: Preserve this section from the original plan.**
```
**Recipes:**
```
recipes/default.rb
```

**Providers:**
*(none – no custom resources are used)*

**Templates:**
*(none – all file contents are provided inline in the recipe)*

**Attributes:**
*(none – the cookbook does not define attribute files)*
```

## Module Explanation

The cookbook executes **only** `cookbooks/fastapi-tutorial/recipes/default.rb`.  
Resources are applied in the exact order shown below.

1. **Package Installation** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Installs system packages: `python3`, `python3-pip`, `python3-venv`, `git`, `postgresql`, `postgresql-contrib`, `libpq-dev`.

2. **Application Directory Creation** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Creates directory `/opt/fastapi-tutorial` owned by `root:root`, mode `0755`, recursive.

3. **Clone FastAPI Tutorial Repository** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Clones `https://github.com/dibanez/fastapi_tutorial.git` into `/opt/fastapi-tutorial` at revision `main`.

4. **Create Python Virtual Environment** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Executes `python3 -m venv /opt/fastapi-tutorial/venv` (creates `/opt/fastapi-tutorial/venv`).

5. **Install Python Dependencies** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Runs `/opt/fastapi-tutorial/venv/bin/pip install -r /opt/fastapi-tutorial/requirements.txt` inside the application directory.

6. **Enable & Start PostgreSQL Service** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Enables and starts the `postgresql` service.

7. **Create Database User & Database** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Executes SQL commands as `postgres` to:
     - `CREATE USER fastapi WITH PASSWORD 'fastapi_password';`
     - `CREATE DATABASE fastapi_db OWNER fastapi;`
     - `GRANT ALL PRIVILEGES ON DATABASE fastapi_db TO fastapi;`
   - Each command is wrapped with `|| true` to ignore errors if already present.

8. **Write `.env` Configuration File** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Creates `/opt/fastapi-tutorial/.env` with:
     ```
     PROJECT_NAME="FastAPI Tutorial"
     API_VERSION=1.0.0
     DATABASE_URL=postgresql://fastapi:fastapi_password@localhost/fastapi_db
     ```
   - Mode `0644`, owned by `root:root`.

9. **Create systemd Service Unit for FastAPI** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Writes `/etc/systemd/system/fastapi-tutorial.service` with unit definition (see file content in original plan).
   - Notifies `execute[systemd_reload]` immediately after creation.

10. **Reload systemd daemon** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
    - Executes `systemctl daemon-reload` (triggered by the file resource above).

11. **Enable & Start FastAPI Service** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
    - Enables and starts the `fastapi-tutorial` systemd service.

## Dependencies

- **External cookbook dependencies**: None (metadata only lists name/version).
- **System package dependencies**: `python3`, `python3-pip`, `python3-venv`, `git`, `postgresql`, `postgresql-contrib`, `libpq-dev`.
- **Service dependencies**: PostgreSQL must be running before the FastAPI service starts (enforced by `After=postgresql.service` in the systemd unit).

## Credentials

**Detection Summary**: 1 credential detected across 2 files.

**Source**:
  - **Provider**: None (hard‑coded in recipe)
  - **Path**: `cookbooks/fastapi-tutorial/recipes/default.rb`

### PostgreSQL User Password
- **Variable(s)**: `fastapi_password` (hard‑coded string)
- **Source file(s)**: `recipes/default.rb` (inside `execute[create_db_user]` command) and `file[/opt/fastapi-tutorial/.env]` (inline content)
- **Current storage**: Hardcoded in recipe & file resource (plain text)
- **Usage context**: Used to create the PostgreSQL user `fastapi` and to build the `DATABASE_URL` environment variable for the FastAPI app.

*Note*: For production migrations, consider moving this password to an encrypted vault (e.g., Ansible Vault) and referencing it via a variable.

## Checks for the Migration

**Files to verify**:
- `/opt/fastapi-tutorial` (application code)
- `/opt/fastapi-tutorial/.env` (environment configuration)
- `/etc/systemd/system/fastapi-tutorial.service` (systemd unit)
- PostgreSQL data directory (default `/var/lib/postgresql/...` – managed by the OS package)

**Service endpoints to check**:
- FastAPI HTTP endpoint – `http://<host>:8000/` (default port 8000)
- PostgreSQL – `localhost:5432`

**Templates rendered**: None external; all file resources contain inline content.

## Pre‑flight Checks:
```bash
# 1. Verify required system packages are installed
dpkg -l | grep -E 'python3|python3-pip|python3-venv|git|postgresql|libpq-dev'

# 2. Verify PostgreSQL service status
systemctl status postgresql
ps aux | grep postgres

# 3. Verify FastAPI service status
systemctl status fastapi-tutorial
ps aux | grep uvicorn

# 4. Verify FastAPI HTTP endpoint (health check)
curl -I http://localhost:8000/health || echo "Health endpoint not reachable"

# 5. Verify PostgreSQL listening port
netstat -tulpn | grep 5432
ss -tlnp | grep 5432

# 6. Verify database connectivity for fastapi_db (user fastapi)
PGPASSWORD='fastapi_password' psql -h localhost -U fastapi -d fastapi_db -c "SELECT version();"

# 7. Verify .env file contains expected values
grep -E 'PROJECT_NAME|API_VERSION|DATABASE_URL' /opt/fastapi-tutorial/.env

# 8. Verify systemd unit file content
cat /etc/systemd/system/fastapi-tutorial.service | grep -E 'ExecStart|Environment|WorkingDirectory'

# 9. Verify logs for both services
journalctl -u fastapi-tutorial -f &
tail -f /var/log/postgresql/postgresql-*.log &
```