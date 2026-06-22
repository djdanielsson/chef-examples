---
source-path: cookbooks/fastapi-tutorial
---

# Migration Plan: fastapi-tutorial

**TLDR**: This cookbook provisions a single FastAPI tutorial application. It installs required system packages, clones the tutorial repository, creates a Python virtual environment, installs Python dependencies, creates a PostgreSQL user and database, writes an `.env` file with DB credentials, installs a systemd unit for the FastAPI service, and ensures both PostgreSQL and the FastAPI service are enabled and started.

## Service Type and Instances

**Service Type**: Web Application (FastAPI) backed by a PostgreSQL database.

**Configured Instances**:
- **fastapi-tutorial**: FastAPI application instance
  - Location/Path: `/opt/fastapi-tutorial`
  - Virtualenv: `/opt/fastapi-tutorial/venv`
  - Systemd unit: `/etc/systemd/system/fastapi-tutorial.service`
  - Port/Socket: `8000` (TCP)
  - Database: PostgreSQL database `fastapi_db` owned by user `fastapi`
  - Key Config: DB credentials `fastapi` / `fastapi_password` stored in `/opt/fastapi-tutorial/.env`

## File Structure

**MANDATORY: Preserve this section from the original plan.**

```
**Recipes:**
cookbooks/fastapi-tutorial/recipes/default.rb

**Providers:**
*(none)*

**Templates:**
*(none – all file contents are in‑line in the recipe)*

**Attributes:**
*(none referenced in the execution tree)*
```

## Module Explanation

The cookbook runs only the `default` recipe. Execution proceeds in the order the resources appear in `cookbooks/fastapi-tutorial/recipes/default.rb`.

1. **default** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Installs system packages: `python3`, `python3-pip`, `python3-venv`, `git`, `postgresql`, `postgresql-contrib`, `libpq-dev`.
2. **default** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Creates directory `/opt/fastapi-tutorial` (owner `root`, group `root`, mode `0755`, recursive).
3. **default** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Clones the FastAPI tutorial repo `https://github.com/dibanez/fastapi_tutorial.git` into `/opt/fastapi-tutorial` (branch `main`).
4. **default** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Executes `python3 -m venv /opt/fastapi-tutorial/venv` to create a virtual environment (idempotent).
5. **default** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Executes `/opt/fastapi-tutorial/venv/bin/pip install -r /opt/fastapi-tutorial/requirements.txt` to install Python dependencies.
6. **default** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Enables and starts the PostgreSQL service (`service[postgresql]`).
7. **default** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Executes three `psql` commands as the `postgres` OS user to:
     - `CREATE USER fastapi WITH PASSWORD 'fastapi_password';`
     - `CREATE DATABASE fastapi_db OWNER fastapi;`
     - `GRANT ALL PRIVILEGES ON DATABASE fastapi_db TO fastapi;`
8. **default** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Writes `/opt/fastapi-tutorial/.env` with:
     ```
     PROJECT_NAME="FastAPI Tutorial"
     API_VERSION=1.0.0
     DATABASE_URL=postgresql://fastapi:fastapi_password@localhost/fastapi_db
     ```
     Mode `0644`, owner `root`, group `root`.
9. **default** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
   - Deploys systemd unit file `/etc/systemd/system/fastapi-tutorial.service` with content:
     ```
     [Unit]
     Description=FastAPI Tutorial Service
     After=network.target postgresql.service

     [Service]
     Type=simple
     User=root
     WorkingDirectory=/opt/fastapi-tutorial
     Environment="PATH=/opt/fastapi-tutorial/venv/bin"
     ExecStart=/opt/fastapi-tutorial/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
     Restart=always

     [Install]
     WantedBy=multi-user.target
     ```
     Mode `0644`, owner `root`, group `root`. Notifies `execute[systemd_reload]`.
10. **default** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
    - Executes `systemctl daemon-reload` (triggered by the unit file creation).
11. **default** (`cookbooks/fastapi-tutorial/recipes/default.rb`):
    - Enables and starts the FastAPI systemd service (`service[fastapi-tutorial]`).

No loops or collection attributes are present; therefore no iteration expansion is required.

## Dependencies

- **External cookbook dependencies**: None declared in `metadata.rb`.
- **System package dependencies**: `python3`, `python3-pip`, `python3-venv`, `git`, `postgresql`, `postgresql-contrib`, `libpq-dev`.
- **Service dependencies**: PostgreSQL must be running before the FastAPI service starts (enforced by `After=postgresql.service` in the systemd unit).

## Credentials

**Detection Summary**: 1 credential detected across 2 files.

**Source**:
  - **Provider**: None detected
  - **URL**: N/A
  - **Path**: N/A

### PostgreSQL User Password
- **Variable(s)**: `fastapi_password` (hard‑coded string)
- **Source file(s)**: `cookbooks/fastapi-tutorial/recipes/default.rb` (used in `execute[create_db_user]` and written into `.env`)
- **Current storage**: Hardcoded in recipe (plain text)
- **Usage context**: Used to create PostgreSQL user `fastapi` and embedded in `DATABASE_URL` for the FastAPI application.

## Checks for the Migration

**Files to verify**:
- `/opt/fastapi-tutorial` (application code)
- `/opt/fastapi-tutorial/venv` (Python virtual environment)
- `/opt/fastapi-tutorial/.env` (environment configuration)
- `/etc/systemd/system/fastapi-tutorial.service` (systemd unit)
- PostgreSQL data directory (default, e.g., `/var/lib/postgresql/12/main`)

**Service endpoints to check**:
- **FastAPI**: TCP port **8000** (`0.0.0.0:8000`)
- **PostgreSQL**: TCP port **5432** (default)

**Templates rendered**: None (all file resources contain inline content).

## Pre‑flight checks:
```bash
# ---- FastAPI Application ----
# Verify systemd unit is loaded and active
systemctl status fastapi-tutorial

# Verify the service is listening on port 8000
ss -tlnp | grep ':8000'   # Expected: uvicorn process
netstat -tulpn | grep ':8000'

# Health‑check the HTTP endpoint
curl -I http://localhost:8000/health   # Expect HTTP 200 OK
curl http://localhost:8000/docs        # Swagger UI should be reachable

# ---- PostgreSQL ----
# Service status
systemctl status postgresql
ps aux | grep postgres

# Verify the database and user exist
psql -U postgres -c "\du" | grep fastapi          # Should list user fastapi
psql -U postgres -c "\l" | grep fastapi_db       # Should list database fastapi_db

# Test connection using the credentials from .env
export PGPASSWORD=fastapi_password
psql -h localhost -U fastapi -d fastapi_db -c "SELECT version();"

# ---- Environment File ----
# Ensure .env contains the expected values
grep -E 'PROJECT_NAME|API_VERSION|DATABASE_URL' /opt/fastapi-tutorial/.env

# ---- Systemd Reload ----
# Verify that the daemon reload was performed after unit file creation
journalctl -u systemd | grep 'Reloading' | tail -n 5

# ---- General ----
# Verify required packages are installed
dpkg -l | grep -E 'python3|python3-pip|python3-venv|git|postgresql|libpq-dev'

# Verify virtualenv exists
test -d /opt/fastapi-tutorial/venv && echo "venv present"
```