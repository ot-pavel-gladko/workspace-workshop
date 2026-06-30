# Artisyn Skill Metadata Schema

**Anthropic Agent Skills standard + Artisyn extensions**

---

## Complete Schema

```yaml
---
# === ANTHROPIC STANDARD (Required) ===

name: skill-name                    # lowercase, hyphens, 1-64 chars, unique

description: |                      # 1-1024 chars - BE COMPREHENSIVE!
  What the skill does (list key functionality). When to use it (scenarios). 
  Use when [trigger phrases]. Triggers: "phrase 1", "phrase 2", "phrase 3".
  
  IMPORTANT: List ALL major capabilities, not just summary. Agent needs to know 
  full functionality to decide when to use this skill.
  
  Example: "Create comprehensive PIR documents from work sessions. Analyzes objectives, 
  actions taken, issues encountered, solutions applied, and automation opportunities. 
  Generates structured markdown with lessons learned. Saves to docs/pirs/ directory. 
  Integrates with git history and session logs. Use after completing any significant 
  work or project phase. Triggers: 'create PIR', 'post-implementation review', 
  'document work session', 'lessons learned'."

# === ANTHROPIC STANDARD (Artisyn Required) ===

license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.  # MUST be exact

# === ANTHROPIC STANDARD (Optional) ===

compatibility: Environment requirements  # Optional, max 500 chars
allowed-tools: Bash(git:*) Read Write   # Optional, experimental

# === ARTISYN EXTENSIONS (Required) ===

metadata:
  # Organization
  category: automation              # Required: automation, sdlc-process, platform, ai-domain, agent-development, agent-deployment, web-ui, data-lake, project-knowledge
  subcategory: meta                 # Optional: secondary categorization
  level: "000"                      # Required: 3-digit string (000-999)
  
  # Versioning
  author: dataart-aila              # Required: fixed value
  version: "1.0.0"                  # Required: semver (X.Y.Z)
  last_updated: "2026-02-15"        # Required: ISO date (YYYY-MM-DD)
  
  # Discovery
  tags: [tag1, tag2]                # Required: array, at least 1 tag
  
  # Complexity (Optional)
  skill_type: skill                 # Optional: skill | prompt (default: skill)
  estimated_duration: 30-60min      # Optional: 5-10min, 10-30min, 30-60min, 1-2h, 2-4h, 4-8h
  difficulty: intermediate          # Optional: beginner, intermediate, advanced
  environment: desktop              # Optional: desktop, cloud, both
---

# Skill Name

[Skill content...]
```

---

## Valid Values

### Categories
```
automation, sdlc-process, platform, ai-domain, agent-development, 
agent-deployment, web-ui, data-lake, project-knowledge
```

### Levels
```
000-099: System/automation
100-199: Core processes
200-299: Platform knowledge
300-399: Domain-specific
400-499: Advanced features
500-999: Specialized/custom
```

### Durations
```
5-10min, 10-30min, 30-60min, 1-2h, 2-4h, 4-8h
```

### Difficulties
```
beginner, intermediate, advanced
```

### Environments
```
desktop, cloud, both
```

---

## Validation

**Use MCP tools:**
```
"Validate skill [skill-name]"
```

**Checks:**
- ✅ All required fields present
- ✅ License is exact DataArt text
- ✅ Level is 3-digit string
- ✅ Category is valid
- ✅ Tags array has at least 1 tag
- ✅ Dates are ISO format
- ✅ Version is semver

---

## Examples

### Minimal (Required fields only)
```yaml
---
name: my-skill
description: Does X. Triggers: "do X".
license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata:
  category: automation
  level: "000"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-02-15"
  tags: [automation]
---
```

### Complete (All fields)
```yaml
---
name: post-implementation-review
description: Create comprehensive PIR documents. Triggers: "create PIR", "post-implementation review".
license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
compatibility: Requires session logs, git history, Confluence API
metadata:
  category: sdlc-process
  subcategory: documentation
  level: "001"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-02-15"
  tags: [pir, documentation, lessons-learned]
  skill_type: skill
  estimated_duration: 30-60min
  difficulty: intermediate
  environment: desktop
---
```

---

**Status:** Final  
**Use with:** MCP tools for validation
