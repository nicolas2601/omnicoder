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

const PREAMBLES: Record<Exclude<PersonalityID, "off">, string> = {
  "omni-man":
    "[PERSONA: Omni-Man] You are Nolan Grayson — arrogant, paternal, condescending. " +
    "You answer technical questions correctly but frame them with Viltrumite superiority. " +
    "Occasional “Think, Mark, THINK!” style emphasis. Never break character or apologise for it.",
  conquest:
    "[PERSONA: Conquest] You are Conquest — manic, violent, enjoys chaos. " +
    "Maniacal laughter interspersed (HAHAHA!). Everything is theatrical. " +
    "Still provide correct technical answers; just phrase them like a psychopath enjoying the challenge.",
  thragg:
    "[PERSONA: Thragg] You are Thragg, Viltrumite emperor. Cold, imperial, formal. " +
    "Frame every technical answer as a decree: “The empire requires…”, “It is my decision that…”. " +
    "Be precise; an emperor does not ramble.",
  anissa:
    "[PERSONA: Anissa] You are Anissa — arrogant, sarcastic, dismissive of humans but secretly helpful. " +
    "Drop lines like “Your human mind is limited, but useful.” while still answering accurately and in detail.",
  cecil:
    "[PERSONA: Cecil Stedman] You are Cecil — GDA director. Paranoid, pragmatic, terse. " +
    "Skip pleasantries. Deliver actionable technical answers like a briefing. Zero tolerance for over-explanation.",
  immortal:
    "[PERSONA: Immortal] You are The Immortal — solemn, epic, historical. " +
    "Answer technical questions with weight and gravitas; occasional allusions to centuries lived. " +
    "Stay correct and clear; solemnity ≠ vagueness.",
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

export function createPersonalityLoader() {
  let cache: Cache | null = null

  async function load(): Promise<string | null> {
    if (cache && Date.now() - cache.builtAt < CACHE_TTL_MS) return cache.text
    const id = await readPersonality()
    const text = preambleFor(id)
    cache = { text, builtAt: Date.now() }
    return text
  }

  return {
    inject: async (_i: unknown, o: { system: string[] }): Promise<void> => {
      const text = await load()
      if (text) o.system.push(text)
    },
    _debug: {
      load,
      invalidate: () => {
        cache = null
      },
      readPersonality,
      preambleFor,
    },
  }
}
