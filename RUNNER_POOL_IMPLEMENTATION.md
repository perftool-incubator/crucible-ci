# Runner Pool Implementation Guide

## Overview

This implementation allows you to switch between different pools of self-hosted GitHub Actions runners (e.g., KMR cloud vs AWS cloud) by simply changing a workflow input parameter, without modifying rickshaw or any other core components.

## Architecture

The runner pool selection flows through three layers:

1. **Workflow Input** → Specify which pool to use (e.g., "kmr-cloud-1" or "aws-cloud-1")
2. **generate-ci-jobs.py** → Builds runner label list dynamically
3. **runs-on Directive** → Uses dynamic labels from job matrix

## Files Modified

### In rickshaw (PR #757)
- `util/generate-ci-jobs.py` - Added `--runner-pool` parameter and `runner_labels` field to jobs

### In crucible-ci
- `.github/actions/get-job-parameters/action.yml` - Added `runner-pool` input
- `.github/workflows/core-crucible-ci.yaml` - Added `runner_pool` input and dynamic `runs-on`
- `.github/workflows/benchmark-crucible-ci.yaml` - Added `runner_pool` input and dynamic `runs-on`

## How to Use

### Default Behavior (KMR Cloud Runners)

No changes needed! The default is set to "kmr-cloud-1":

```yaml
# workflows automatically use:
runner_pool: "kmr-cloud-1"  # This is the default
```

Jobs will run on runners labeled: `["self-hosted", "kmr-cloud-1", "cpu-partitioning", "remotehosts"]`

### Switching to AWS Cloud Runners

When calling a workflow, override the `runner_pool` input:

```yaml
# In your calling workflow:
jobs:
  test:
    uses: ./.github/workflows/core-crucible-ci.yaml
    with:
      runner_pool: "aws-cloud-1"
      # ... other inputs
```

Jobs will run on runners labeled: `["self-hosted", "aws-cloud-1", "cpu-partitioning", "remotehosts"]`

### Switching Back to Default (No Pool Label)

To use runners without a pool-specific label:

```yaml
jobs:
  test:
    uses: ./.github/workflows/core-crucible-ci.yaml
    with:
      runner_pool: ""  # Empty string = no pool label
      # ... other inputs
```

Jobs will run on runners labeled: `["self-hosted", "cpu-partitioning", "remotehosts"]`

## Runner Configuration

### KMR Cloud Runners

Configure your runners with these labels:
```
self-hosted, kmr-cloud-1, cpu-partitioning, remotehosts, workflow-overhead
```

### AWS Cloud Runners

Configure your runners with these labels:
```
self-hosted, aws-cloud-1, cpu-partitioning, remotehosts, workflow-overhead
```

### Important Notes

1. **Both pools can run simultaneously** - The labels distinguish which jobs go to which pool
2. **All capability labels must be present** - Both pools need `cpu-partitioning`, `remotehosts`, etc.
3. **The pool label is inserted second** - Order: `["self-hosted", "<pool>", "<other-tags>"]`

## Testing Strategy

### Phase 1: Test Rickshaw Changes (In Progress)
- PR #757 tests backward compatibility
- Existing workflows run without changes
- Verify `runner_labels` field is generated correctly

### Phase 2: Test Crucible-CI Changes
1. Push this branch to your fork
2. Create a test workflow that calls core-crucible-ci with `runner_pool: "kmr-cloud-1"`
3. Verify jobs target the correct runners
4. Test switching to `runner_pool: "aws-cloud-1"`
5. Verify jobs switch to AWS runners

### Phase 3: Production Rollout
1. Merge rickshaw PR #757
2. Merge this crucible-ci PR
3. Configure AWS runners with `aws-cloud-1` label
4. Test in a non-critical workflow
5. Roll out to production workflows

## Troubleshooting

### Jobs Don't Run
**Problem:** Jobs are queued but never start

**Possible Causes:**
1. No runners have the pool label (e.g., no runner labeled `aws-cloud-1`)
2. Runners don't have all required labels (missing `cpu-partitioning` or `remotehosts`)

**Solution:** Check runner labels match exactly what's in `runner_labels` field

### Wrong Runners Execute Jobs
**Problem:** Jobs run on KMR runners when expecting AWS

**Possible Causes:**
1. `runner_pool` input not passed correctly
2. Default value is being used instead of specified value

**Solution:** Check workflow call includes `runner_pool: "aws-cloud-1"`

### Syntax Errors in runs-on
**Problem:** Workflow fails with syntax error on `runs-on` line

**Possible Causes:**
1. Rickshaw PR #757 not merged (no `runner_labels` field in jobs)
2. JSON parsing issue with `fromJSON(toJSON(...))`

**Solution:** Verify rickshaw has been updated with PR #757 changes

## Examples

### Example 1: Temporary AWS Testing

Test a PR on AWS runners:

```yaml
name: PR Test on AWS
on:
  pull_request:
    branches: [ main ]

jobs:
  test-on-aws:
    uses: ./.github/workflows/core-crucible-ci.yaml
    with:
      ci_target: "crucible"
      ci_target_branch: ${{ github.head_ref }}
      github_workspace: ${{ github.workspace }}
      runner_pool: "aws-cloud-1"  # Force AWS for this test
```

### Example 2: Matrix Testing Both Pools

Test on both pools to compare results:

```yaml
jobs:
  test-both-pools:
    strategy:
      matrix:
        pool: ["kmr-cloud-1", "aws-cloud-1"]
    uses: ./.github/workflows/core-crucible-ci.yaml
    with:
      runner_pool: ${{ matrix.pool }}
      # ... other inputs
```

### Example 3: Default Production Workflow

No changes needed - uses KMR by default:

```yaml
jobs:
  production-test:
    uses: ./.github/workflows/core-crucible-ci.yaml
    with:
      ci_target: "crucible"
      # runner_pool defaults to "kmr-cloud-1"
```

## Future Enhancements

Possible future improvements:

1. **Auto-selection based on load** - Automatically pick less busy pool
2. **Cost tracking** - Tag jobs with pool info for cost analysis
3. **Geographic selection** - `us-east-cloud-1` vs `us-west-cloud-1`
4. **Fallback pools** - Try AWS if KMR is full
5. **Runner pool health checks** - Warn if no runners available for a pool

## Related Documentation

- Rickshaw PR: https://github.com/perftool-incubator/rickshaw/pull/757
- Rickshaw changes: ../rickshaw/RUNNER_POOL_CHANGES.md
