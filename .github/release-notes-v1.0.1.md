# HORCRUX Proxmox Health Check v1.0.1

The first stable public release of the HORCRUX Proxmox Health Check: a read-only Bash utility for quickly reviewing the condition of a standalone Proxmox VE host.

## Highlights

- Reports Proxmox, kernel, uptime, CPU, load, memory, and root-filesystem status
- Verifies required mounts and the expected Linux bridge
- Reports failed `systemd` units and Proxmox storage capacity
- Summarizes QEMU virtual machines and LXC containers, including autostart mismatches
- Optionally checks HTTP and HTTPS service endpoints
- Returns automation-friendly exit codes for healthy, warning, critical, and usage-error states
- Makes no repairs, restarts, deletions, package changes, or configuration changes

## Fixed in v1.0.1

- A successful empty `pct list` now correctly reports that no LXC containers are configured
- The same successful-empty behavior is applied to QEMU VM inventory

## Validation

- Tested on a live Proxmox VE 9.2.2 host
- Bash syntax and ShellCheck validation
- Simulated-host smoke tests using included command mocks
- Automated GitHub Actions validation on every push and pull request

## Downloads

- `HORCRUX_Proxmox_Health_Check_v1.0.1.zip` — complete source package
- `proxmox-health-check-v1.0.1.sh` — standalone executable script
- `SHA256SUMS.txt` — checksums for both downloadable files

See the README for installation, configuration, exit codes, safety guarantees, and example output.
