---
name: aila-catalog-sdk
description: |
  Artisyn Catalog SDK usage guide for AI agents. Covers skill discovery, resource management, catalog operations, and publishing. Explains all aila_* API functions, RESOURCE_CONFIG types, and provider architecture.

  Use when discovering skills, creating or saving skills, managing catalog resources (knowledge, agents, prompts, workshops, PIRs), listing resource types, or publishing workspace artifacts.

  Triggers: "List skills", "Create skill", "Save resource", "Catalog operations", "Resource types", "SDK usage", "Discover providers", "List resources", "Get resource".

license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata:
  category: sdk-operations
  level: "101"
  author: dataart-aila
  version: "1.1.0"
  last_updated: "2026-03-22"
  tags: [sdk, catalog, skills, resources, discovery, publishing, aila, api]
---

# Artisyn Catalog SDK

SDK for AI agents to discover, create, and manage Artisyn catalog resources (skills, knowledge, agents, prompts, workshops, PIRs, and more).

## Quick Start

```python
from skill_sdk_aila import (
    aila_list_skills, aila_get_skill, aila_create_skill, aila_save_skill,
    aila_list_resources, aila_get_resource, aila_list_resource_types,
)

# Discover skills
skills = aila_list_skills()
skill = aila_get_skill("workspace-management")

# Discover resources
types = aila_list_resource_types()
agents = aila_list_resources("agent-configs")
content = aila_get_resource("agent-configs", "my-agent-name")

# Create / Update skills
aila_create_skill("my-skill", skill_content, provider_name="skill-library-aila")
aila_save_skill("my-skill", updated_content, provider_name="skill-library-aila")
```

## API Reference

### Skill Discovery

```python
aila_list_skills() -> {"skills": [...], "count": int}
```
Returns all skills from all providers.

```python
aila_search_skills(query=None, category=None, tags=None, providers=None) -> {"skills": [...]}
```
Search by name/description substring, category, or tags.

```python
aila_get_skill(skill_name, provider_name=None) -> {"instructions": str, "metadata": dict}
```
Get full skill content. Returns instructions (SKILL.md body) and metadata.

```python
aila_get_skill_resource(skill_name, resource_path, provider_name=None) -> str
```
Read a resource file from within a skill (e.g., scripts/run.py). Returns content as string.

### Resource Discovery and Access

```python
aila_list_resource_types() -> [{"type": str, "skill": str, "content_file": str}, ...]
```
List all 15 supported resource types with their managing skill and content file convention.

```python
aila_list_resources(resource_type, provider_name=None) -> {"resources": [...], "count": int}
```
List all resources of a given type across all providers (or a specific one). Each item includes enriched fields for direct access:
- `_provider`: provider identifier
- `_resource_name`: resource name/path
- `_skill_name`: skill that owns this resource
- `_resource_path`: full path for read_resource() call
- `_content_file`: content filename (e.g., "AGENT.json")
- `_catalog_get_params`: dict with all params needed for aila_get_resource()

```python
aila_get_resource(resource_type, resource_name, provider_name=None) -> str
```
Get resource content by type and name. Resolves skill_name and resource_path automatically from RESOURCE_CONFIG. Returns content as string, empty string if not found.

### Skill Creation and Update

```python
aila_create_skill(skill_name, skill_content, provider_name=None) -> {"success": bool}
```
Create new skill. skill_content must include YAML frontmatter. Fails if skill exists.

```python
aila_save_skill(skill_name, skill_content, provider_name=None) -> {"success": bool}
```
Update existing skill. Regenerates SKILL_META.yaml automatically.

```python
aila_save_skill_resource(skill_name, resource_location, content, provider_name=None) -> {"success": bool}
```
Create or update a resource file within a skill.

```python
aila_delete_skill_resource(skill_name, resource_location, provider_name=None) -> {"success": bool}
```
Delete a resource file from a skill.

### System

```python
aila_describe_providers() -> {"providers": [...]}
```
List all discovered providers with their types and capabilities.

```python
aila_self_diagnostics() -> {"environment": {...}, "providers": {...}, "capabilities": [...]}
```
Full system diagnostics.

## SKILL.md Frontmatter Format

Every skill MUST start with YAML frontmatter:

```yaml
---
name: my-skill-name
description: |
  What the skill does. When to use it.
  Triggers: "keyword1", "keyword2".
license: Proprietary - DataArt Core IP.
metadata:
  category: my-category
  level: "101"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-03-19"
  tags: [tag1, tag2]
---
```

## Resource Types (RESOURCE_CONFIG)

Each type maps to a managing skill and content file convention:

| Content File | Resource Type | Managing Skill |
|---|---|---|
| AGENT.json | agent-configs | declarative-agent-management |
| AGENT_TEAM.json | agent-teams | agent-team-management |
| KNOW.md | knowledge | aila-knowledge |
| KNOWLEDGE.md | extract | aila-knowledge-extraction |
| PROMPT.md | prompts | prompt-management |
| BEST_PRACTICE.md | best-practices | best-practices |
| PIR.md | pirs | post-implementation-review |
| WORKSHOP.md | workshops | workshop-assistant |
| MODEL.txt | models | model-management |
| APPLICATION.py | dynamic-applications | dynamic-applications-management |
| DATA_SOURCE.md | data-sources | data-source-management |
| DATA_CATALOG.md | data-catalogs | data-catalog-management |
| DATA_QUERY.md | data-queries | data-query-management |
| DATA.csv | data | data-management |
| WORKSPACE.json | workspaces | workspace-management |

### Saving Resources by Type

```python
from skill_sdk_aila import aila_save_skill_resource

# Save knowledge article
aila_save_skill_resource("aila-knowledge", "artifacts/my-topic/python/KNOW.md", content)

# Save agent config
aila_save_skill_resource("declarative-agent-management", "artifacts/my-agent/AGENT.json", json_content)

# Save prompt
aila_save_skill_resource("prompt-management", "artifacts/my-prompt/PROMPT.md", prompt_content)
```

## Provider Architecture

```
MultiProviderDiscovery
  -- file providers (local filesystem, Git-based)
  -- aws-cloud-provider (S3 + DynamoDB)
  -- api-gateway (HTTP client for distributed catalog)
  -- skill-library-aila (shared skill library)
  -- project providers (workspace-local skills)
```

Providers are auto-discovered from:
1. ~/.aila/settings.json (desktop config)
2. Environment variables (cloud/docker)
3. Installed packages with aila_skills entry point

All providers implement a consistent interface (SkillsProvider base class):
- `discover()` → List[SkillMetadata]
- `get_skill(skill_name)` → dict with instructions + metadata
- `read_resource(skill_name, resource_path)` → str
- `list_resources(skill_name=None, resource_type="")` → list of enriched dicts
- `create_skill()`, `save_skill()`, `save_resource()`, `delete_resource()`

### Provider Names

- skill-library-aila: shared skill library (file provider)
- aws-cloud-provider: AWS S3/DynamoDB (cloud provider)
- api-gateway: HTTP client for remote catalog API
- Project-specific providers: from workspace skills/ directory

## Common Workflows

### Create a New Skill

```python
from skill_sdk_aila import aila_create_skill

content = '''---
name: my-new-skill
description: |
  What it does. When to use.
license: Proprietary - DataArt Core IP.
metadata:
  category: my-category
  version: "1.0.0"
  tags: [tag1]
---

# My New Skill

Instructions here.
'''

aila_create_skill("my-new-skill", content, provider_name="skill-library-aila")
```

### Discover and Use a Skill

```python
from skill_sdk_aila import aila_get_skill, aila_get_skill_resource

# Get instructions
skill = aila_get_skill("generic-sdlc")
print(skill["instructions"])

# Get a script from the skill
script = aila_get_skill_resource("generic-sdlc", "scripts/run.py")
```

### List and Read Resources by Type

```python
from skill_sdk_aila import aila_list_resources, aila_get_resource

# List all agent configs across all providers
result = aila_list_resources("agent-configs")
for item in result["resources"]:
    print(f'{item["_resource_name"]} ({item["_provider"]})')

# Get specific agent config content
content = aila_get_resource("agent-configs", "my-agent-name")

# List all knowledge articles
knowledge = aila_list_resources("knowledge")

# Get specific knowledge content
content = aila_get_resource("knowledge", "skill-sdk-aila/python")

# List all prompts from a specific provider
prompts = aila_list_resources("prompts", provider_name="aws-cloud-provider")
```

### Using Enriched list_resources Output

Each item from `aila_list_resources` includes everything needed for direct access:

```python
result = aila_list_resources("agent-configs")
for item in result["resources"]:
    # Use _catalog_get_params for aila_get_resource
    params = item["_catalog_get_params"]
    content = aila_get_resource(params["resource_type"], params["resource_name"], params["provider_name"])
```
