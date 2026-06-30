# Artisyn SKILL.md Structure Guide

**Standard structure following Anthropic Agent Skills format**

---

## Complete Template

```yaml
---
# Frontmatter (see metadata-schema.md for details)
name: skill-name
description: What it does. Triggers: "phrase 1", "phrase 2".
license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata:
  category: automation
  level: "000"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-02-15"
  tags: [tag1, tag2]
---

# Skill Name

Brief overview of what the skill does.

## Quick Start

Minimal example to get started:
```
"Do X with Y"
```

Agent will: [what happens]

## Core Workflow

### Step 1: First Action
What to do and why.

### Step 2: Next Action
What to do and why.

## Advanced Features

Optional advanced usage.

## Skill Resources

- [guide](references/guide.md) - Detailed guide
- [schema](references/schema.md) - Schema reference

## Troubleshooting

### Issue: Problem
**Solution:** How to fix
```

---

## Section Order

**Required:**
1. Title (# Skill Name)
2. Quick Start
3. Core Workflow

**Optional (in order):**
4. Installation
5. Environment Variables
6. Authentication
7. Advanced Features
8. Skill Resources
9. Best Practices
10. Troubleshooting
11. Acceptance Criteria

---

## Guidelines

### Keep Concise
- SKILL.md body: <5000 tokens
- Move details to references/
- Use progressive disclosure

### Use Standard Sections
- Quick Start: Minimal example
- Core Workflow: Step-by-step
- Advanced Features: Optional usage

### Link to Resources
```markdown
See [guide](references/guide.md) for details.
```

### MCP Operations
```markdown
**Use MCP tools:**
"Create skill X"
"Validate skill Y"
```

---

## Resource Locations

```
skill-name/
├── scripts/          # Helper scripts (.py)
├── references/       # Documentation (.md)
└── assets/          # Templates, configs
```

**Access via MCP:**
```
"Get script helper.py from skill-name"
"Show references/guide.md from skill-name"
```

---

**See also:**
- [metadata-schema.md](metadata-schema.md) - Complete schema
- [validation-rules.md](validation-rules.md) - Validation checklist
