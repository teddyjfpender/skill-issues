# Codex Skills: Installation

This repo includes packaged Codex skills under `skills/` and `dist/`. Use **one** of the installation options below, then restart Codex so it can load the new skills.

## Option A — User-scoped (available in all repos)

```bash
mkdir -p ~/.codex/skills
cp -R ./skills/cairo-* ~/.codex/skills/
```

## Option B — Repo-scoped (checked into this repo)

```bash
mkdir -p ./.codex/skills
cp -R ./skills/cairo-* ./.codex/skills/
```

## Using packaged `.skill` files

If you prefer the packaged `.skill` archives (zip files), unzip them into a skill location:

```bash
mkdir -p ~/.codex/skills
unzip ./dist/cairo-*.skill -d ~/.codex/skills
```

## Notes

- Codex loads skills from `~/.codex/skills/` (user-scoped) and `.codex/skills/` in a repo (repo-scoped).
- After installing or updating skills, restart Codex to pick them up.
- Reference: Codex skills documentation — <https://developers.openai.com/codex/skills/create-skill?utm_source=openai>
