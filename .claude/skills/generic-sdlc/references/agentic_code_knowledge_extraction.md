# Agentic Enhancement: Code Knowledge Extraction Subflow

## Overview

When code knowledge (KNOW.md files) is missing, insufficient, or doesn't cover the relevant area, this subflow guides the user through extracting structured code intelligence using `aila-meta`. This is critical because undocumented code is a source of super-valuable information that subagents cannot access without KNOW.md.

## When to Trigger

You MUST check code knowledge quality during research and trigger this subflow when:

1. **No KNOW.md files exist** → Full subflow
2. **KNOW.md has errors** (e.g., "tree-sitter not available") → Fix + re-run
3. **KNOW.md doesn't cover the needed area** → Add provider + re-run
4. **Code lacks documentation** (functions without docstrings/JSDoc) → Iterative enhancement

## Parameters

- **codebase_root** (required): Path to the source code repository
- **target_area** (required): The code area needed for the current task (e.g., "apps/api-employees/src/internal/documents")

## Steps

### 1. Check for aila-meta Tooling

```bash
which aila-meta || pip show skill-sdk-aila
```

**Constraints:**
- If not installed, You MUST inform the user: "Code knowledge extraction requires aila-meta (part of skill-sdk-aila). Install with: `pip install -e /path/to/skill-sdk-aila`"
- You MUST NOT proceed without the tooling because manual code reading is 10x slower than structured extraction

### 2. Check for Existing Configuration

```bash
cat {codebase_root}/.aila/documentation.json
```

**Constraints:**
- If config exists, proceed to Step 3
- If missing, run: `cd {codebase_root} && aila-meta --analyse`
- This auto-detects language providers and generates `.aila/documentation.json`

### 3. Assess Coverage Gaps

Compare `documentation.json` providers against the files you need.

**Constraints:**
- You MUST list all provider `roots` and `output` names
- You MUST check if `{target_area}` is covered by any provider
- If gap found, You MUST suggest adding a new provider entry:
  ```json
  {
    "type": "typescript",
    "enabled": true,
    "roots": ["{target_area}"],
    "output": "{descriptive-name}"
  }
  ```
- You MUST get user approval before modifying documentation.json

### 4. Run Extraction

```bash
cd {codebase_root} && aila-meta --document
```

**Constraints:**
- You MUST run from the codebase root directory
- You MUST verify output: check that KNOW.md files were generated
- You MUST report: "Generated {N} KNOW.md files covering {M} files"

### 5. Verify Quality

**Constraints:**
- You MUST check for "tree-sitter not available" errors in generated KNOW.md
- You MUST check line count (>100 lines = good coverage, <50 = sparse)
- You MUST verify the target area files appear in the KNOW.md
- You MUST check for actual function signatures (not just file listings)
- If quality is poor, You MUST suggest: install tree-sitter language grammar, or add documentation strings to code

### 6. Enhance Undocumented Code (Iterative)

When code lacks docstrings/JSDoc, KNOW.md will have signatures but no purpose descriptions.

**Constraints:**
- You SHOULD send a code expert subagent to read key files and explain what they do
- You SHOULD add documentation strings to key functions based on understanding:
  - Pattern: `@purpose`, `@structure`, `@semantics`, `@relationships`
- You SHOULD re-run `aila-meta --document` after adding docs to capture them in KNOW.md
- You SHOULD validate understanding by asking the subagent domain-specific questions
- Each iteration compounds — first is slow, subsequent are fast because context accumulates
- You MUST NOT skip this step for critical code areas because undocumented code hides the most valuable implementation knowledge

## Troubleshooting

### tree-sitter not available
Install the language grammar: `pip install tree-sitter-typescript` (or python, etc.)

### KNOW.md too sparse
The code may lack structured comments. Run iteration 6 to add documentation, then re-extract.

### Provider doesn't cover needed files
Add a new provider entry to `.aila/documentation.json` with the correct `roots` path.
