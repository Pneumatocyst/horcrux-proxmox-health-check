# HORCRUX Proxmox Health Check Roadmap

The roadmap records likely project directions, not guaranteed delivery dates. Reliability, safe defaults, and the read-only operating model take priority over feature count.

## v1.1 priorities

- Add an optional machine-readable output mode for monitoring and automation
- Support a local configuration file while preserving command-line overrides
- Allow operators to enable or disable individual check groups
- Expand test coverage for empty, missing, malformed, and permission-limited command output
- Improve endpoint-check summaries and diagnostics without exposing sensitive URLs
- Document cron and systemd-timer examples for scheduled reporting

## Later possibilities

- Historical comparison of health-check results
- Optional notification wrappers maintained separately from the read-only checker
- Additional Proxmox storage and backup-health checks
- Multi-node reporting that does not require clustering changes
- Signed release artifacts and stronger software-supply-chain metadata

## Non-goals

The core utility will not automatically:

- Delete logs, snapshots, backups, or disks
- Restart services, guests, or hosts
- Install packages or apply upgrades
- Change networking, storage, firewall, or guest configuration
- Send infrastructure data to an external service by default

Feature proposals are welcome through the repository's feature-request form.

