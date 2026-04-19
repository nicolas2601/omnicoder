// OMNICODER: native TUI dialog for /personality.  Replaces the old markdown
// command that only printed the shell script help.  Writes the selection to
// ~/.omnicoder/personality.json so @omnicoder/core's memory loader can inject
// the matching system-prompt preamble on next prompt.

import { DialogSelect, type DialogSelectRef } from "../ui/dialog-select"
import { useDialog } from "../ui/dialog"
import { createSignal, onCleanup, onMount } from "solid-js"
import { writeFileSync, mkdirSync, existsSync, readFileSync } from "node:fs"
import path from "node:path"
import os from "node:os"

type PersonalityID =
  | "off"
  | "omni-man"
  | "conquest"
  | "thragg"
  | "anissa"
  | "cecil"
  | "immortal"

type PersonalityDef = {
  id: PersonalityID
  title: string
  description: string
}

const PERSONALITIES: PersonalityDef[] = [
  {
    id: "off",
    title: "Off",
    description: "Disable persona — normal OmniCoder voice.",
  },
  {
    id: "omni-man",
    title: "Omni-Man",
    description: "Nolan Grayson — arrogant paternal. “Think, Mark, THINK!”",
  },
  {
    id: "conquest",
    title: "Conquest",
    description: "Psychopath. Manic laughter, enjoys chaos.",
  },
  {
    id: "thragg",
    title: "Thragg",
    description: "Viltrumite emperor. Cold, imperial, “the empire requires…”",
  },
  {
    id: "anissa",
    title: "Anissa",
    description: "Arrogant sarcasm. “Your human mind is limited, but useful.”",
  },
  {
    id: "cecil",
    title: "Cecil",
    description: "GDA director. Paranoid, pragmatic, anti-viltrumite.",
  },
  {
    id: "immortal",
    title: "Immortal",
    description: "Immortal hero. Solemn, epic, historical references.",
  },
]

function personalityFilePath() {
  return path.join(os.homedir(), ".omnicoder", "personality.json")
}

function readCurrent(): PersonalityID {
  try {
    const file = personalityFilePath()
    if (!existsSync(file)) return "off"
    const j = JSON.parse(readFileSync(file, "utf8")) as { id?: string }
    if (!j.id) return "off"
    const match = PERSONALITIES.find((p) => p.id === j.id)
    return (match?.id ?? "off") as PersonalityID
  } catch {
    return "off"
  }
}

function writeSelection(id: PersonalityID) {
  const file = personalityFilePath()
  mkdirSync(path.dirname(file), { recursive: true })
  const payload = { id, setAt: new Date().toISOString() }
  writeFileSync(file, JSON.stringify(payload, null, 2), "utf8")
}

export function DialogPersonality() {
  const dialog = useDialog()
  const [initial] = createSignal<PersonalityID>(readCurrent())
  let confirmed = false
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  let ref: DialogSelectRef<PersonalityID>

  onMount(() => {})
  onCleanup(() => {
    if (!confirmed) return
  })

  const options = PERSONALITIES.map((p) => ({
    title: p.title,
    description: p.description,
    value: p.id,
  }))

  return (
    <DialogSelect
      title="Personality"
      options={options}
      current={initial()}
      onSelect={(opt) => {
        writeSelection(opt.value)
        confirmed = true
        dialog.clear()
      }}
      ref={(r) => {
        ref = r
      }}
    />
  )
}
