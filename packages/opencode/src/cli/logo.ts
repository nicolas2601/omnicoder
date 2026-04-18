// OMNICODER: banner reforged to spell "omnicoder" in the same block style as
// the upstream opencode splash. `marks` is kept identical so the TUI print
// path (which inserts a subtle accent where `marks` characters appear)
// behaves exactly as before. Keeping the export named `logo` so the call
// sites in logo.tsx / cli output don't drift from upstream on merge.
export const logo = {
  left: [
    "                        ",
    "█▀▀█ █▀▀█ █▀▀▄ ▀█▀ █▀▀█ ",
    "█  █ █^^█ █  █  █  █  █ ",
    "▀▀▀▀ ▀  ▀ ▀  ▀ ▀▀▀ ▀▀▀▀ ",
  ],
  right: [
    "                             ",
    "█▀▀█ █▀▀█ █▀▀▄ █▀▀▀ █▀▀█ ",
    "█  █ █  █ █  █ █▀▀  █▄▄▀ ",
    "▀▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀ ▀▀ ",
  ],
}

export const go = {
  left: ["    ", "█▀▀▀", "█_^█", "▀▀▀▀"],
  right: ["    ", "█▀▀█", "█__█", "▀▀▀▀"],
}

export const marks = "_^~,"
