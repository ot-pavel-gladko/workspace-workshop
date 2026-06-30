# Migration Guide

**Purpose:** Guide for migrating existing Artisyn skills to Anthropic standard format

**Use with:** skill-creator-aila "Migrating Existing Skill" workflow

---

## Pre-Migration Checklist

### 1. Identify Source of Truth

**Problem:** Skills may exist in multiple locations

**Check these locations:**
```bash
# Steering directory
ls -la .kiro/steering/*/

# Skills directory
ls -la .kiro/skills/*/

# Project-specific copies
find . -name "*skill*.md" -type f
```

**Identify symlinks:**
```bash
# Find all symlinks
find . -type l -ls | grep skill

# Check where symlink points
ls -la path/to/symlink
readlink path/to/symlink
```

**Questions to answer:**
- [ ] Is this a symlink or real file?
- [ ] Where does symlink point?
- [ ] Which version is most recent?
- [ ] Which version is most complete?
- [ ] Are there multiple symlinks to same skill?

**Document findings:**
```
Skill: post-implementation-review
Locations found:
  1. .kiro/steering/001-sdlc-process/pir/post_implementation_review_skill.md (symlink → .kiro/skills/...)
  2. .kiro/skills/001-sdlc-process/pir/post_implementation_review_skill.md (real file)
  3. ../aila-prompts-lib/skills/001-sdlc-process/pir/post_implementation_review_skill.md (real file)

Source of truth: ../aila-prompts-lib/skills/... (most recent, most complete)
```

---

### 2. Deduplication

**Problem:** Multiple versions may have differences

**Compare versions:**
```bash
# Compare two files
diff file1.md file2.md

# Show differences side by side
diff -y file1.md file2.md | less

# Count differences
diff file1.md file2.md | wc -l
```

**Questions to answer:**
- [ ] Are versions identical?
- [ ] What are the differences?
- [ ] Which version has better content?
- [ ] Should we merge or keep separate?

**Decision matrix:**

| Scenario | Action |
|----------|--------|
| Identical | Use any version |
| Minor differences (typos, formatting) | Use most recent |
| Major differences (different content) | Merge best parts |
| Completely different | Keep as separate skills |

**Document decision:**
```
Versions compared:
  - Version A: Last updated 2026-01-15, has examples
  - Version B: Last updated 2026-02-10, has better workflow

Decision: Merge - use workflow from B, examples from A
Rationale: B has improvements, A has useful examples
```

---

### 3. Symlink Structure Analysis

**Problem:** Old symlink structure may be complex

**Map old structure:**
```bash
# Create visual map
tree -L 3 .kiro/steering/
tree -L 3 .kiro/skills/

# Document symlink chain
ls -la .kiro/steering/001-sdlc-process/pir/
# → points to .kiro/skills/001-sdlc-process/pir/
ls -la .kiro/skills/001-sdlc-process/pir/
# → points to ../aila-prompts-lib/skills/...
```

**Document for reference:**
```
Old symlink structure:
  .kiro/steering/001-sdlc-process/pir/post_implementation_review_skill.md
    → .kiro/skills/001-sdlc-process/pir/post_implementation_review_skill.md
      → ../aila-prompts-lib/skills/001-sdlc-process/pir/post_implementation_review_skill.md

New structure:
  skills/post-implementation-review/SKILL.md (real file)
  
New symlink (if needed):
  .kiro/steering/post-implementation-review.yaml → skills/post-implementation-review/SKILL_META.yaml
```

---

## Migration Mapping

### Old Metadata Format → New YAML Frontmatter

**Old format (Markdown section):**
```markdown
## Metadata
- **Category**: 001-sdlc-process/pir
- **Target Type**: library
- **Version**: 1.0.0
- **Last Updated**: 2026-02-07
```

**New format (YAML frontmatter):**
```yaml
---
name: post-implementation-review
description: Create comprehensive PIR documents. Triggers - create PIR, post-implementation review.
license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata:
  category: sdlc-process
  level: "001"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-02-07"
  tags: [pir, documentation]
---
```

---

### Field Mapping Rules

**Category:**
```
Old: Category: 001-sdlc-process/pir
New: category: sdlc-process
     level: "001"
     subcategory: pir (optional)

Pattern: {level}-{category}/{subcategory}
→ category: {category}
→ level: "{level}"
→ subcategory: {subcategory} (optional)
```

**Target Type:**
```
Old: Target Type: library
New: (removed - not needed)

Rationale: All skills are reusable, no distinction needed
```

**Version:**
```
Old: Version: 1.0.0
New: metadata.version: "1.0.0"

Keep same version number
```

**Last Updated:**
```
Old: Last Updated: 2026-02-07
New: metadata.last_updated: "2026-02-07"

Keep same date, ensure ISO format (YYYY-MM-DD)
```

**New Required Fields:**
```
name: (extract from filename or title)
description: (extract from Overview or create)
license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata.author: dataart-aila
metadata.tags: [extract from content or create]
```

---

### Section Mapping

**Old sections → New sections:**

| Old Section | New Section | Notes |
|-------------|-------------|-------|
| Metadata | YAML frontmatter | Convert to YAML |
| Overview | Quick Start | Condense to essential |
| Purpose | (merge into description) | Add to frontmatter description |
| Parameters | Environment Variables or Quick Start | Depends on type |
| Instructions | Core Workflow | Rename, keep content |
| Output Format | Core Workflow or Advanced Features | Integrate into workflow |
| Best Practices | Best Practices | Keep as-is |
| Example Use Cases | Quick Start or Advanced Features | Move to appropriate section |
| Related Files | Reference Files | Update to markdown links |

---

### File Structure Mapping

**Old structure:**
```
.kiro/skills/001-sdlc-process/pir/
├── post_implementation_review_skill.md
├── pir_template.md
└── examples.md
```

**New structure:**
```
skills/post-implementation-review/
├── SKILL.md
├── SKILL_META.yaml
└── references/
    ├── pir-template.md
    └── examples.md
```

**Mapping rules:**
- Main skill file → `SKILL.md`
- Supporting docs → `references/`
- Scripts → `scripts/`
- Templates → `assets/`

---

## What to Preserve

### ✅ Keep

**Content:**
- All instructions and workflows
- Examples and use cases
- Best practices
- Troubleshooting tips

**Files:**
- Supporting documentation
- Scripts and tools
- Templates and assets

**History:**
- Version information
- Last updated date
- Git history (via git log)

---

### ❌ Discard

**Metadata:**
- Old metadata format (replaced by YAML)
- Target Type field (not needed)
- Redundant category information

**Content:**
- Outdated information
- Deprecated workflows
- Broken links to removed files

**Structure:**
- Old directory hierarchy
- Old symlink structure
- Redundant copies

---

## What to Add

### Required Additions

**YAML frontmatter:**
- name (from filename)
- description (from Overview or create)
- license (DataArt proprietary - exact text)

**Metadata fields:**
- category (from old Category)
- level (from old Category number)
- author: dataart-aila
- version (from old Version)
- last_updated (from old Last Updated)
- tags (create from content)

**Files:**
- SKILL_META.yaml (auto-generated by create_skill.py)

---

### Optional Additions

**Metadata fields:**
- subcategory (from old Category)
- estimated_duration (estimate from content)
- difficulty (estimate from complexity)
- environment (desktop/cloud/both)

**Sections:**
- Acceptance Criteria (for testing)
- Troubleshooting (if not present)

---

## Migration Workflow

**Migration follows a structured SDLC-like process with approval gates.**

**Important:** Migrate ONE skill at a time. No bulk migration supported.

---

### Phase 1: Requirements (Understand)

**Goal:** Understand what needs to be migrated

**Steps:**
1. Identify skill to migrate
2. Find all copies (steering, skills, projects)
3. Analyze symlink structure
4. Check for duplicates
5. Document findings

**Output:** Requirements document
```
Skill: post-implementation-review
Current location: .kiro/steering/001-sdlc-process/pir/
Copies found: 2 (steering symlink, skills real file)
Source of truth: .kiro/skills/001-sdlc-process/pir/post_implementation_review_skill.md
Symlinks: 1 (steering → skills)
Duplicates: None
```

**Approval Gate:** User confirms this is correct skill and source

---

### Phase 2: Clarification (Decide)

**Goal:** Make migration decisions

**Questions to answer:**
- Which version is source of truth?
- Should we merge multiple versions?
- What content to preserve?
- What content to discard?
- What new information to add?

**Output:** Migration decisions document
```
Source: .kiro/skills/001-sdlc-process/pir/post_implementation_review_skill.md
Merge: No (only one version)
Preserve: All content, examples, workflow
Discard: Old metadata format
Add: Tags [pir, documentation, lessons-learned]
Add: Trigger phrases in description
```

**Approval Gate:** User approves migration decisions

---

### Phase 3: Research (Analyze)

**Goal:** Analyze old format and plan mapping

**Steps:**
1. Read old skill thoroughly
2. Identify sections
3. Map to new structure
4. Identify supporting files
5. Plan file organization

**Output:** Migration plan
```
Old sections → New sections:
- Metadata → YAML frontmatter
- Overview → Quick Start
- Instructions → Core Workflow
- Best Practices → Best Practices
- Example Use Cases → Advanced Features

Supporting files:
- pir_template.md → references/pir-template.md
- examples.md → references/examples.md

New structure:
skills/post-implementation-review/
├── SKILL.md
├── SKILL_META.yaml
└── references/
    ├── pir-template.md
    └── examples.md
```

**Approval Gate:** User approves migration plan

---

### Phase 4: Design (Create)

**Goal:** Create new skill in Anthropic format

**Steps:**
1. Generate YAML frontmatter
2. Map content to new sections
3. Update markdown links
4. Move supporting files
5. Create SKILL_META.yaml

**Output:** New skill (draft)
```
skills/post-implementation-review/
├── SKILL.md (complete)
├── SKILL_META.yaml (generated)
└── references/
    ├── pir-template.md
    └── examples.md
```

**Approval Gate:** User reviews draft skill

---

### Phase 5: Approval (Validate)

**Goal:** Validate migrated skill

**Steps:**
1. Validate with skills-ref
2. Validate with validate_skill.py
3. Check all links work
4. Test skill functionality
5. Compare with original (nothing lost)

**Output:** Validation report
```
✅ Anthropic standard: PASS
✅ Artisyn requirements: PASS
✅ Structure: PASS
✅ SKILL_META.yaml: PASS
✅ All links work
✅ Skill tested successfully
✅ All content preserved
```

**Approval Gate:** User approves for implementation

---

### Phase 6: Implementation (Deploy)

**Goal:** Replace old skill with new skill

**Steps:**
1. Commit new skill to git
2. Update references to new location
3. Remove old skill (after backup)
4. Update symlinks if needed
5. Document migration

**Output:** Migration complete
```
Committed: skills/post-implementation-review/
Updated: References in other skills
Removed: .kiro/skills/001-sdlc-process/pir/ (backed up)
Updated: .kiro/steering/ symlinks
Documented: In commit message and migration log
```

**Final Approval:** User confirms migration complete

---

## Migration Checklist (Per Skill)

### Phase 1: Requirements ✓
- [ ] Skill identified
- [ ] All copies found
- [ ] Symlinks documented
- [ ] Duplicates checked
- [ ] **User approved requirements**

### Phase 2: Clarification ✓
- [ ] Source of truth identified
- [ ] Merge decisions made
- [ ] Content preservation decided
- [ ] New information planned
- [ ] **User approved decisions**

### Phase 3: Research ✓
- [ ] Old format analyzed
- [ ] Sections mapped
- [ ] Supporting files identified
- [ ] New structure planned
- [ ] **User approved plan**

### Phase 4: Design ✓
- [ ] YAML frontmatter created
- [ ] Content mapped to new sections
- [ ] Links updated
- [ ] Files moved
- [ ] SKILL_META.yaml generated
- [ ] **User reviewed draft**

### Phase 5: Approval ✓
- [ ] skills-ref validation passed
- [ ] Artisyn validation passed
- [ ] Links verified
- [ ] Functionality tested
- [ ] Content compared
- [ ] **User approved for implementation**

### Phase 6: Implementation ✓
- [ ] Committed to git
- [ ] References updated
- [ ] Old skill removed
- [ ] Symlinks updated
- [ ] Migration documented
- [ ] **User confirmed complete**

---

## Why No Bulk Migration?

**Reasons:**
1. **Each skill is unique** - Different formats, structures, content
2. **Decisions required** - Merge? Preserve? Discard? (human judgment)
3. **Quality control** - Each skill needs review and testing
4. **Risk management** - One skill at a time limits blast radius
5. **Learning** - Each migration improves process

**Approach:**
- Migrate one skill at a time
- Learn from each migration
- Improve process iteratively
- Build confidence before next migration

---

## Use skill-creator-aila "Migrating Existing Skill" workflow:

### Step 1: Pre-Migration Analysis
1. Find all copies of skill
2. Identify source of truth
3. Check for duplicates
4. Document symlink structure

### Step 2: Content Preparation
1. Read source skill
2. Extract metadata
3. Identify sections
4. Note supporting files

### Step 3: Generate New Format
1. Create YAML frontmatter (use mappings above)
2. Map sections to new structure
3. Update markdown links
4. Move supporting files

### Step 4: Validation
1. Validate with skills-ref
2. Validate with validate_skill.py
3. Check all links work
4. Test skill functionality

### Step 5: Cleanup
1. Document migration in commit message
2. Update references to new location
3. Remove old copies (after validation)
4. Update symlinks if needed

---

## Common Migration Issues

### Issue 1: Multiple Versions with Differences

**Problem:** Skill exists in 3 places with different content

**Solution:**
1. Compare all versions:
   ```bash
   diff -y version1.md version2.md | less
   ```
2. Identify best parts of each
3. Merge into single version
4. Document merge in commit:
   ```
   Merged 3 versions of PIR skill:
   - Used workflow from version B (most recent)
   - Added examples from version A (more complete)
   - Discarded version C (outdated)
   ```

---

### Issue 2: Complex Symlink Structure

**Problem:** Multiple levels of symlinks, hard to find source

**Solution:**
1. Follow symlink chain:
   ```bash
   readlink -f path/to/symlink  # Shows final target
   ```
2. Document chain for reference
3. Migrate from final target (source of truth)
4. Create new simple structure (no nested symlinks)

---

### Issue 3: Missing Required Information

**Problem:** Old format missing fields required by new format

**Solution:**

| Missing Field | How to Fill |
|---------------|-------------|
| name | Extract from filename (remove _skill.md, use hyphens) |
| description | Extract from Overview or first paragraph |
| tags | Analyze content, extract key terms |
| category | Infer from directory path |
| level | Extract from directory path number |

**Example:**
```
Old: .kiro/skills/001-sdlc-process/pir/post_implementation_review_skill.md

Extract:
- name: post-implementation-review (from filename)
- category: sdlc-process (from path)
- level: "001" (from path)
- tags: [pir, documentation] (from content analysis)
```

---

### Issue 4: Inconsistent Old Format

**Problem:** Old skill doesn't follow standard format

**Solution:**
1. Don't try to parse automatically
2. Read content manually
3. Extract information by understanding, not pattern matching
4. Create new skill following new format
5. Preserve all useful content

**Example:**
```
Old skill has:
- No metadata section
- Custom structure
- Mixed content

Approach:
1. Read and understand what skill does
2. Create new SKILL.md from scratch
3. Copy useful content into appropriate sections
4. Add proper metadata
5. Validate
```

---

### Issue 5: Broken Links

**Problem:** Old skill references files that don't exist

**Solution:**
1. Identify broken links:
   ```bash
   grep -r "\[.*\](.*)" SKILL.md
   ```
2. For each link:
   - If file exists elsewhere: update path
   - If file missing: remove link or create placeholder
   - If external: verify URL still works
3. Update to relative markdown links:
   ```markdown
   Old: Uses: `path/to/file.md`
   New: See [file](./references/file.md)
   ```

---

## Migration Checklist

**Before migration:**
- [ ] Found all copies of skill
- [ ] Identified source of truth
- [ ] Checked for duplicates
- [ ] Documented symlink structure
- [ ] Compared versions if multiple exist

**During migration:**
- [ ] Created YAML frontmatter with all required fields
- [ ] Mapped all sections to new structure
- [ ] Moved supporting files to correct directories
- [ ] Updated all links to markdown format
- [ ] Preserved all useful content

**After migration:**
- [ ] Validated with skills-ref
- [ ] Validated with validate_skill.py
- [ ] Tested all links work
- [ ] Tested skill functionality
- [ ] Documented migration in commit message

---

## Example Migration

### Before (Old Format)

**File:** `.kiro/skills/001-sdlc-process/pir/post_implementation_review_skill.md`

```markdown
# Post-Implementation Review (PIR) Skill

## Metadata
- **Category**: 001-sdlc-process/pir
- **Target Type**: library
- **Version**: 1.0.0
- **Last Updated**: 2026-02-07

## Overview
Creates comprehensive PIR documents from work sessions.

## Instructions
1. Gather session logs
2. Analyze work
3. Generate PIR
```

---

### After (New Format)

**File:** `skills/post-implementation-review/SKILL.md`

```yaml
---
name: post-implementation-review
description: Create comprehensive PIR documents from work sessions. Triggers - create PIR, post-implementation review.
license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata:
  category: sdlc-process
  subcategory: pir
  level: "001"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-02-07"
  tags: [pir, documentation, lessons-learned]
---

# Post-Implementation Review (PIR)

Create comprehensive PIR documents from work sessions.

## Quick Start

```
"Create PIR from session logs"
```

## Core Workflow

1. Gather session logs
2. Analyze work performed
3. Generate PIR document
4. Save to docs/pirs/
```

**File:** `skills/post-implementation-review/SKILL_META.yaml`

```yaml
name: post-implementation-review
description: Create comprehensive PIR documents from work sessions. Triggers - create PIR, post-implementation review.
category: sdlc-process
level: "001"
tags: [pir, documentation, lessons-learned]
skill_path: ./SKILL.md
```

---

**Status:** Migration Reference  
**Use:** When migrating existing Artisyn skills to Anthropic format
