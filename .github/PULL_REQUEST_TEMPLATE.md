<!--
  Thanks for contributing to OmniCoder!
  Please fill out every section. Remove sections that do not apply
  rather than leaving them blank.
-->

## Summary

<!-- One or two sentences describing WHAT this PR does and WHY. -->

## Type of change

- [ ] Bug fix (non-breaking fix for an existing defect)
- [ ] Feature (non-breaking addition of functionality)
- [ ] Refactor (no behavior change)
- [ ] Documentation
- [ ] Chore (tooling, CI, build, dependencies)
- [ ] Breaking change (requires major version bump)

## Testing

<!-- How did you verify this works? Include commands, steps, and/or screenshots.
Examples:
- Ran `bash -n` on all modified hooks
- Executed `bats tests/validate.bats` locally
- Ran `./scripts/install-linux.sh --doctor`
- Tested provider switch via `./scripts/switch-provider.sh nvidia`
-->

## Breaking changes

<!-- List any migration steps users must perform. If none, write "None". -->

None

## Checklist

- [ ] `shellcheck -x -e SC1091,SC2086` passes on modified `.sh` files
- [ ] `bash -n` passes on modified `.sh` files
- [ ] Tests pass locally (`bats tests/`)
- [ ] Documentation updated (`README.md`, `OMNICODER.md`, or relevant `docs/`)
- [ ] `CHANGELOG.md` updated under the `[Unreleased]` (or target version) section
- [ ] No secrets, API keys, or personal data committed
- [ ] Branding uses "OmniCoder" (not "claude code" / "qwen code") outside of `docs/providers.md` and `CHANGELOG.md`
