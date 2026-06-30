# Testing Guide

**Purpose:** How to write test scenarios for Artisyn skills

**Pattern:** YAML-based test scenarios (Microsoft pattern)

---

## Format

Test scenarios are YAML files in `tests/scenarios/{skill-name}/scenarios.yaml`:

```yaml
scenarios:
  - name: Scenario name
    description: What this scenario tests
    steps:
      - action: What to do
        expected: What should happen
      - action: Next action
        expected: Expected result
    
  - name: Another scenario
    description: What this tests
    steps:
      - action: Action
        expected: Expected result
```

---

## Example: skill-creator-aila

```yaml
# tests/scenarios/skill-creator-aila/scenarios.yaml

scenarios:
  - name: Create minimal skill
    description: Test creating a minimal valid Artisyn skill
    steps:
      - action: Request "Create a minimal test skill called hello-world"
        expected: Skill created successfully
      - action: Check SKILL.md exists
        expected: Instructions exist with valid YAML frontmatter
      - action: Validate skill
        expected: Validation passes
      - action: Check Artisyn metadata
        expected: All required Artisyn fields present
  
  - name: Create skill with scripts
    description: Test creating skill with helper scripts
    steps:
      - action: Request "Create skill with helper script"
        expected: Skill created with scripts/ resources
      - action: Check scripts
        expected: Contains .py resource
      - action: Run script
        expected: Script executes without errors
  
  - name: Create skill with references
    description: Test creating skill with reference files
    steps:
      - action: Request "Create skill with reference documentation"
        expected: Skill created with references/ resources
      - action: Check references
        expected: Contains .md resources
      - action: Check SKILL.md links
        expected: Links to reference resources work
  
  - name: Validate invalid skill
    description: Test validation catches errors
    steps:
      - action: Create skill with missing license
        expected: Validation fails with clear error
      - action: Create skill with invalid level
        expected: Validation fails with clear error
      - action: Create skill with missing category
        expected: Validation fails with clear error
```

---

## Example: post-implementation-review

```yaml
# tests/scenarios/post-implementation-review/scenarios.yaml

scenarios:
  - name: Create PIR from session log
    description: Test PIR creation from single session log
    steps:
      - action: Provide session log file
        expected: Session log parsed successfully
      - action: Request "Create PIR"
        expected: PIR document generated
      - action: Check PIR location
        expected: Saved to docs/pirs/YYYY-MM-DD-*.md
      - action: Check PIR content
        expected: Contains all required sections
  
  - name: Create PIR from multiple sources
    description: Test PIR creation from multiple files
    steps:
      - action: Provide session log + git log
        expected: Both sources parsed
      - action: Request "Create PIR"
        expected: PIR combines information from both
      - action: Check PIR content
        expected: References both source files
  
  - name: Identify automation opportunities
    description: Test automation opportunity detection
    steps:
      - action: Provide session with repeated manual steps
        expected: Manual steps identified
      - action: Request "Create PIR"
        expected: PIR includes automation opportunities section
      - action: Check recommendations
        expected: Specific skill/template suggestions included
```

---

## Guidelines

### Scenario Structure

**Name:** Short, descriptive  
**Description:** What is being tested  
**Steps:** Sequential actions and expected results

### Action Format

**Good:** "Request 'Create skill called hello-world'"  
**Bad:** "Create skill"

**Good:** "Validate skill hello-world"  
**Bad:** "Validate"

### Expected Format

**Good:** "Validation passes with no errors"  
**Bad:** "Works"

**Good:** "Skill exists with valid instructions"  
**Bad:** "File created"

---

## Test Categories

### Happy Path
Test normal, expected usage:
```yaml
- name: Create basic skill
  description: Test standard skill creation workflow
```

### Edge Cases
Test boundary conditions:
```yaml
- name: Create skill with maximum name length
  description: Test 64-character skill name
```

### Error Handling
Test failure scenarios:
```yaml
- name: Handle invalid metadata
  description: Test validation catches missing fields
```

### Integration
Test interaction with other components:
```yaml
- name: Create skill and validate
  description: Test full creation and validation workflow
```

---

## Running Tests

**Manual testing:**
1. Load skill in Claude
2. Follow scenario steps
3. Verify expected results

**Automated testing:** Future enhancement

---

## Checklist

When writing test scenarios:

- [ ] Scenario has clear name
- [ ] Scenario has description
- [ ] Steps are sequential
- [ ] Each step has action
- [ ] Each step has expected result
- [ ] Scenarios cover happy path
- [ ] Scenarios cover edge cases
- [ ] Scenarios cover error handling

---

## Template

```yaml
scenarios:
  - name: [Scenario name]
    description: [What this tests]
    steps:
      - action: [What to do]
        expected: [What should happen]
      - action: [Next action]
        expected: [Expected result]
```

---

**Status:** Testing Reference  
**Use:** When adding test scenarios to skills
