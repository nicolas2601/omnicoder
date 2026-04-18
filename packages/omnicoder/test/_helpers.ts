/**
 * Test helpers: create isolated temporary HOME directories so each test runs
 * against a clean ~/.omnicoder namespace without leaking state.
 */
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"

export async function makeHome(prefix = "omni-test-"): Promise<string> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), prefix))
  await fs.mkdir(path.join(root, ".omnicoder"), { recursive: true })
  return root
}

export async function cleanupHome(home: string): Promise<void> {
  try {
    await fs.rm(home, { recursive: true, force: true })
  } catch {
    /* best-effort */
  }
}

export function withHome(home: string): () => void {
  const prev = process.env.HOME
  process.env.HOME = home
  return () => {
    if (prev === undefined) delete process.env.HOME
    else process.env.HOME = prev
  }
}

/** Minimal shape required by the module factories — cast at call sites. */
export const fakePluginInput = {
  client: null,
  project: { id: "test" },
  directory: process.cwd(),
  worktree: process.cwd(),
  experimental_workspace: { register: () => {} },
  serverUrl: new URL("http://localhost/"),
  $: null,
} as unknown
