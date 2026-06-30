# Artisyn Skill Validation Rules

**Purpose:** Validation checklist for Artisyn skills

---

## Anthropic Standard Validation

**Use MCP tools:**
```
"Validate skill [skill-name]"
```

**Checks:**
- ✅ YAML frontmatter is valid
- ✅ Required fields present (name, description)
- ✅ Name format valid (lowercase, hyphens, 1-64 chars)
- ✅ No reserved words (anthropic, claude)
- ✅ Description length (1-1024 chars)
- ✅ No XML tags in description

---

## Artisyn-Specific Validation

### Required Fields

**License (MUST be exact):**
```yaml
license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
```

**Metadata (Required):**
```yaml
metadata:
  category: automation           # Required, from valid list
  level: "000"                   # Required, 3-digit string
  author: dataart-aila           # Required, exact value
  version: "1.0.0"               # Required, semver format
  last_updated: "2026-02-14"     # Required, ISO date (YYYY-MM-DD)
  tags: [tag1, tag2]             # Required, array with at least 1 tag
```

---

## Validation Checklist

### Metadata Validation

- [ ] **name** is unique identifier
- [ ] **name** is lowercase with hyphens only
- [ ] **name** is 1-64 characters
- [ ] **description** includes trigger phrases
- [ ] **license** is exact DataArt proprietary text
- [ ] **metadata.category** is from valid list
- [ ] **metadata.level** is 3-digit string (000-999)
- [ ] **metadata.author** is "dataart-aila"
- [ ] **metadata.version** follows semver (X.Y.Z)
- [ ] **metadata.last_updated** is ISO date (YYYY-MM-DD)
- [ ] **metadata.tags** is array with at least 1 tag

---

### Content Validation

- [ ] Title section exists (# Skill Name)
- [ ] Quick Start section exists
- [ ] Body is concise (<5000 tokens recommended)
- [ ] Markdown links use standard format
- [ ] Reference resources exist if linked
- [ ] Scripts exist if mentioned
- [ ] No broken links
- [ ] **No absolute paths** (all paths must be relative)
- [ ] **Skill references use correct format** (see Link Standards below)
- [ ] **Inputs documented** (if metadata.inputs present)
- [ ] **Outputs documented** (if metadata.outputs present)

---

### Link Standards

**Two types of links:**

**1. Resources within skill:**
```markdown
[metadata schema](references/metadata-schema.md)
[create script](scripts/create_skill.py)
[template](assets/template.yaml)
```
**Rule:** Relative markdown links

**2. External links:**
```markdown
See [Anthropic Docs](https://docs.anthropic.com) for details.
See [GitHub Repo](https://github.com/org/repo) for source.
```
**Rule:** Full URLs

**For other skills:** Use MCP tools, not links
```
"Show me skill-discovery skill"
```

---

### SKILL_META.yaml Validation

- [ ] SKILL_META.yaml exists
- [ ] Contains required fields: name, description, category, level, tags
- [ ] All fields match SKILL.md frontmatter
- [ ] No absolute paths

---

### Structure Validation

- [ ] Skill name is unique
- [ ] SKILL.md exists with instructions
- [ ] scripts/ (if present) contains .py resources
- [ ] references/ (if present) contains .md resources
- [ ] assets/ (if present) contains templates/configs

---

## Valid Categories

```
automation
sdlc-process
platform
ai-domain
agent-development
agent-deployment
web-ui
data-lake
project-knowledge
```

---

## Valid Level Ranges

```
000-099: System/automation (most fundamental)
100-199: Core processes
200-299: Platform knowledge
300-399: Domain-specific
400-499: Advanced features
500-999: Specialized/custom
```

**Any 3-digit number is valid.**

---

## Common Issues

### Issue 1: Invalid License
**Problem:** License text doesn't match exactly  
**Fix:** Copy exact text from metadata-schema.md

### Issue 2: Level Not String
**Problem:** `level: 000` (number instead of string)  
**Fix:** `level: "000"` (quoted string)

### Issue 3: Missing Tags
**Problem:** `tags: []` (empty array)  
**Fix:** Add at least one tag: `tags: [automation]`

### Issue 4: Invalid Category
**Problem:** Category not in valid list  
**Fix:** Use one of the valid categories listed above

### Issue 5: Name Mismatch
**Problem:** Skill name doesn't match metadata name  
**Fix:** Update metadata.name to match

### Issue 6: Absolute Path
**Problem:** Absolute path in metadata or links  
**Fix:** Use relative markdown links: `[guide](references/guide.md)`

### Issue 7: Incorrect Skill Reference
**Problem:** Hardcoded skill reference  
**Fix:** Use MCP tool: `get_skill("other-skill")`

---

## Validation with MCP

**Use MCP tools:**
```
"Validate skill [skill-name]"
```

**Returns:**
```
✅ Anthropic standard: PASS
✅ Artisyn license: PASS
✅ Artisyn metadata: PASS
✅ Structure: PASS

Skill is valid!
```

---

## Manual Validation

**Quick check:**
```bash
# 1. Check frontmatter
head -30 SKILL.md

# 2. Validate with skills-ref
skills-ref validate .

# 3. Check structure
ls -la

# 4. Check links
grep -r "](references/" SKILL.md
```

---

**Status:** Validation Reference  
**Use:** When validating Artisyn skills
