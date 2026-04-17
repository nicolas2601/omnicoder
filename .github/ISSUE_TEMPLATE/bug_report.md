---
name: Bug report
about: Report a defect in OmniCoder (hooks, agents, skills, installers, CLI)
title: "[BUG] <short summary>"
labels: ["bug", "triage"]
assignees: []
---

## Description

<!-- Clear and concise description of the bug. What went wrong? -->

## Steps to reproduce

1.
2.
3.

## Expected behavior

<!-- What did you expect to happen? -->

## Actual behavior

<!-- What happened instead? Include error messages. -->

## Environment

Run one of the following and paste the output:

```bash
omnicoder --version
# or
./scripts/install-linux.sh --doctor
```

<details>
<summary>Output</summary>

```
<paste here>
```

</details>

- OS (e.g. `Arch Linux 6.19`, `macOS 15.2`, `Windows 11 24H2`):
- Shell (e.g. `bash 5.2`, `zsh 5.9`, `pwsh 7.4`):
- Node.js version (`node --version`):
- Qwen CLI version (if known):
- Provider in use (NVIDIA NIM / MiniMax / Gemini / other):

## Relevant logs

Tail of the operations log (last ~50 lines is usually enough):

```bash
tail -n 50 ~/.omnicoder/logs/operations.log
```

<details>
<summary>Log excerpt</summary>

```
<paste here>
```

</details>

## Additional context

<!-- Screenshots, config snippets (DO NOT include secrets/API keys), related issues, etc. -->
