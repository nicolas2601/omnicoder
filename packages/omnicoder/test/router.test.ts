import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { promises as fs } from "node:fs"
import * as path from "node:path"
import { createSkillRouter } from "../src/router/index.ts"
import { cleanupHome, fakePluginInput, makeHome, withHome } from "./_helpers.ts"

async function seedSkills(home: string): Promise<void> {
  const skills = path.join(home, ".omnicoder", "skills")
  await fs.mkdir(path.join(skills, "react-best-practices"), { recursive: true })
  await fs.writeFile(
    path.join(skills, "react-best-practices", "SKILL.md"),
    "---\nname: react-best-practices\n---\nReact performance optimization, hooks, memoization, concurrent rendering.",
  )
  await fs.mkdir(path.join(skills, "django-expert"), { recursive: true })
  await fs.writeFile(
    path.join(skills, "django-expert", "SKILL.md"),
    "---\nname: django-expert\n---\nDjango models views ORM migrations authentication.",
  )
  const agents = path.join(home, ".omnicoder", "agents")
  await fs.mkdir(agents, { recursive: true })
  await fs.writeFile(
    path.join(agents, "security-auditor.md"),
    "Security auditor agent. Finds vulnerabilities, reviews authentication and authorization flows.",
  )
}

describe("router", () => {
  let home = ""
  let restore: () => void = () => {}

  beforeEach(async () => {
    home = await makeHome()
    restore = withHome(home)
    await seedSkills(home)
  })

  afterEach(async () => {
    restore()
    await cleanupHome(home)
  })

  test("happy path: suggests top-3 skills for a matching prompt", async () => {
    const router = await createSkillRouter(fakePluginInput as never)
    router._debug.invalidate()
    const output = { system: [] as string[] }
    await router.inject(
      {
        prompt:
          "necesito ayuda para optimizar el rendimiento de mi aplicacion react con hooks y memoization en produccion",
      },
      output,
    )
    expect(output.system.length).toBe(1)
    expect(output.system[0]).toContain("[OMNICODER] Sugeridos:")
    expect(output.system[0]).toContain("react-best-practices")
    expect(output.system[0]!.length).toBeLessThanOrEqual(500)
  })

  test("edge case: short prompt / greeting injects nothing", async () => {
    const router = await createSkillRouter(fakePluginInput as never)
    router._debug.invalidate()
    const o1 = { system: [] as string[] }
    await router.inject({ prompt: "hola que tal" }, o1)
    expect(o1.system.length).toBe(0)

    const o2 = { system: [] as string[] }
    await router.inject({ prompt: "hi" }, o2)
    expect(o2.system.length).toBe(0)

    const o3 = { system: [] as string[] }
    await router.inject({ prompt: "" }, o3)
    expect(o3.system.length).toBe(0)
  })

  test("error handling: missing skills directory does not throw and yields no output", async () => {
    // wipe seeded data
    await fs.rm(path.join(home, ".omnicoder"), { recursive: true, force: true })
    await fs.mkdir(path.join(home, ".omnicoder"), { recursive: true })
    const router = await createSkillRouter(fakePluginInput as never)
    router._debug.invalidate()
    const output = { system: [] as string[] }
    await router.inject(
      { prompt: "please implement a full react application with state management today" },
      output,
    )
    expect(output.system.length).toBe(0)
  })
})
