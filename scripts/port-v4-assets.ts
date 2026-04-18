#!/usr/bin/env bun
/**
 * Port OmniCoder v4 skills + agents → Opencode format (v5).
 *
 * Sources (read-only):
 *   - ~/.omnicoder/skills/<name>/SKILL.md  (+ optional subfiles)
 *   - ~/.omnicoder/agents/<name>.md
 *
 * Targets:
 *   - <repo>/.opencode/skills/<slug>/SKILL.md   (+ subfiles preserved)
 *   - <repo>/.opencode/agent/<slug>.md
 *
 * Flags:
 *   --dry-run   Only print stats, write nothing.
 *   --verbose   Extra logs.
 */

import { readdir, mkdir, stat, readFile, writeFile, copyFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join, dirname, basename, relative } from "node:path";
import { homedir } from "node:os";

const HOME = homedir();
const REPO_ROOT = join(HOME, "omnicoder-v5");
const V4_SKILLS_DIR = join(HOME, ".omnicoder", "skills");
const V4_AGENTS_DIR = join(HOME, ".omnicoder", "agents");
const OUT_SKILLS_DIR = join(REPO_ROOT, ".opencode", "skills");
const OUT_AGENTS_DIR = join(REPO_ROOT, ".opencode", "agent");

const DRY_RUN = process.argv.includes("--dry-run");
const VERBOSE = process.argv.includes("--verbose");

type Stats = {
  skillsPorted: number;
  skillsSkipped: number;
  skillConflicts: number;
  skillErrors: number;
  agentsPorted: number;
  agentsSkipped: number;
  agentConflicts: number;
  agentErrors: number;
  manualDecisions: string[];
};

const stats: Stats = {
  skillsPorted: 0,
  skillsSkipped: 0,
  skillConflicts: 0,
  skillErrors: 0,
  agentsPorted: 0,
  agentsSkipped: 0,
  agentConflicts: 0,
  agentErrors: 0,
  manualDecisions: [],
};

// ──────────────────────────────────────────────────────────────
// Frontmatter utilities
// ──────────────────────────────────────────────────────────────

const FM_RE = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/;

function parseFrontmatter(source: string): { fm: Record<string, string>; body: string } {
  const match = source.match(FM_RE);
  if (!match) return { fm: {}, body: source };
  const [, fmText, body] = match;
  const fm: Record<string, string> = {};
  // naive YAML: key: value (values may be quoted, possibly multi-line quoted handled crudely)
  const lines = fmText.split(/\r?\n/);
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim() || line.trim().startsWith("#")) {
      i++;
      continue;
    }
    const m = line.match(/^([A-Za-z_][\w-]*)\s*:\s*(.*)$/);
    if (!m) {
      i++;
      continue;
    }
    const key = m[1];
    let value = m[2];
    // Multi-line quoted string? Only handle if starts with " and doesn't end with unescaped "
    if (value.startsWith('"') && !/"\s*$/.test(value.slice(1))) {
      // accumulate until closing quote
      let acc = value;
      i++;
      while (i < lines.length) {
        acc += "\n" + lines[i];
        if (/"\s*$/.test(lines[i])) break;
        i++;
      }
      value = acc;
    }
    fm[key] = stripYamlValue(value);
    i++;
  }
  return { fm, body: body ?? "" };
}

function stripYamlValue(v: string): string {
  const trimmed = v.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1).replace(/\\"/g, '"').replace(/\\'/g, "'");
  }
  return trimmed;
}

function quoteYaml(value: string): string {
  // Always quote with double quotes; escape any " inside.
  return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

function buildFrontmatter(pairs: Array<[string, string | undefined]>): string {
  const lines = ["---"];
  for (const [key, value] of pairs) {
    if (value === undefined || value === null || value === "") continue;
    lines.push(`${key}: ${quoteYaml(value)}`);
  }
  lines.push("---");
  return lines.join("\n");
}

// ──────────────────────────────────────────────────────────────
// Heuristics
// ──────────────────────────────────────────────────────────────

function slugify(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 120);
}

function extractTitleFromBody(body: string): string | undefined {
  const m = body.match(/^#\s+(.+?)\s*$/m);
  return m ? m[1].trim() : undefined;
}

function extractFirstParagraph(body: string): string | undefined {
  const stripped = body.replace(/^#[^\n]*\n+/g, ""); // drop leading headers
  for (const chunk of stripped.split(/\n\s*\n/)) {
    const clean = chunk.trim();
    if (clean && !clean.startsWith("#") && !clean.startsWith("```")) {
      return clean.replace(/\s+/g, " ").slice(0, 400);
    }
  }
  return undefined;
}

function detectModelHint(body: string): string | undefined {
  const b = body.toLowerCase();
  if (/claude[\s-]*opus[\s-]*4\.7|opus 4\.7/.test(b)) return "anthropic/claude-opus-4-7";
  if (/claude[\s-]*opus/.test(b) || /use\s+(claude\s+)?opus/.test(b)) return "anthropic/claude-opus-4-7";
  if (/claude[\s-]*sonnet[\s-]*4/.test(b)) return "anthropic/claude-sonnet-4-5";
  if (/claude[\s-]*sonnet/.test(b) || /use\s+(claude\s+)?sonnet/.test(b)) return "anthropic/claude-sonnet-4-5";
  if (/claude[\s-]*haiku/.test(b) || /use\s+(claude\s+)?haiku/.test(b)) return "anthropic/claude-haiku-4-5";
  return undefined;
}

function detectPrimary(name: string, body: string): boolean {
  const n = name.toLowerCase();
  if (/orchestrator|coordinator|supervisor|conductor|maestro/.test(n)) return true;
  if (/\bprimary\s+agent\b|you are the leader|autonomous pipeline manager/i.test(body)) return true;
  return false;
}

// ──────────────────────────────────────────────────────────────
// Filesystem helpers
// ──────────────────────────────────────────────────────────────

async function ensureDir(path: string): Promise<void> {
  if (DRY_RUN) return;
  await mkdir(path, { recursive: true });
}

async function walkFiles(root: string): Promise<string[]> {
  const out: string[] = [];
  async function visit(dir: string) {
    let entries;
    try {
      entries = await readdir(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const e of entries) {
      const p = join(dir, e.name);
      if (e.isDirectory()) await visit(p);
      else if (e.isFile()) out.push(p);
    }
  }
  await visit(root);
  return out;
}

async function fileExists(p: string): Promise<boolean> {
  try {
    await stat(p);
    return true;
  } catch {
    return false;
  }
}

async function hashFile(p: string): Promise<string> {
  const buf = await readFile(p);
  const h = new Bun.CryptoHasher("sha256");
  h.update(buf);
  return h.digest("hex");
}

async function filesIdentical(a: string, b: string): Promise<boolean> {
  if (!(await fileExists(a)) || !(await fileExists(b))) return false;
  try {
    const [ha, hb] = await Promise.all([hashFile(a), hashFile(b)]);
    return ha === hb;
  } catch {
    return false;
  }
}

// ──────────────────────────────────────────────────────────────
// Skill porting
// ──────────────────────────────────────────────────────────────

async function portSkill(skillDir: string, skillName: string): Promise<void> {
  const skillMd = join(skillDir, "SKILL.md");
  if (!(await fileExists(skillMd))) {
    if (VERBOSE) console.log(`[skill] skip ${skillName}: no SKILL.md`);
    stats.skillsSkipped++;
    return;
  }

  const raw = await readFile(skillMd, "utf8");
  const { fm, body } = parseFrontmatter(raw);

  const name = fm.name || skillName;
  const description =
    fm.description ||
    extractFirstParagraph(body) ||
    extractTitleFromBody(body) ||
    `Skill: ${name}`;

  // Pick a unique slug
  const baseSlug = slugify(name);
  let slug = baseSlug;
  let suffix = 1;
  while (true) {
    const candidateDir = join(OUT_SKILLS_DIR, slug);
    const candidate = join(candidateDir, "SKILL.md");
    // Idempotency: if candidate already contains our exact source (same frontmatter name), overwrite same slug.
    if (await fileExists(candidate)) {
      const existingRaw = await readFile(candidate, "utf8");
      const existingFm = parseFrontmatter(existingRaw).fm;
      if (existingFm.name === name) break; // same skill, reuse
      // different content → conflict
      slug = `${baseSlug}-${++suffix}`;
      stats.skillConflicts++;
      stats.manualDecisions.push(
        `skill conflict: "${name}" remapped to slug "${slug}" (original slot taken by different skill)`
      );
      continue;
    }
    break;
  }

  const outDir = join(OUT_SKILLS_DIR, slug);
  const outFile = join(outDir, "SKILL.md");

  // Rebuild frontmatter with only required fields for Opencode skills.
  // Preserve extra fm keys under a comment-friendly space? Opencode skill schema is just {name, description}.
  const newFm = buildFrontmatter([
    ["name", name],
    ["description", description],
  ]);
  const newContent = `${newFm}\n${body.startsWith("\n") ? body : "\n" + body}`;

  if (DRY_RUN) {
    stats.skillsPorted++;
    if (VERBOSE) console.log(`[dry][skill] ${skillName} → ${slug}`);
    return;
  }

  await ensureDir(outDir);
  // Write SKILL.md only if changed (idempotency)
  let existing = "";
  if (await fileExists(outFile)) existing = await readFile(outFile, "utf8");
  if (existing !== newContent) {
    await writeFile(outFile, newContent, "utf8");
  }

  // Copy any non-SKILL.md siblings (e.g. references, assets).
  const siblings = await walkFiles(skillDir);
  for (const src of siblings) {
    if (basename(src) === "SKILL.md") continue;
    const rel = relative(skillDir, src);
    const dst = join(outDir, rel);
    if (await filesIdentical(src, dst)) continue;
    await ensureDir(dirname(dst));
    await copyFile(src, dst);
  }

  stats.skillsPorted++;
  if (VERBOSE) console.log(`[skill] ${skillName} → ${slug}`);
}

async function portSkills(): Promise<void> {
  if (!existsSync(V4_SKILLS_DIR)) {
    console.warn(`Skills source missing: ${V4_SKILLS_DIR}`);
    return;
  }
  const entries = await readdir(V4_SKILLS_DIR, { withFileTypes: true });
  for (const e of entries) {
    if (!e.isDirectory()) continue;
    try {
      await portSkill(join(V4_SKILLS_DIR, e.name), e.name);
    } catch (err) {
      stats.skillErrors++;
      console.error(`[skill:error] ${e.name}: ${(err as Error).message}`);
    }
  }
}

// ──────────────────────────────────────────────────────────────
// Agent porting
// ──────────────────────────────────────────────────────────────

// Agents that are not really agents (meta docs, routing tables) → skip
const AGENT_SKIP_NAMES = new Set(["agent-activation-prompts"]);

async function portAgent(srcFile: string): Promise<void> {
  const srcName = basename(srcFile, ".md");
  if (AGENT_SKIP_NAMES.has(srcName)) {
    stats.agentsSkipped++;
    stats.manualDecisions.push(`agent skipped: ${srcName} (meta/non-agent file)`);
    return;
  }

  const raw = await readFile(srcFile, "utf8");
  const { fm, body } = parseFrontmatter(raw);

  const name = fm.name || srcName;
  const description =
    fm.description || extractFirstParagraph(body) || `Agent: ${name}`;

  const isPrimary = detectPrimary(name, body);
  const mode = isPrimary ? "primary" : "subagent";
  const model = fm.model || detectModelHint(body);
  const color = fm.color; // preserve whatever v4 had (hex or theme word)

  const baseSlug = slugify(name);
  let slug = baseSlug;
  let suffix = 1;
  while (true) {
    const candidate = join(OUT_AGENTS_DIR, `${slug}.md`);
    if (await fileExists(candidate)) {
      const existingRaw = await readFile(candidate, "utf8");
      const existingFm = parseFrontmatter(existingRaw).fm;
      // Idempotency: same description + same mode → overwrite.
      if (
        existingFm.description === description &&
        (existingFm.mode ?? "subagent") === mode
      )
        break;
      // Also reuse if the existing file appears to be an exact port of this source
      // (detected by description prefix + name match via heuristic).
      if (!existingFm.description) break;
      slug = `${baseSlug}-${++suffix}`;
      stats.agentConflicts++;
      stats.manualDecisions.push(
        `agent conflict: "${name}" remapped to slug "${slug}" (different existing agent occupies "${baseSlug}")`
      );
      continue;
    }
    break;
  }

  const outFile = join(OUT_AGENTS_DIR, `${slug}.md`);

  const fmLines: Array<[string, string | undefined]> = [
    ["description", description],
    ["mode", mode],
  ];
  if (model) fmLines.push(["model", model]);
  if (color) fmLines.push(["color", color]);

  const newFm = buildFrontmatter(fmLines);
  const newContent = `${newFm}\n${body.startsWith("\n") ? body : "\n" + body}`;

  if (DRY_RUN) {
    stats.agentsPorted++;
    if (VERBOSE) console.log(`[dry][agent] ${srcName} → ${slug} (${mode}${model ? `, ${model}` : ""})`);
    return;
  }

  await ensureDir(OUT_AGENTS_DIR);
  let existing = "";
  if (await fileExists(outFile)) existing = await readFile(outFile, "utf8");
  if (existing !== newContent) {
    await writeFile(outFile, newContent, "utf8");
  }
  stats.agentsPorted++;
  if (VERBOSE) console.log(`[agent] ${srcName} → ${slug} (${mode}${model ? `, ${model}` : ""})`);
}

async function portAgents(): Promise<void> {
  if (!existsSync(V4_AGENTS_DIR)) {
    console.warn(`Agents source missing: ${V4_AGENTS_DIR}`);
    return;
  }
  const entries = await readdir(V4_AGENTS_DIR, { withFileTypes: true });
  for (const e of entries) {
    if (!e.isFile() || !e.name.endsWith(".md")) continue;
    const src = join(V4_AGENTS_DIR, e.name);
    try {
      await portAgent(src);
    } catch (err) {
      stats.agentErrors++;
      console.error(`[agent:error] ${e.name}: ${(err as Error).message}`);
    }
  }
}

// ──────────────────────────────────────────────────────────────
// Main
// ──────────────────────────────────────────────────────────────

async function main() {
  console.log(
    `Port v4 → Opencode${DRY_RUN ? " (dry-run)" : ""}\n` +
      `  skills src: ${V4_SKILLS_DIR}\n` +
      `  agents src: ${V4_AGENTS_DIR}\n` +
      `  skills out: ${OUT_SKILLS_DIR}\n` +
      `  agents out: ${OUT_AGENTS_DIR}`
  );

  await ensureDir(OUT_SKILLS_DIR);
  await ensureDir(OUT_AGENTS_DIR);

  await portSkills();
  await portAgents();

  console.log("\n=== STATS ===");
  console.log(JSON.stringify(stats, null, 2));
}

await main();
