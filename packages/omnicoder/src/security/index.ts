/**
 * Security guard — ports `security-guard.sh`.
 *
 * Inspects `bash` tool calls for destructive or secret-leaking patterns and
 * throws when a match is found. Non-bash tools short-circuit cheaply.
 */
import type { PluginInput } from "@opencode-ai/plugin"

const DANGEROUS: RegExp[] = [
  /rm\s+-r[f ]*\s+\//,
  /rm\s+-r[f ]*\s+~/,
  /rm\s+-rf\s+\*/,
  /rm\s+.*--no-preserve-root/,
  /:\(\)\s*\{.*:\|:.*\}/, // fork bomb
  /\bmkfs\./i,
  /\bdd\s+if=\/dev\/(zero|random|urandom)/i,
  /\bdd\s+of=\/dev\/[a-z]/i,
  />\s*\/dev\/sd[a-z]/i,
  /chmod\s+[0-7]*7[0-7]*\s+\/(etc|usr|var|boot|bin|sbin)/i,
  /chmod\s+-R\s+777\s+\//,
  /curl\s+[^|]*\|\s*(ba)?sh\b/i,
  /wget\s+[^|]*\|\s*(ba)?sh\b/i,
  /bash\s*<\(\s*curl/i,
  /bash\s*<\(\s*wget/i,
  /\bsudo\b/i,
  />\s*\/etc\//i,
  /\.\.\// , // path traversal — block ANY ../ (including single level)
  /mv\s+\/\s+\/dev\/null/,
  // SSRF prevention — block dangerous URL schemes
  /\b(file|gopher|data|dict|ftp|ldap|ldaps):/i,
  // Redirection to files — can write to sensitive locations
  /[<>]{1,2}\s*\S*\/(etc|var|boot|bin|sbin|root|home\/[^/]+\/.ssh)/i,
]

const SECRETS: RegExp[] = [
  /\bcat\s+[^|]*\.env/i, // *.env, *.env.production, etc.
  /\becho\s+.*\b(API_KEY|SECRET|PASSWORD|TOKEN)\b/i,
  /\becho\s+.*\$\{?(API_KEY|SECRET|PASSWORD|TOKEN|OPENAI_API_KEY|GITHUB_TOKEN|AWS_SECRET)\b/i,
  /\bprintenv\s+.*(KEY|SECRET|TOKEN|PASSWORD)\b/i,
  // Detect credential patterns in variable assignments or exports
  /(export|declare)\s+(OPENAI_API_KEY|GITHUB_TOKEN|AWS_SECRET_ACCESS_KEY|DATABASE_PASSWORD|PRIVATE_KEY)=/i,
]

const WHITELIST: RegExp[] = [
  /^git\s/,
  /^npm\s/,
  /^bun\s/,
  /^ls(\s|$)/,
  /^cat\s/,
  /^grep\s/,
]

// Command separators that can smuggle a second command past a prefix whitelist
// (e.g. `git pull && rm -rf /`).  We split on them *before* whitelist matching.
// Includes redirections (>, >>, <) and newlines (\n).
const SEPARATORS = /[;&|]{1,2}|\$\(|`|[<>]{1,2}|\n/

export class SecurityError extends Error {
  constructor(
    message: string,
    public readonly pattern: string,
  ) {
    super(message)
    this.name = "SecurityError"
  }
}

export async function createSecurityGuard(_input: PluginInput): Promise<{
  check: (
    i: { tool: string; sessionID?: string; callID?: string },
    o: { args: unknown },
  ) => Promise<void>
}> {
  async function check(
    i: { tool: string; sessionID?: string; callID?: string },
    o: { args: unknown },
  ): Promise<void> {
    // SECURITY: Only bash is allowed through security checking.
    // Other interpreters (python, node, perl, ruby, etc.) bypass guard completely.
    // This is INTENTIONAL — they are considered higher-risk attack vectors.
    // If future work requires python/node/perl, those tools need their OWN
    // security guards (e.g., AST-based analysis for python, babel for node).
    if (i.tool !== "bash") return
    
    const args = o.args as { command?: unknown } | null
    const command = typeof args?.command === "string" ? args.command.trim() : ""
    if (!command) return

    // SECURITY: always check DANGEROUS + SECRETS over the FULL command first —
    // whitelist only applies to the *whole* command, never per-segment. This
    // prevents `git pull && rm -rf /` (prefix matches whitelist) or
    // `ls; dd if=/dev/zero of=/dev/sda` from slipping through.
    for (const re of DANGEROUS) {
      if (re.test(command)) {
        throw new SecurityError(
          `[omnicoder:security] blocked dangerous command: ${re.source}`,
          re.source,
        )
      }
    }
    for (const re of SECRETS) {
      if (re.test(command)) {
        throw new SecurityError(
          `[omnicoder:security] blocked secret-exposing command: ${re.source}`,
          re.source,
        )
      }
    }

    // Whitelist requires: (a) no separators / subshells anywhere, AND
    // (b) every top-level token is an allowed prefix. Otherwise fall through
    // (no throw — opencode decides via permission rules).
    if (!SEPARATORS.test(command)) {
      for (const allow of WHITELIST) {
        if (allow.test(command)) return
      }
    }
  }

  return { check }
}
