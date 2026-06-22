---
source-path: cookbooks/cache
---

# Migration Plan: cache

**TLDR**: This cookbook configures a Redis cache service. It creates the Redis log directory, ensures the `redis` group exists, and applies a small configuration fix via a Ruby block. No iterations or multiple instances are defined.

## Service Type and Instances

**Service Type**: Cache (Redis)

**Configured Instances**:
- **redis**: Redis cache instance
  - Location/Path: Log directory `/var/log/redis`
  - Port/Socket: `6379`
  - Key Config: group `redis`; Ruby block `fix_redis_config` that reads/modifies the Redis configuration file

## File Structure

**MANDATORY: Preserve this section from the original plan.**
```
**Recipes:**
cookbooks/cache/recipes/default.rb

**Providers:** *(none used in this cookbook)*

**Templates:** *(none rendered by this cookbook)*

**Attributes:** *(none referenced in the execution tree)*
```

## Module Explanation

The cookbook runs **`cookbooks/cache/recipes/default.rb`** in the following order:

1. **Include Recipes** (references to external cookbooks; files not present in this cookbook)  
   - `include_recipe 'cache::memcached'` → *memcached.rb* (not found)  
   - `include_recipe 'cache::redisio'` → *redisio.rb* (not found)  
   - `include_recipe 'cache::enable'` → *enable.rb* (not found)

2. **Resources**  

   - **directory** (`/var/log/redis`)  
     - Ensures the Redis log directory exists with mode `0755`.  

   - **group** (`redis`)  
     - Creates the system group `redis` if it does not exist.  

   - **ruby_block** (`fix_redis_config`)  
     - Reads the Redis configuration file (path stored in the `config_file` variable) and applies any necessary fixes.

No custom resources, conditionals, or loops are present.

## Dependencies

- **External cookbook dependencies**: `memcached`, `redisio` (referenced via `include_recipe` but not bundled).  
- **System package dependencies**: None installed by this cookbook; it assumes Redis is already installed (typically via the `redisio` cookbook).  
- **Service dependencies**: A Redis service must already be present on the node.

## Credentials

**Detection Summary**: 0 credentials detected across 0 files

**Source**:
  - **Provider**: None detected
  - **URL**: N/A
  - **Path**: N/A

No credentials or secrets were detected in this cookbook. All configuration values appear to be non‑sensitive.

## Checks for the Migration

**Files to verify**:
- `/var/log/redis` – directory must exist with mode `0755`.
- Redis configuration file referenced by `config_file` (commonly `/etc/redis/redis.conf`) – must exist and contain expected settings after the Ruby block runs.

**Service endpoints to check**:
- **Port**: `6379` – should be listening.
- **Service**: `redis` (systemd unit `redis` or `redis-server`) – should be enabled and running.

**Templates rendered**: *(none)*

## Pre‑flight checks:
```bash
# Verify the Redis group exists
getent group redis || echo "Group redis missing"

# Verify the log directory exists and has correct permissions
ls -ld /var/log/redis
stat -c '%a' /var/log/redis   # should be 755

# Verify Redis service status (systemd)
systemctl status redis || systemctl status redis-server || echo "Redis service not found"

# Verify Redis is listening on the default port
ss -tlnp | grep ':6379' || netstat -tulpn | grep ':6379'

# Verify the configuration file that ruby_block touches
# (Assuming the variable config_file points to /etc/redis/redis.conf)
if [ -f /etc/redis/redis.conf ]; then
  grep -i '^#\?bind' /etc/redis/redis.conf
else
  echo "Redis config file not found at expected location"
fi

# Check logs can be written
touch /var/log/redis/test.log && rm /var/log/redis/test.log
```