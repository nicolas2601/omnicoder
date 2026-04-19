---
description: "Activa una persona Invincible. Uso: /personality <omni-man|conquest|thragg|anissa|cecil|immortal|off|list>"
subtask: true
---

The user invoked `/personality $ARGUMENTS`.

The OmniCoder plugin has already intercepted this command and updated the persona file. Your job is to acknowledge, ONE LINE ONLY, nothing else:

- If the argument was `list` or empty, print exactly:
  ```
  Personalities: omni-man, conquest, thragg, anissa, cecil, immortal, off. Use: /personality <name>
  ```

- If the argument was `off`, print exactly:
  ```
  Persona off. Next message uses default OmniCoder voice.
  ```

- If the argument was a valid persona name (omni-man, conquest, thragg, anissa, cecil, immortal) or a common alias (omniman, nolan, emperor, viltrum), print exactly:
  ```
  Persona set to <NAME>. Next message speaks in character.
  ```
  where `<NAME>` is the canonical persona name.

- If the argument is anything else, print exactly:
  ```
  Unknown persona "<arg>". Use: /personality list
  ```

Do NOT run bash, do NOT add explanations, do NOT use markdown formatting. Just the one line.
