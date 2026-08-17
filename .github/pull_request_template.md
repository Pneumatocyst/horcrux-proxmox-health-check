## Summary

Describe what changed and why.

## Operator impact

Explain how the change affects health-check behavior, output, dependencies, or documentation.

## Validation

- [ ] `bash -n proxmox-health-check.sh tests/smoke-test.sh`
- [ ] `bash tests/smoke-test.sh`
- [ ] `shellcheck proxmox-health-check.sh tests/smoke-test.sh` (when available)
- [ ] Documentation and sample output updated when applicable
- [ ] No credentials or identifying infrastructure details included

## Safety

- [ ] The change preserves the read-only operating model.
- [ ] The documented exit-code contract remains correct.
- [ ] New or changed behavior has simulated-host test coverage.

