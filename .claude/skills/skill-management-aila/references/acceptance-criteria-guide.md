# Acceptance Criteria Guide

**Purpose:** Testing criteria for skill-management-aila MCP operations

---

## MCP Operations Criteria

### Skill Discovery
✅ Returns all available skills
✅ Search filters work correctly (category, tags, query)
✅ Skill metadata includes all required fields

### Skill Access
✅ get_skill() returns complete instructions and metadata
✅ get_skill_resource() returns resource content
✅ Resources accessible via logical locations (scripts/, references/, assets/)

### Skill Creation
✅ Creates valid skill with all required metadata
✅ Validates skill automatically

### Resource Management
✅ Resources created at correct locations
✅ Bulk operations work efficiently
✅ Confirm save operations with user
❌ Should not overwrite without confirmation

### Validation
✅ Validates Anthropic standard compliance
✅ Validates Artisyn-specific requirements
✅ Reports clear error messages

---

## Format Pattern

Use ✅/❌ for clear pass/fail:

```markdown
## Acceptance Criteria

### Feature Name
✅ Expected behavior when successful
❌ What should NOT happen
```

---

## Guidelines

**Be Specific:**
- ✅ Good: "Creates skill with metadata.level as 3-digit string"
- ❌ Bad: "Creates skill correctly"

**Be Testable:**
- ✅ Good: "Validates skill automatically"
- ❌ Bad: "Skill is good"

**Cover Edge Cases:**
- ✅ Good: "Should not overwrite without confirmation"
- ❌ Bad: "Should not break things"
- [ ] Criteria cover edge cases
- [ ] Criteria cover error handling

---

## Template

```markdown
## Acceptance Criteria

### [Feature/Function Name]
✅ [What should happen when successful]
✅ [Another success case]
❌ [What should NOT happen]
❌ [Another failure case to avoid]

### [Another Feature/Function]
✅ [Success case]
❌ [Failure case]
```

---

**Status:** Testing Reference  
**Use:** When adding acceptance criteria to skills
