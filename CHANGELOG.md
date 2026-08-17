# Changelog

All notable changes to this project will be documented here.

## [Unreleased]

### Added

- Contribution and security policies
- Structured bug-report and feature-request forms
- Pull-request checklist focused on validation and read-only safety
- Public v1.1 roadmap
- Release, license, and community links in the README

## [1.0.1] - 2026-08-16

### Fixed

- Treat a successful empty `pct list` result as “no LXC containers configured” instead of an inventory failure
- Apply the same successful-empty handling to QEMU VM inventory

## [1.0.0] - 2026-08-16

### Added

- Read-only Proxmox VE host health report
- CPU load, memory, and root-filesystem thresholds
- Required-mount validation
- Linux bridge and failed-systemd-unit checks
- Proxmox storage status and capacity checks
- QEMU VM and LXC container status summaries
- Optional HTTP/HTTPS endpoint checks
- Stable exit codes for automation
- Sanitized documentation, example configuration, and smoke tests
