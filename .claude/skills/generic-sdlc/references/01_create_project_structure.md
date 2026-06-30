# SOP_STEP: Create Project Structure

step_name: create_project_structure

## Overview

Set up a directory structure to organize all artifacts created during the process, if it does nbt yet exist.

## Constraints

- You MUST create the specified project structure if it doesn't already exist
- You MUST create the following files:
  - {project_name}/rough-idea.md (containing the provided rough idea)
  - {project_name}/clarification.md (for questions and user answers during requirements clarification)
- You MUST create the following directories:
  - {project_name}/requirements/context/ (for project context files that remain available throughout the entire process in project memory)
  - {project_name}/requirements/artifacts/ (input directory for any project artifacts and files that could be explored and retrieved on demand, not loaded in memory, at different stages - sample data files, specification, documentation)
  - {project_name}/research/ (output directory for research output)
  - {project_name}/design/ (output directory for design documents)
  - {project_name}/implementation/ (output directory for implementation plans)
- You MUST read preconfigured project context files from the system context location
- You MUST copy all preconfigured context files to {project_name}/requirements/context/
- You MUST inform the user which context files were initialized in {project_name}/requirements/context/
- You MUST notify the user when the structure has been created
- You MUST explain that users can add, modify, or remove context files in {project_name}/requirements/context/ to customize project context
- You MUST explain that all context files in {project_name}/requirements/context/ remain in project memory throughout the entire process
- You MUST prompt the user to add project artifacts such as data samples, specifications to {project_name}/requirements/artifacts/
- You MUST explain that artifacts in {project_name}/requirements/artifacts/ are accessible on demand throughout the process