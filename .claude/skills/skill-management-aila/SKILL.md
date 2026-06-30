---
name: skill-management-aila
description: |
  Guide for discovering, searching, and managing Artisyn skills using catalog tools. 
  Lists all available skills, searches by category/tags, views complete skill definitions,
  accesses skill resources (scripts/references/assets), creates new skills with auto-generated metadata,
  migrates existing skills to Artisyn format, validates skills against standards, and manages skill libraries.
  
  Use when managing Artisyn skill catalog, discovering available capabilities, creating new skills,
  or migrating legacy skills. Handles both project-specific and shared library skills.
  
  Triggers: "list skills", "find skills", "create skill", "skill management", "validate skill", 
  "migrate skill", "skill catalog", "what skills available".

license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata:
  category: agent-development
  level: "000"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-03-03"
  tags: [skill-catalog, skill-discovery, skill-creation, skill-validation, skill-migration, catalog-tools, aila-skills]
---

# Skill Management (AILA)

Guide for discovering, searching, and managing Artisyn skills using catalog tools.

## About Artisyn Skills

Artisyn skills are modular, self-contained packages that extend Claude's capabilities with specialized knowledge, workflows, and tools. They follow the **Anthropic Agent Skills standard** with **Artisyn-specific extensions in metadata**.

**Key characteristics:**
- 100% Anthropic standard compliant
- Artisyn extensions in `metadata` field
- Proprietary DataArt license
- Accessed via catalog tools (storage-agnostic)

**Reference documentation:**
- [Anthropic Skills Specification](artifacts/anthropic-skills-spec/specification.md) - Official format specification
- [What Are Skills](artifacts/anthropic-skills-spec/what-are-skills.md) - Conceptual overview
- [Integrate Skills](artifacts/anthropic-skills-spec/integrate-skills.md) - Integration guide
- [skills-ref SDK](artifacts/anthropic-skills-spec/skills-ref-sdk.md) - Reference SDK documentation

**Use these references when:**
- Understanding skill format requirements
- Validating skill structure
- Learning about Anthropic standard features
- Implementing skill integrations

---

## Quick Start

**Discover available skills:**
```
"List all skills" or "What skills are available?"
```

**Search for skills:**
```
"Find skills for documentation" or "Show me automation skills"
```

**View skill details:**
```
"Show me the post-implementation-review skill"
```

**Get skill resource:**
```
"Get the metadata schema from skill-management-aila"
```

**Validate skill:**
```
"Validate skill post-implementation-review"
```

**Create a new skill:**
```
"Create a new skill called [skill-name] for [purpose]"
```

**Note:** Agent uses skill management tools automatically. No need to specify tool names.

---

## Core Workflow: Discovering Skills

### Step 1: List All Skills

**Use skill management tools:**
```
"List all available skills"
```

**Agent will:**
- Discover skills from all installed libraries
- Return minimal metadata (name, description, category, tags)
- Group by source provider

**Result:**
- List of skills with discovery metadata
- Source information (which library)
- Category and level organization

---

### Step 2: Search for Specific Skills

**Filter by category:**
```
"Show me automation skills"
```

**Filter by tags:**
```
"Find skills tagged with documentation"
```

**Text search:**
```
"Find PIR skills"
```

**Agent will:**
- Use aila_search_skills() tool
- Apply filters (category, tags, query)
- Return matching skills

---

### Step 3: Get Full Skill Definition

**View complete skill:**
```
"Show me the post-implementation-review skill"
```

**Agent will:**
- Use aila_get_skill() tool
- Return instructions (SKILL.md content)
- Return full metadata
- Return resource structure

**Result:**
- Complete skill instructions
- All metadata fields
- List of available resources (scripts, references, assets)

---

### Step 4: Access Skill Resources

**Get specific resource:**
```
"Get the metadata schema from skill-management-aila"
```

**Agent will:**
- Use aila_get_skill_resource() tool
- Return resource content

**Examples:**
- `"Get scripts/helper.py from skill-name"`
- `"Show me references/guide.md from skill-name"`

---

## Core Workflow: Creating a New Skill

### Step 1: Understand Requirements

**Ask user:**
- What is the skill's purpose?
- What category? (automation, sdlc-process, platform, etc.)
- What level? (000-999, where 000 is most fundamental)
- What resources needed? (scripts, references, templates)
- **Where to save?**
  - Current project (project-specific skill)
  - Shared library (skill-library-aila)

---

### Step 2: Write Skill Body

**Write skill instructions ONLY (no frontmatter):**

See [structure-guide.md](references/structure-guide.md) for structure.

**Write:**
```markdown
# Skill Name

Brief overview.

## Quick Start

Minimal example.

## Core Workflow

### Step 1: First Action
### Step 2: Next Action

## Advanced Features

Optional usage.
```

**Important:**
- Write body ONLY (no YAML frontmatter)
- Catalog tools will generate metadata automatically
- Tools analyze content and create comprehensive metadata
- Focus on WHAT the skill does, not HOW

---

### Step 3: Create Skill

**CRITICAL: AWS SSO Authentication Required**

Before calling any write operations (aila_create_skill, aila_save_skill, aila_save_skill_resource), agent MUST:

1. **Check for AWS SSO authentication errors**
2. **If SSO token expired:**
   - STOP execution immediately
   - DO NOT attempt workarounds
   - DO NOT create files manually
   - Inform user: "AWS SSO authentication required. Please run: `aws sso login --profile default`"
   - Wait for user confirmation before retrying

**Based on user's answer:**

**If "current project" (project-specific):**
```
aila_create_skill(
    skill_name="skill-name",
    skill_content=body
    # No provider_name - auto-detects from current directory
)
```

**If "shared library":**
```
aila_create_skill(
    skill_name="skill-name",
    skill_content=body,
    provider_name="skill-library-aila"
)
```

**Tool will:**
- Analyze skill content
- Generate comprehensive metadata automatically
- Create YAML frontmatter with proper categorization
- Add frontmatter to body
- Save to specified location (or auto-detect if not specified)

**Result:**
- Skill created with auto-generated metadata
- Comprehensive description listing ALL functionality
- Proper category, level, and tags
- Saved to correct location

**Note:** Metadata is ALWAYS auto-generated. User controls WHERE to save via their answer.

---

### Step 4: Add Resources (if needed)

**Add scripts, references, or templates:**
```
"Add script helper.py to skill [skill-name]"
"Add reference guide.md to skill [skill-name]"
```

**Agent will:**
- Call aila_save_skill_resource() for each resource
- Provider creates resource at location (scripts/, references/, assets/)
- Provider updates SKILL_META.yaml automatically

**Bulk operations:**
```
"Add multiple resources to skill [skill-name]"
```

Agent uses bulk operations for efficiency.

---

### Step 5: Validate

**Validate skill:**
```
"Validate skill [skill-name]"
```

**Agent will:**
- Call aila_validate_skill() tool
- Check Anthropic standard
- Check Artisyn requirements
- Return errors/warnings

See [validation-rules.md](references/validation-rules.md) for complete checklist.

---

### Step 6: Test

**Load and test:**
```
"Show me skill [skill-name]"
```

**Verify:**
- Instructions are clear
- Metadata is correct
- Resources are accessible
- Links work

---

## Core Workflow: Migrating Existing Skill

**See [migration-guide.md](references/migration-guide.md) for detailed migration instructions.**

### Step 1: Pre-Migration Analysis

**Check for duplicates and symlinks:**
```bash
# Find all copies
find . -name "*skill-name*"

# Check symlinks
find . -type l -ls | grep skill-name
```

**Questions:**
- Where are all copies located?
- Which is source of truth?
- Are there symlinks?
- Are versions identical?

**See migration-guide.md for detailed checklist.**

---

### Step 2: Map to Artisyn Format

**Extract information:**
- Name (from resource name or title)
- Description (from overview)
- Category (from current structure)
- Level (from current numbering)
- Tags (from content)

**Use mapping rules from [migration-guide.md](references/migration-guide.md):**
- Old category format → new category + level
- Old sections → new sections
- Old resource structure → new structure

---

### Step 3: Generate Artisyn Metadata

**Create YAML frontmatter:**
```yaml
---
name: skill-name
description: [Extract from current skill]
license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata:
  category: [Map from current category]
  level: "[Map from current number]"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-02-14"
  tags: [Extract from content]
---
```

---

### Step 4: Restructure Content

**Map sections:**
- Current "Overview" → Quick Start
- Current "Instructions" → Core Workflow
- Current "Parameters" → Environment Variables or Quick Start
- Current "Examples" → Quick Start or Advanced Features

**Keep content, change structure.**

---

### Step 5: Move Supporting Files

**Organize resources:**
- Scripts → `scripts/`
- Documentation → `references/`
- Templates → `assets/`

**Update links to use markdown format:**
```markdown
**Example:** `[metadata schema](references/metadata-schema.md)`
```

---

### Step 6: Validate Migrated Skill

**Use validation tools:**
```
"Validate skill [skill-name]"
```

**Agent will:**
- Use aila_validate_skill() tool
- Check Anthropic standard compliance
- Check Artisyn-specific requirements

**Test with agent:**
- Load migrated skill
- Test main workflows
- Verify all links work

---

## Advanced Features

### Catalog Tools Available

**Discovery:**
- `aila_list_skills()` - List all skills
- `aila_search_skills(query, category, tags)` - Search skills

**Access:**
- `aila_get_skill(skill_name, provider_name)` - Get skill (instructions + metadata)
- `aila_get_skill_resource(skill_name, resource_path, provider_name)` - Get resource

**Write:**
- `aila_create_skill(skill_name, skill_content, provider_name)` - Create new skill
- `aila_save_skill(skill_name, skill_content, provider_name)` - Update skill
- `aila_save_skill_resource(skill_name, resource_location, content, provider_name)` - Add/update resource
- `aila_delete_skill_resource(skill_name, resource_location, provider_name)` - Delete resource

**Validation:**
- `aila_validate_skill(skill_name, provider_name)` - Validate skill
- `aila_get_skill_schema()` - Get Artisyn schema

**Note:** Agent uses these automatically via natural language.

---

### Skill Structure (Logical)

**What agent sees:**
```
skill-name
├── Instructions (from aila_get_skill)
├── Metadata (from aila_get_skill)
└── Resources (from aila_get_skill_resource)
    ├── scripts/helper.py
    ├── references/guide.md
    └── assets/template.txt
```

**What agent doesn't see:**
- Physical storage (filesystem, S3, DynamoDB)
- SKILL_META.yaml (internal sync)
- Provider implementation

**Storage is abstracted by catalog tools.**

---

### Progressive Disclosure

**3-tier loading:**
1. **Discovery** - Minimal metadata (aila_list_skills)
2. **Full Definition** - Instructions + metadata (aila_get_skill)
3. **Resources** - On-demand content (aila_get_skill_resource)

**Keep SKILL.md concise. Move details to references/.**

---

### Markdown Links

**Use standard markdown links for resources:**
```markdown
See [guide](references/guide.md) for details.
```

**Claude automatically reads linked resources using `cat` command.**

**Link types:**

**1. Resources within skill:**
```markdown
[guide](references/guide.md)
[script](scripts/helper.py)
```

**2. External resources:**
```markdown
See [Anthropic Docs](https://docs.anthropic.com) for standards.
```

**For other skills, use catalog tools:**
```
"Show me skill-discovery skill"
```

**Don't use:**
- Hardcoded paths
- Special syntax
- Absolute paths

---

## Skill Resources

**Artisyn-specific guides:**
- [metadata-schema.md](references/metadata-schema.md) - Complete Artisyn metadata schema
- [structure-guide.md](references/structure-guide.md) - SKILL.md structure guide
- [validation-rules.md](references/validation-rules.md) - Validation checklist
- [migration-guide.md](references/migration-guide.md) - Migration from old format
- [acceptance-criteria-guide.md](references/acceptance-criteria-guide.md) - Testing format
- [testing-guide.md](references/testing-guide.md) - Test scenarios format

**Anthropic standard references:**
- [specification.md](artifacts/anthropic-skills-spec/specification.md) - Official Anthropic format spec
- [what-are-skills.md](artifacts/anthropic-skills-spec/what-are-skills.md) - Conceptual overview
- [integrate-skills.md](artifacts/anthropic-skills-spec/integrate-skills.md) - Integration patterns
- [skills-ref-sdk.md](artifacts/anthropic-skills-spec/skills-ref-sdk.md) - Reference SDK docs

**When to use which:**
- Creating skills → Use Artisyn guides (metadata-schema, structure-guide)
- Understanding format → Use Anthropic spec (specification.md)
- Validating → Use validation-rules.md + Anthropic spec
- Integrating → Use integrate-skills.md

---

## Best Practices

### Concise is Key

**Default assumption: Claude is already smart.**

Only add context Claude doesn't have:
- Domain-specific knowledge
- Company-specific processes
- Specialized workflows
- Tool integrations

**Challenge each paragraph:** "Does this justify its token cost?"

---

### Set Appropriate Degrees of Freedom

**High freedom (text instructions):**
- Multiple approaches valid
- Context-dependent decisions
- Heuristic guidance

**Medium freedom (pseudocode/scripts with parameters):**
- Preferred pattern exists
- Some variation acceptable
- Configuration affects behavior

**Low freedom (specific scripts):**
- Operations fragile/error-prone
- Consistency critical
- Specific sequence required

---

### Organize by Complexity

**SKILL.md:** Essential workflows and quick start  
**references/:** Detailed documentation and examples  
**scripts/:** Deterministic operations  
**assets/:** Templates and resources

---

### Use Markdown Links

**Link to references instead of duplicating:**
```markdown
For detailed documentation, see references via aila_get_skill_resource().
```

**Benefits:**
- Keeps SKILL.md lean
- Loaded only when needed
- Easy to update

---

### Include Trigger Phrases

**In description field:**
```yaml
description: Create PIR documents. Triggers: "create PIR", "post-implementation review", "document work".
```

**Helps Claude know when to use the skill.**

---

## Troubleshooting

### Issue: AWS SSO Token Expired

**Problem:** Write operations fail with "Token has expired and refresh failed"

**Symptoms:**
- aila_create_skill() fails
- aila_save_skill() fails
- aila_save_skill_resource() fails
- Error message mentions SSO token

**Solution:**
1. **STOP immediately** - Do not attempt workarounds
2. **DO NOT create files manually** - This bypasses catalog tools and breaks the system
3. **Inform user:** "AWS SSO authentication required. Please run: `aws sso login --profile default`"
4. **Wait for user confirmation** before retrying operation
5. **Retry original operation** after user confirms login

**What NOT to do:**
- ❌ Create skill files manually with fs_write
- ❌ Try alternative authentication methods
- ❌ Continue with partial operations
- ❌ Suggest workarounds

**Why this matters:**
- Catalog tools handle metadata generation automatically
- Manual file creation bypasses validation
- Breaks skill discovery and indexing
- Creates inconsistent state

---

### Issue: Validation fails with "invalid license"

**Problem:** License text doesn't match exactly  
**Solution:** Copy exact text from metadata-schema.md:
```yaml
license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
```

---

### Issue: Validation fails with "level must be string"

**Problem:** Level is number instead of string  
**Solution:** Quote the level:
```yaml
level: "000"  # Correct (string)
level: 000    # Wrong (number)
```

---

### Issue: skills-ref not found

**Problem:** skills-ref not installed  
**Solution:** Install skills-ref package

---

### Issue: Broken markdown links

**Problem:** Referenced resource doesn't exist  
**Solution:** Create the referenced resource or remove the link

---

### Issue: Name mismatch

**Problem:** Skill name doesn't match metadata.name  
**Solution:** Update metadata.name to match skill name

---

## Acceptance Criteria

See [acceptance-criteria-guide.md](references/acceptance-criteria-guide.md) for complete testing criteria.

**Key criteria:**
- ✅ Catalog tools return expected results
- ✅ Validation catches invalid skills
- ✅ Confirm save operations with user
- ✅ Stop execution on AWS SSO errors
- ❌ Should not expose internal storage structure
- ❌ Should not create files manually on SSO errors

---

## Validation Rules

See [validation-rules.md](references/validation-rules.md) for complete validation checklist.