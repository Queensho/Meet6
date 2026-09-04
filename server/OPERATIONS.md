# Meet6 Production Operations

This directory contains the VPS operations baseline for the Meet6 NestJS API.

## What is installed

- Daily PostgreSQL custom-format backup at 03:30 with 14-day local retention.
- Daily upload archive in the same timestamped local backup directory.
- SHA-256 verification plus `pg_restore --list` and tar integrity checks.
- `/var/backups/meet6/latest` symlink pointing to the newest verified local backup.
- Optional verified off-site copy through `rclone` after every successful local backup.
- Optional backup dead-man heartbeat sent only after the off-site copy is verified.
- Recovery helper that downloads a selected off-site backup and runs the normal verifier.
- PM2 crash recovery, memory restart, backoff, persistent process list and systemd startup.
- PM2 stdout/stderr in `/var/log/meet6`.
- Daily log rotation, 14 rotations, compression and 50 MB max-size trigger.
- One-minute API health checks against `/api/health`, including PostgreSQL and Redis.
- Optional external heartbeat ping after successful local health checks.
- GitHub-hosted external HTTPS monitor every 5 minutes against the public production health endpoint.
- Structured tracking of HTTP 5xx, bootstrap failures, uncaught exceptions and unhandled rejections.
- Five-minute scanner for new structured application errors.
- Optional Slack, Discord or generic webhook alerts.

## Install or refresh on the VPS

From `/var/www/meet6`:

```bash
sudo bash server/scripts/install-production-ops.sh
```

The installer detects the owner of `/var/www/meet6/server` and uses that account for PM2. Override when required:

```bash
sudo APP_USER=meet6 bash server/scripts/install-production-ops.sh
```

## Off-site backup

The local `/var/backups/meet6` copy is deliberately retained for fast recovery, but it is not sufficient for total VPS/disk loss. Production must use independent object storage or a second server.

Meet6 uses `rclone` so the storage provider is not hard-coded. Prefer an object-storage provider that is operationally independent from the VPS provider. Enable bucket versioning and/or object lock when available, and configure a provider-side lifecycle retention policy rather than deleting old remote backups from the VPS.

### 1. Install rclone

Install `rclone` from the operating system package repository or the official rclone distribution, then confirm:

```bash
rclone version
```

### 2. Create an encrypted remote

Keep the rclone configuration outside the repository:

```bash
sudo mkdir -p /etc/meet6
sudo rclone --config /etc/meet6/rclone.conf config
sudo chmod 600 /etc/meet6/rclone.conf
```

Recommended layout:

- Base remote: independent S3-compatible/object-storage account, for example `meet6-object`.
- Crypt remote: `meet6-crypt`, pointing at `meet6-object:meet6-production`.
- Production setting: `OFFSITE_RCLONE_REMOTE=meet6-crypt:backups`.

Store the object-storage credentials and the rclone crypt recovery password/config in a password manager or other recovery location that does **not** depend on the VPS. Losing the only crypt credentials together with the VPS makes the remote backup unusable.

### 3. Test the remote

```bash
sudo rclone --config /etc/meet6/rclone.conf lsd meet6-crypt:
sudo OFFSITE_RCLONE_REMOTE=meet6-crypt:backups \
  RCLONE_CONFIG=/etc/meet6/rclone.conf \
  /usr/local/sbin/meet6-offsite-backup /var/backups/meet6/latest
```

The uploader first checks the local `SHA256SUMS`, uploads the timestamped directory, runs an `rclone check` against the remote, and updates `latest.txt` only after verification succeeds.

### 4. Make off-site backup mandatory

Edit:

```bash
sudo nano /etc/default/meet6-ops
```

Set:

```text
OFFSITE_RCLONE_REMOTE=meet6-crypt:backups
OFFSITE_BACKUP_REQUIRED=true
RCLONE_CONFIG=/etc/meet6/rclone.conf
BACKUP_HEARTBEAT_URL=
```

After `OFFSITE_BACKUP_REQUIRED=true`, a missing remote, missing rclone config, upload failure or remote verification failure makes `meet6-backup.service` fail and triggers the existing operations alert chain.

Use `BACKUP_HEARTBEAT_URL` with an external dead-man monitoring provider. Configure it to expect one successful ping per day with suitable grace time. Because the ping is sent only after the off-site copy is verified, a dead VPS, failed backup timer or failed remote copy eventually produces an external alert.

### 5. Recovery drill

List available remote backups:

```bash
sudo rclone --config /etc/meet6/rclone.conf lsd meet6-crypt:backups
```

Fetch and verify a selected timestamp:

```bash
sudo OFFSITE_RCLONE_REMOTE=meet6-crypt:backups \
  RCLONE_CONFIG=/etc/meet6/rclone.conf \
  /usr/local/sbin/meet6-offsite-fetch 20260904T033000Z
```

Do a recovery drill periodically. A backup is not considered production-safe until a copy can be downloaded and verified independently from the source VPS.

## External uptime monitoring

There are two complementary checks:

1. The VPS-local one-minute monitor checks Node, PostgreSQL and Redis and can send `UPTIME_HEARTBEAT_URL` after success.
2. `.github/workflows/external-uptime.yml` runs on GitHub-hosted infrastructure every 5 minutes and requests the public HTTPS endpoint. It verifies DNS/TLS reachability, HTTP 200, `ok=true`, and `service=meet6-api`.

The default public endpoint is:

```text
https://api.meet6.com.tr/api/health
```

To override it, create the repository variable:

```text
MEET6_PUBLIC_HEALTH_URL
```

For an additional alert channel, add the repository secret:

```text
MEET6_UPTIME_ALERT_WEBHOOK_URL
```

and optionally the repository variable:

```text
MEET6_UPTIME_ALERT_WEBHOOK_FORMAT=slack
```

Supported webhook formats are `generic`, `slack`, and `discord`. Even without a webhook, the GitHub Actions run fails visibly when the public endpoint is unavailable.

For production SLA monitoring, a dedicated external uptime provider can additionally monitor the same public URL at a one-minute interval. It must run outside the Meet6 VPS/provider failure domain.

## Alerting and local uptime heartbeat

Edit:

```bash
sudo nano /etc/default/meet6-ops
```

Useful variables:

```text
HEALTH_URL=http://127.0.0.1:3100/api/health
HEALTH_FAILURE_THRESHOLD=3
UPTIME_HEARTBEAT_URL=
BACKUP_HEARTBEAT_URL=
OPS_ALERT_WEBHOOK_URL=
OPS_ALERT_WEBHOOK_FORMAT=generic
```

`OPS_ALERT_WEBHOOK_FORMAT` supports `generic`, `slack`, and `discord`.

## Commands

```bash
# Timers
systemctl list-timers 'meet6-*'

# Backup status and logs
systemctl status meet6-backup.timer
journalctl -u meet6-backup.service -n 100 --no-pager

# Verify latest local backup
sudo /usr/local/sbin/meet6-backup-verify /var/backups/meet6/latest

# Manually verify/copy latest backup off-site
sudo /usr/local/sbin/meet6-offsite-backup /var/backups/meet6/latest

# Health status and logs
systemctl status meet6-health.timer
journalctl -u meet6-health.service -n 100 --no-pager

# Error watcher
systemctl status meet6-error-watch.timer
journalctl -u meet6-error-watch.service -n 100 --no-pager

# PM2
pm2 status
pm2 logs meet6-api --lines 100

# Test logrotate config
sudo logrotate --debug /etc/logrotate.d/meet6
```

## Production backup policy

A healthy production setup should satisfy all of the following:

- Local verified backup for fast recovery.
- Independent off-site verified copy.
- Remote storage credentials/recovery key stored outside the VPS.
- Provider-side retention/versioning or object lock.
- Daily backup dead-man heartbeat.
- Periodic restore drill from the off-site copy.
- External public uptime monitoring outside the VPS failure domain.

The local backup alone is **not** disaster recovery. Total VPS/disk loss is covered only after the independent off-site copy and its recovery credentials have been configured and tested.
