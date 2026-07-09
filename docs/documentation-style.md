---
title: "Documentation Style"
description: "Rules for adding Markdown documentation files to modbus2mqtt."
audience:
  - agents
  - maintainers
status: "active"
related:
  - "../DOCUMENTATION.md"
  - "../README.md"
---

# Documentation Style

Use front matter for agent-oriented Markdown documentation. The exception is `README.md`, which stays plain Markdown because it is the public GitHub landing page for humans and agents.

## Required Front Matter

Every Markdown file under `docs/` and the root `DOCUMENTATION.md` should start with:

```yaml
---
title: "Short Human Title"
description: "One sentence describing what the document covers."
audience:
  - agents
  - maintainers
status: "active"
related:
  - "../README.md"
---
```

## Field Guidance

- `title`: short display title.
- `description`: concise routing summary for search and agents.
- `audience`: intended readers. Use `agents`, `maintainers`, or `users` as appropriate.
- `status`: lifecycle state. Prefer `active`, `draft`, or `archived`.
- `entry_point`: set to `true` only for the main documentation index.
- `front_matter_required`: set to `true` on the documentation index to make the convention explicit.
- `related`: nearby source files or documentation files that help interpret the page.

## Writing Rules

- Keep `README.md` optimized for GitHub readers and common quick-start tasks.
- Keep detailed implementation notes in front-matter Markdown files.
- Prefer focused topic files over one large document when the content helps agents route tasks.
- Use `container` in workflows and examples. Use `docker` only when a required option is unavailable through `container`.

