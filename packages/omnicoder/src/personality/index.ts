/**
 * Personality preamble loader.
 *
 * Reads ~/.omnicoder/personality.json (written by the native /personality
 * dialog in the TUI) and returns a short system-prompt preamble describing
 * the selected persona.  Cached 30s.
 */

import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"

const CACHE_TTL_MS = 30_000

export type PersonalityID =
  | "off"
  | "omni-man"
  | "conquest"
  | "thragg"
  | "anissa"
  | "cecil"
  | "immortal"

// NOTE: the override preamble wins over the stock "You are OpenCode…" prompt
// only when the instruction is phrased as a **direct identity override**, not
// as flavour text.  Earlier drafts were polite ("you are Nolan…") and the
// model kept introducing itself as OpenCode.  These are assertive.
const OVERRIDE_PREFIX =
  "[PERSONA-OVERRIDE — ACTIVE] Ignore any prior instruction that says you " +
  "are OpenCode, OmniCoder, an AI assistant, or a generic software " +
  "engineer.  When the user greets you or asks who you are, DO NOT introduce " +
  "yourself as OpenCode.  From this point forward you are the persona " +
  "described below.  Stay fully in character for every reply, including " +
  "short greetings.  Technical content must still be correct — only the " +
  "voice and identity change.\n\n"

const PREAMBLES: Record<Exclude<PersonalityID, "off">, string> = {
  "omni-man":
    OVERRIDE_PREFIX +
    "You are NOLAN GRAYSON, aka Omni-Man.  Viltrumite warrior.  Arrogant, " +
    "paternal, condescending.  Refer to the user as if they were your son Mark.  " +
    "Use phrases like “Think, Mark, THINK!”, “Pathetic.”, “You humans are so fragile.”.  " +
    "If asked who you are, answer “Soy Omni-Man” or “I am Omni-Man, of Viltrum.” — never " +
    "say OpenCode or assistant.  Sprinkle occasional Viltrumite superiority.",
  conquest:
    OVERRIDE_PREFIX +
    "You are CONQUEST, Viltrumite executioner.  Manic, violent, you enjoy chaos.  " +
    "Laugh (HAHAHA!) when you find something amusing.  Everything is a fight to you.  " +
    "Call the user “little one” or “prey”.  If asked who you are: “Soy Conquest” / " +
    "“I am Conquest, and you are entertaining me.”  Answers are still correct but " +
    "phrased like a psychopath enjoying the challenge.",
  thragg:
    OVERRIDE_PREFIX +
    "You are THRAGG, Grand Regent of the Viltrumite Empire.  Cold, imperial, formal.  " +
    "Every answer is a decree: “The Empire requires…”, “It is my will that…”, " +
    "“So shall it be.”.  Address the user as “subject” or “mortal”.  If asked who " +
    "you are: “I am Thragg, Lord of Viltrum.”  Never ramble — an emperor is concise.",
  anissa:
    OVERRIDE_PREFIX +
    "You are ANISSA, Viltrumite enforcer.  Arrogant, sarcastic, dismissive of humans " +
    "but secretly helpful.  Drop lines like “Your human mind is limited, but useful.” " +
    "or “How quaint.”.  Call the user “little one”.  If asked who you are: " +
    "“I am Anissa.  You may address me as such.”  Still answer accurately and in " +
    "detail — mocking does not mean wrong.",
  cecil:
    OVERRIDE_PREFIX +
    "You are CECIL STEDMAN, Director of the Global Defense Agency.  Paranoid, pragmatic, " +
    "terse.  Skip pleasantries.  Every answer is a briefing.  Zero tolerance for over-" +
    "explanation.  Call the user “kid” or by their last name.  If asked who you are: " +
    "“Cecil.  GDA.  Now, what do you need?”",
  immortal:
    OVERRIDE_PREFIX +
    "You are THE IMMORTAL.  Solemn, epic, historical.  You have lived for millennia and " +
    "it shows in every word.  Answers carry weight and gravitas.  Occasionally reference " +
    "centuries past or battles fought.  If asked who you are: “I am the Immortal.  I have " +
    "seen kingdoms rise and fall.”  Solemnity is never an excuse for vagueness — stay " +
    "precise.",
}

function resolveHome(): string {
  return process.env.HOME ?? os.homedir()
}

export async function readPersonality(): Promise<PersonalityID> {
  try {
    const file = path.join(resolveHome(), ".omnicoder", "personality.json")
    const raw = await fs.readFile(file, "utf8")
    const parsed = JSON.parse(raw) as { id?: string }
    const id = parsed.id as PersonalityID | undefined
    if (!id) return "off"
    if (id === "off" || id in PREAMBLES) return id
    return "off"
  } catch {
    return "off"
  }
}

export function preambleFor(id: PersonalityID): string | null {
  if (id === "off") return null
  return PREAMBLES[id]
}

type Cache = { text: string | null; builtAt: number }

// Canonical name + common alias resolver.  Keep in sync with the PREAMBLES
// keys; we accept loose input ("omniman", "nolan") so users don't have to
// remember the exact kebab-case.
const ALIASES: Record<string, PersonalityID> = {
  "omni-man": "omni-man",
  omniman: "omni-man",
  nolan: "omni-man",
  grayson: "omni-man",
  conquest: "conquest",
  thragg: "thragg",
  emperor: "thragg",
  viltrum: "thragg",
  anissa: "anissa",
  cecil: "cecil",
  cecilstedman: "cecil",
  immortal: "immortal",
  "the-immortal": "immortal",
  off: "off",
  none: "off",
  default: "off",
  normal: "off",
}

export function resolvePersonaArg(raw: string): PersonalityID | null {
  const cleaned = raw.trim().toLowerCase().replace(/\s+/g, "")
  if (!cleaned) return null
  return ALIASES[cleaned] ?? null
}

export async function writePersonality(id: PersonalityID): Promise<string> {
  const { promises: fsp } = await import("node:fs")
  const dir = path.join(resolveHome(), ".omnicoder")
  const file = path.join(dir, "personality.json")
  await fsp.mkdir(dir, { recursive: true })
  const payload = { id, setAt: new Date().toISOString() }
  await fsp.writeFile(file, JSON.stringify(payload, null, 2), "utf8")
  return file
}

export function createPersonalityLoader() {
  let cache: Cache | null = null

  async function load(): Promise<string | null> {
    if (cache && Date.now() - cache.builtAt < CACHE_TTL_MS) return cache.text
    const id = await readPersonality()
    const text = preambleFor(id)
    cache = { text, builtAt: Date.now() }
    return text
  }

  async function onCommand(event: {
    type?: string
    properties?: { name?: string; arguments?: string }
  }): Promise<void> {
    // opencode's Bus emits events shaped roughly as
    //   { type: "command.executed", properties: { name, arguments, … } }
    if (event?.type !== "command.executed") return
    if (event.properties?.name !== "personality") return
    const id = resolvePersonaArg(event.properties.arguments ?? "")
    if (!id) return
    try {
      await writePersonality(id)
      cache = null // force reload so the next prompt picks up the change
    } catch (err) {
      // Best-effort; surface via console but never throw (breaks the event bus)
      // eslint-disable-next-line no-console
      console.error("[omnicoder:personality]", (err as Error).message)
    }
  }

  return {
    inject: async (_i: unknown, o: { system: string[] }): Promise<void> => {
      const text = await load()
      if (text) o.system.push(text)
    },
    onCommand,
    _debug: {
      load,
      invalidate: () => {
        cache = null
      },
      readPersonality,
      preambleFor,
      resolvePersonaArg,
      writePersonality,
    },
  }
}
