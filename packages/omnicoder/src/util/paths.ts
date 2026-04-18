/**
 * Shared path helpers. Extracted per CR-05 to remove the 4-file duplication
 * of resolveHome() and to give us a single place to tune OMNICODER_HOME later.
 *
 * Bun caches os.homedir() at first call, so we prefer $HOME so tests can
 * override via TMPDIR + HOME=.
 */
import * as os from "node:os"
import * as path from "node:path"
import { promises as fs } from "node:fs"

export function resolveHome(): string {
  return process.env.HOME ?? os.homedir()
}

export function omniDir(): string {
  return path.join(resolveHome(), ".omnicoder")
}

export function logsDir(): string {
  return path.join(omniDir(), "logs")
}

export function skillsDir(): string {
  return path.join(omniDir(), "skills")
}

export function agentsDir(): string {
  return path.join(omniDir(), "agents")
}

export function memoryDir(): string {
  return path.join(omniDir(), "memory")
}

/**
 * Size-based JSONL rotation. When the file exceeds `maxBytes`, renames it to
 * `<path>.1` (overwriting any previous .1). Keeps exactly one rotation — good
 * enough for audit trail without unbounded disk growth (CR-02).
 */
export async function rotateJsonlIfLarge(
  file: string,
  maxBytes: number,
): Promise<void> {
  try {
    const stat = await fs.stat(file)
    if (stat.size < maxBytes) return
    const rotated = `${file}.1`
    await fs.rm(rotated, { force: true })
    await fs.rename(file, rotated)
  } catch (err) {
    const code = (err as NodeJS.ErrnoException).code
    if (code === "ENOENT") return
    // Non-fatal — the caller still tries to append.
    console.error("[omnicoder:paths] rotate failed:", (err as Error).message)
  }
}

/** Default rotation threshold for every JSONL log we own. */
export const JSONL_ROTATE_BYTES = 5 * 1024 * 1024 // 5 MB
