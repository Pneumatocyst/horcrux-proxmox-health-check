# Sanitized sample output

The exact sections vary depending on available commands, configured storage, guests, mounts, and optional endpoint checks.

```text
HORCRUX Proxmox Health Check  v1.0.1
Host: pve-lab.example.internal
Time: 2026-08-16T13:42:18-05:00
Mode: read-only

Platform
--------
  [OK  ] Proxmox VE               pve-manager/9.x
  [INFO] Kernel                   6.x-pve
  [INFO] Uptime                   up 3 days, 4 hours
  [INFO] CPU                      Intel(R) Core(TM) processor

CPU and Memory
--------------
  [OK  ] Load average             0.18 across 4 cores (5% of core capacity)
  [OK  ] Memory                   8.7 GiB / 15.5 GiB used (56%)

Root Filesystem
---------------
  [WARN] Root disk                54 GiB / 67 GiB used (80%); 13 GiB free

Required Mounts
---------------
  [OK  ] /mnt/media               mounted from /dev/sdb1 (ext4)

Network
-------
  [OK  ] Bridge vmbr0             UP

System Services
---------------
  [OK  ] Failed units             none

Proxmox Storage
---------------
  [OK  ] local                    active, 43.10% used; 38 GiB free
  [OK  ] local-lvm                active, 35.27% used; 102 GiB free

QEMU Virtual Machines
---------------------
      ID      NAME                       STATUS       ONBOOT
      100     core-services              running      1
      200     gui-lab                    stopped      0
  [INFO] QEMU summary             1/2 running

LXC Containers
--------------
  [INFO] LXC containers           none configured

HTTP Services
-------------
  [OK  ] Grafana                  HTTP 200 in 12 ms
  [OK  ] Jellyfin                 HTTP 200 in 8 ms

Summary
-------
  OK=10  WARN=1  CRIT=0  INFO=6  SKIP=0
  [WARN] Overall                  review warnings
```
