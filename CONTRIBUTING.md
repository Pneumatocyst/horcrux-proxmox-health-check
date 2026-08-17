# Contributing to HORCRUX Proxmox Health Check

Thanks for helping improve the project. Contributions should preserve its core promise: produce useful Proxmox health evidence without changing the host.

## Before you start

- Search existing issues before opening a new one.
- Use the bug-report form for incorrect output or failures.
- Use the feature-request form for new checks or output formats.
- Keep hostnames, IP addresses, URLs, storage names, tokens, and other private infrastructure details out of issues and test fixtures.
- For security concerns, follow [`SECURITY.md`](SECURITY.md).

## Development workflow

1. Fork the repository and create a focused branch.
2. Make the smallest change that solves the problem.
3. Add or update a simulated-host test when behavior changes.
4. Run the validation commands below.
5. Open a pull request using the repository template.

## Validation

Run from the repository root:

```bash
bash -n proxmox-health-check.sh tests/smoke-test.sh
bash tests/smoke-test.sh
```

If ShellCheck is installed:

```bash
shellcheck proxmox-health-check.sh tests/smoke-test.sh
```

GitHub Actions repeats these checks and scans tracked files for obvious secret material.

## Project rules

- Maintain compatibility with Bash on supported Proxmox VE hosts.
- Do not add automatic repairs, deletions, restarts, upgrades, or configuration changes.
- Treat missing optional commands as reportable conditions rather than uncontrolled failures.
- Keep terminal output readable with and without ANSI color.
- Preserve the documented exit-code contract.
- Avoid external runtime dependencies unless the feature is explicitly optional.
- Update the README, sample output, changelog, and tests when a change affects them.

## Commit and pull-request guidance

- Keep commits focused and use clear imperative summaries.
- Explain the operator impact and how the change was tested.
- Identify any Proxmox-specific assumptions.
- Never include unsanitized production output.

