# CLAUDE.md - Crucible-CI

## Project Overview

Crucible-CI is a CI testing harness for the [Crucible](https://github.com/perftool-incubator/crucible) performance automation and analysis framework. It provides GitHub Actions and reusable workflows for integration testing of Crucible subprojects.

## Repository Structure

- `actions/` and `.github/actions/` — GitHub Actions (shell-script based)
  - `build-controller/` — builds Crucible controller images
  - `check-controller-build/` — detects if controller rebuild is needed
  - `clean-environment/` — cleans up runner environment (for self-hosted runners)
  - `get-job-parameters/` — generates job parameter lists
  - `get-releases/` — determines which releases to test
  - `get-repo-name/` — extracts repo name from github context
  - `get-scenarios/` — determines test scenarios (endpoint + benchmark)
  - `get-userenvs/` — lists supported userenvs from rickshaw
  - `install-crucible/` — reusable Crucible installation
  - `integration-tests/` — primary integration test execution
- `workflows/` and `.github/workflows/` — GitHub workflow definitions
  - Reusable: `benchmark-crucible-ci.yaml`, `core-crucible-ci.yaml`
  - Runnable: `faux-*`, `test-*`, `run-*`
- `runners/` — self-hosted runner configuration

## Conventions

- Actions are implemented as shell scripts (bash), invoked via `action.yml`
- Commit messages use conventional format: `feat:`, `fix:`, etc.
- The main branch should always be ready for user delivery
- Workshop files: both `workshop.pl` (Perl) and `workshop.py` (Python) are valid

## Development Notes

- When modifying actions, check both the script files and `action.yml` for consistency
- The `github/` and `.github/` directories mirror each other (symlinked structure)
- Self-hosted runners require `clean-environment` action; GitHub-hosted runners are ephemeral
- `faux-*` workflows provide null jobs for branch protection when changes don't affect runtime
