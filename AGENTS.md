# Repository Guidelines — agent-skills

This repository is the canonical source of cross-repo Agent Skills used across
every mazrean project. Skills are referenced by [apm](https://github.com/microsoft/apm)
from `mazrean/apm-plackage/*` and individual repositories' `apm.yml`.

## Layout

```
skills/
  <skill-name>/
    SKILL.md             # description + frontmatter (auto-discovery metadata)
    [reference/*.md]     # optional supporting reference files
  <single-file>.md       # short single-file skills are also allowed
```

A skill directory is referenced from a consumer repo's `apm.yml` like:

```yaml
dependencies:
  apm:
    - mazrean/agent-skills/skills/committing-code
    - mazrean/agent-skills/skills/writing-feature-spec
```

## Authoring

- Use the `creating-agent-skills` skill in this repo as the authoring guide.
- Each `SKILL.md` MUST start with frontmatter containing `description:` (used by
  Claude Code / apm for auto-discovery). Keep the description concrete — say what
  the skill does and when to invoke it.
- Reference files (loaded only on demand) belong in the skill directory; SKILL.md
  links to them.
- Single-file skills (e.g. `web-performance-optimization.md`) are acceptable when
  the content fits in one file.

## Categories

- `writing-*` — spec-driven development (PRD, design, tasks, constitution). These
  replace `cc-sdd` and `github/spec-kit` org-wide.
- `building-*` — framework / library tutorials (Lit, templ, RSS feeds, etc.).
- `using-*` — toolchain idioms (Go tool directive, UnoCSS-with-templ).
- `creating-*` — meta skills (creating new skills, creating test cases).
- `committing-code`, `releasing-zig-with-goreleaser` — workflow skills.
- `web-performance-optimization`, `frontend-design` — design / perf reference.
- `winning-web-speed-hackathon`, `checking-wsh-vrt`, `planning-wsh-improvements`,
  `sharing-sockets-with-so-reuseport-in-zig`, `writing-zig-cli-tools` — domain
  references.

## Conventions

- Skills must NOT contain repo-specific information (file paths, internal URLs).
  Repo-specific guidance belongs in the consumer's `AGENTS.md` or in
  `mazrean/apm-plackage/<stack>/.apm/instructions/`.
- Bump the `version:` field in skill SKILL.md frontmatter (when present) on every
  behavioural change so consumers can pin.
- New skills used by 2+ repos belong here, not in individual repos.
