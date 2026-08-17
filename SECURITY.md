# Security Policy

## Supported versions

Security fixes are currently provided for the latest `1.0.x` release.

| Version | Supported |
| --- | --- |
| 1.0.x | Yes |
| Earlier versions | No |

## Reporting a vulnerability

Do not publish exploit details, credentials, internal addresses, or unsanitized infrastructure output in a public issue.

If private vulnerability reporting is available in the repository's **Security** tab, use **Report a vulnerability**. Otherwise, open a minimal public issue requesting private maintainer contact and omit all sensitive technical details.

Include the following in a private report when possible:

- A concise description of the issue and its impact
- The affected HORCRUX version
- Reproduction steps using sanitized data
- Any suggested mitigation or patch

## Security model

The health checker is designed to be read-only. It reports host state and does not intentionally repair, delete, restart, upgrade, or reconfigure the Proxmox host or its guests.

Operators are responsible for protecting local service files and captured output. Do not place passwords, API tokens, private keys, or sensitive query parameters in endpoint configuration files.

