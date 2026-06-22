---
source-path: cookbooks/cache
---

# Migration Plan: cache

**TLDR**: This cookbook configures a Redis cache service. It creates the Redis log directory, applies a configuration fix via a Ruby block, and declares dependencies on external `memcached` and `redisio` cookbooks (which are not present). No loops or collections are used.

## Service Type and Instances

**Service Type**: Cache (Redis)

**Configured Instances**:
- **Redis**: Primary Redis cache instance
  - Location/Path: Log directory `/var/log/redis`; configuration file (default) `/etc/redis/redis.conf`
  - Port/Socket: TCP **6379**
  - Key Config: Log directory creation, Ruby block `fix_redis_config` that rewrites the Redis configuration file

## File Structure

**MANDATORY: Preserve this section from the original plan.**
```
**Recipes:**
cookbooks/cache/recipes/default.rb

**Providers:** *(none used – no custom resources appear in the execution tree)*

**Templates:** *(none rendered – no template resources are present)*

**Attributes:** *(none referenced in the execution tree)*
```

## Module Explanation

The cookbook runs the following steps in exact order:

1. **default** (`cookbooks/cache/recipes/default.rb`):
   - **Include recipes** (referenced but not found in the repository):
     - `memcached` – *Recipe file not found*
     - `redisio` – *Recipe file not found*
     - `redisio::enable` – *Recipe file not found*
   - **Resources executed**:
     1. **`directory[/var/log/redis]`**
        - Creates `/var/log/redis` with mode `0755` to hold Redis logs.
     2. **`ruby_block[fix_redis_config]`**
        - Reads the Redis configuration file (path derived from attributes) and writes back a corrected version. The block essentially performs `File.read(config_file)` followed by the necessary modifications.

No loops, iterations, or conditional branches are present.

## Dependencies

- **External cookbook dependencies**: `memcached`, `redisio` (recipe files missing)
- **System package dependencies**: `redis-server` (Debian/Ubuntu) or `redis` (RHEL/CentOS)
- **Service dependencies**: Systemd service `redis` (or `redis-server` depending on distribution)

## Credentials

**Detection Summary**: 0 credentials detected across 1 file

**Source**:
  - **Provider**: None detected
  - **URL**: N/A
  - **Path**: N/A

No credentials or secrets were detected in this cookbook. All configuration values appear to be non‑sensitive.

## Checks for the Migration

**Files to verify**:
- `/var/log/redis` – directory should exist with mode `0755`
- Redis configuration file (default `/etc/redis/redis.conf` unless overridden) – should contain the changes applied by the Ruby block

**Service endpoints to check**:
- TCP port **6379** – default Redis listening port
- Systemd service `redis` (or `redis-server`)

**Templates rendered**: *(none)*

## Pre‑flight checks:
```bash
# Verify the log directory exists and has correct permissions
ls -ld /var/log/redis
stat -c '%a' /var/log/redis   # should output 755

# Verify Redis package is installed
# Debian/Ubuntu
dpkg -l | grep redis
# RHEL/CentOS
rpm -qa | grep redis

# Verify Redis service is enabled and running
systemctl status redis
systemctl is-enabled redis

# Verify Redis is listening on the default port
ss -tlnp | grep ':6379'   # should show redis process

# Verify basic connectivity to Redis
redis-cli PING   # should return PONG

# Verify the configuration file reflects the Ruby block changes
# (adjust path if attribute overrides are used)
grep -i 'some_expected_setting' /etc/redis/redis.conf
```