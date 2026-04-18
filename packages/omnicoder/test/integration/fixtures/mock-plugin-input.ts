/**
 * Factory for a `PluginInput`-shaped fake used by integration tests. The real
 * `@opencode-ai/plugin` type is shimmed in `src/types/plugin-shim.d.ts`; here
 * we construct a plain object that satisfies the structural contract without
 * pulling the workspace peerDep.
 */
import { promises as fs } from "node:fs"
import * as path from "node:path"

export type FakePluginInput = {
  client: Record<string, unknown>
  project: { id: string; worktree: string; directory: string }
  directory: string
  worktree: string
  experimental_workspace: { register: (type: string, adaptor: unknown) => void }
  serverUrl: URL
  $: null
}

export function makeFakePluginInput(overrides: Partial<FakePluginInput> = {}): FakePluginInput {
  const cwd = process.cwd()
  return {
    client: {},
    project: { id: "omnicoder-integration-test", worktree: cwd, directory: cwd },
    directory: cwd,
    worktree: cwd,
    experimental_workspace: { register: () => {} },
    serverUrl: new URL("http://localhost:4096/"),
    $: null,
    ...overrides,
  }
}

/** Copy the fixture tree into `<home>/.omnicoder/*`. */
export async function seedHomeFromFixtures(
  home: string,
  opts: { skills?: string[]; memory?: boolean; agents?: string[] } = {},
): Promise<void> {
  const fixturesRoot = path.join(import.meta.dir)
  const targetRoot = path.join(home, ".omnicoder")

  if (opts.skills && opts.skills.length > 0) {
    const skillsDir = path.join(targetRoot, "skills")
    for (const skill of opts.skills) {
      const srcDir = path.join(fixturesRoot, "skills", skill)
      const dstDir = path.join(skillsDir, skill)
      await fs.mkdir(dstDir, { recursive: true })
      const srcFile = path.join(srcDir, "SKILL.md")
      const dstFile = path.join(dstDir, "SKILL.md")
      await fs.copyFile(srcFile, dstFile)
    }
  }

  if (opts.agents && opts.agents.length > 0) {
    const agentsDir = path.join(targetRoot, "agents")
    await fs.mkdir(agentsDir, { recursive: true })
    for (const agent of opts.agents) {
      await fs.copyFile(
        path.join(fixturesRoot, "agents", `${agent}.md`),
        path.join(agentsDir, `${agent}.md`),
      )
    }
  }

  if (opts.memory) {
    const memDir = path.join(targetRoot, "memory")
    await fs.mkdir(memDir, { recursive: true })
    await fs.copyFile(
      path.join(fixturesRoot, "memory", "patterns.md"),
      path.join(memDir, "patterns.md"),
    )
    await fs.copyFile(
      path.join(fixturesRoot, "memory", "feedback.md"),
      path.join(memDir, "feedback.md"),
    )
  }
}

/** Write an Opencode-style config file with an `engram` MCP entry. */
export async function seedEngramConfig(home: string): Promise<void> {
  const cfgPath = path.join(home, ".omnicoder", "config.json")
  await fs.mkdir(path.dirname(cfgPath), { recursive: true })
  await fs.writeFile(
    cfgPath,
    JSON.stringify(
      {
        mcp: {
          engram: { command: "engram", args: ["serve"] },
        },
      },
      null,
      2,
    ),
  )
}
