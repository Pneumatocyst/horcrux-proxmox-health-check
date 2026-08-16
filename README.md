# HORCRUX Proxmox Health Check

A read-only Bash health report for standalone Proxmox VE hosts. It gives you a fast answer to the question: **is the host healthy, and what needs attention?**

The script checks the host without deleting, restarting, pruning, or changing anything.

## What it checks

- Proxmox VE detection, kernel, uptime, and CPU model
- CPU load relative to available cores
- Memory consumption
- Root-filesystem usage and free space
- Required mounts that you explicitly provide
- Expected Linux bridge state
- Failed `systemd` units
- Proxmox storage availability and usage
- QEMU VM status and autostart mismatches
- LXC container status and autostart mismatches
- Optional HTTP/HTTPS service availability and response time

## Requirements

- A Proxmox VE host using Bash
- Root or `sudo` access is recommended for complete Proxmox information
- Standard Linux tools: `awk`, `df`, `sed`, `systemctl`, `ip`, and `mountpoint`
- `curl` only when using endpoint checks

The script degrades gracefully when an optional command is unavailable.

## Quick start

Run these commands **on the Proxmox host**:

```bash
chmod +x proxmox-health-check.sh
sudo ./proxmox-health-check.sh
```

The script returns:

- `0` when no warning or critical condition is found
- `1` when at least one warning is found
- `2` when at least one critical condition is found
- `64` for invalid command-line usage

This makes it suitable for manual checks, cron jobs, monitoring wrappers, and CI-style validation.

## HORCRUX example

To verify an external media mount and a few internal services, create a local services file from the included example and run:

```bash
cp services.example services.local
nano services.local
sudo ./proxmox-health-check.sh \
  --mount /mnt/horcrux-media \
  --services services.local
```

`services.local` is ignored by Git so local URLs do not need to be committed.

## Options

```text
--root-warn PCT       Root filesystem warning threshold (default: 80)
--root-crit PCT       Root filesystem critical threshold (default: 90)
--mem-warn PCT        Memory warning threshold (default: 85)
--mem-crit PCT        Memory critical threshold (default: 95)
--load-warn PCT       Load/core warning threshold (default: 75)
--load-crit PCT       Load/core critical threshold (default: 100)
--bridge NAME         Expected Linux bridge (default: vmbr0)
--mount PATH          Require PATH to be an active mount; repeatable
--services FILE       Check HTTP endpoints listed in FILE
--timeout SECONDS     HTTP timeout (default: 5)
--no-color            Disable ANSI colors
--version             Print the script version
-h, --help            Show help
```

Example with custom thresholds:

```bash
sudo ./proxmox-health-check.sh \
  --root-warn 75 \
  --root-crit 90 \
  --mem-warn 80 \
  --mem-crit 95
```

## Endpoint configuration

Each non-comment line uses this format:

```text
Display Name|URL|TLS mode
```

Example:

```text
Proxmox UI|https://proxmox.example.internal:8006|insecure
Grafana|http://grafana.example.internal:3000|
Jellyfin|http://media.example.internal:8096/health|
```

The optional `insecure` value permits a trusted internal endpoint with a self-signed certificate. It is deliberately configured per endpoint instead of disabling certificate validation globally.

Do not put usernames, passwords, API keys, tokens, or private query parameters in this file.

## Safety

The script is intentionally read-only. It does not:

- Delete logs, backups, snapshots, or VM disks
- Run package upgrades
- Restart services, guests, or the host
- Change firewall, bridge, storage, or VM configuration
- Automatically repair warnings

It reports findings so the operator can investigate each layer from evidence.

## Example output

See [`docs/sample-output.md`](docs/sample-output.md) for a sanitized example.

## Testing

From the repository root:

```bash
bash tests/smoke-test.sh
```

If ShellCheck is installed:

```bash
shellcheck proxmox-health-check.sh tests/smoke-test.sh
```

## Versioning

This repository uses semantic versioning. The current release is `v1.0.1`.

## License

MIT License. See [`LICENSE`](LICENSE).
