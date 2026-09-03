# Meet6 Production Operations

This directory contains the VPS operations baseline for the Meet6 NestJS API.

## What is installed

- Daily PostgreSQL custom-format backup at 03:30 with 14-day retention.
- Daily upload archive in the same timestamped backup directory.
- SHA-256 verification plus `pg_restore --list` and tar integrity checks.
- `/var/backups/meet6/latest` symlink pointing to the newest verified backup.
- PM2 crash recovery, memory restart, backoff, persistent process list and systemd startup.
- PM2 stdout/stderr in `/var/log/meet6`.
- Daily log rotation, 14 rotations, compression and 50 MB max-size trigger.
- One-minute API health checks against `/api/health`, including PostgreSQL and Redis.
- Optional external heartbeat ping after successful health checks.
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

## Alerting and uptime heartbeat

Edit:

```bash
sudo nano /etc/default/meet6-ops
```

Useful variables:

```text
HEALTH_URL=http://127.0.0.1:3100/api/health
HEALTH_FAILURE_THRESHOLD=3
UPTIME_HEARTBEAT_URL=
OPS_ALERT_WEBHOOK_URL=
OPS_ALERT_WEBHOOK_FORMAT=generic
```

`OPS_ALERT_WEBHOOK_FORMAT` supports `generic`, `slack`, and `discord`.

The local monitor detects application, PostgreSQL and Redis failures. For true internet-side uptime monitoring, set `UPTIME_HEARTBEAT_URL` to a heartbeat URL from your chosen external uptime service, or separately monitor the public `https://api.meet6.com.tr/api/health` endpoint from outside the VPS.

## Commands

```bash
# Timers
systemctl list-timers 'meet6-*'

# Backup status and logs
systemctl status meet6-backup.timer
journalctl -u meet6-backup.service -n 100 --no-pager

# Health status and logs
systemctl status meet6-health.timer
journalctl -u meet6-health.service -n 100 --no-pager

# Error watcher
systemctl status meet6-error-watch.timer
journalctl -u meet6-error-watch.service -n 100 --no-pager

# PM2
pm2 status
pm2 logs meet6-api --lines 100

# Verify latest backup
sudo /usr/local/sbin/meet6-backup-verify /var/backups/meet6/latest

# Test logrotate config
sudo logrotate --debug /etc/logrotate.d/meet6
```

## Disaster recovery note

The default backup destination is on the same VPS. This protects against application mistakes and many local failures, but it does **not** protect against total VPS or disk loss. Production should additionally copy `/var/backups/meet6` to independent object storage or another server.
