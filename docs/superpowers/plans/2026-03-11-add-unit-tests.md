# Add Unit Tests Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add comprehensive unit tests for all scripts in the auto-version-action pipeline.

**Architecture:** Each script gets a dedicated test file in `tests/`. Pure bash tests using the minimal `tests/test-helper.sh` assertion framework. Testable logic is extracted from scripts or replicated in test files. External dependencies (git, curl) are not called directly. `tests/run-all.sh` runs everything.

**Tech Stack:** Bash, no external test frameworks.

---

## File Structure

```
tests/
  test-helper.sh              # Assertion framework (exists)
  run-all.sh                   # Test runner (exists)
  test-version-utils.sh        # version-utils.sh tests (exists, 19 tests)
  test-bump-version.sh         # bump-version.sh helper tests (exists, 14 tests)
  test-analyze-commits.sh      # analyze-commits.sh tests (exists, 35 tests)
  test-create-release.sh       # create-release.sh changelog tests (NEW)
  test-cleanup-rc.sh           # cleanup-rc.sh version comparison tests (NEW)
```

---

## Chunk 1: Completed

- [x] `tests/test-helper.sh` - assertion framework
- [x] `tests/run-all.sh` - test runner
- [x] `tests/test-version-utils.sh` - detect_version_file_type, read_version, write_version (all formats)
- [x] `tests/test-bump-version.sh` - get_bump_priority, version_gte (including downgrade regression)
- [x] `tests/test-analyze-commits.sh` - classify_commits (subjects/bodies split, issue ref prefix, false positive regression)

## Chunk 2: create-release.sh changelog categorization

### Task 1: test-create-release.sh

**Files:**
- Create: `tests/test-create-release.sh`
- Reference: `scripts/create-release.sh:13-24` (categorize_commits grep patterns)

The `categorize_commits` function in create-release.sh uses git log, so we replicate the grep categorization logic in the test.
The `write_sections` function writes to a file based on category variables, fully testable.

- [ ] **Step 1: Write categorization tests**

Replicate the grep patterns from `categorize_commits` (lines 19-23) as a `categorize_line` function:

```bash
categorize_line() {
  local line="$1"
  if echo "$line" | grep -qE "^- feat(\(.*\))?!:|BREAKING CHANGE"; then echo "breaking"
  elif echo "$line" | grep -qE "^- feat(\(.*\))?:" && ! echo "$line" | grep -q "!"; then echo "feature"
  elif echo "$line" | grep -qE "^- fix(\(.*\))?:"; then echo "fix"
  elif echo "$line" | grep -qE "^- (chore|docs|style|refactor|perf|test)(\(.*\))?:"; then echo "maintenance"
  else echo "other"
  fi
}
```

Cases:
- `- feat: add feature` -> feature
- `- feat(api): add endpoint` -> feature
- `- feat!: breaking change` -> breaking
- `- feat(api)!: breaking` -> breaking
- `- fix: resolve bug` -> fix
- `- fix(ui): alignment` -> fix
- `- chore: update deps` -> maintenance
- `- docs: update readme` -> maintenance
- `- refactor: simplify` -> maintenance
- `- perf: optimize query` -> maintenance
- `- test: add tests` -> maintenance
- `- style: formatting` -> maintenance
- `- build: update docker` -> other
- `- ci: update workflow` -> other
- `- random commit message` -> other

- [ ] **Step 2: Write skip-ci exclusion test**

Verify that lines containing `[skip ci]` are excluded when filtering:

```bash
CHANGELOG="- feat: real feature
- chore: bump version [skip ci]
- fix: real fix"
FILTERED=$(echo "$CHANGELOG" | grep -v "\[skip ci\]")
```

Assert filtered has 2 lines, not 3.

- [ ] **Step 3: Write write_sections output tests**

Set BREAKING/FEATURES/FIXES/CHORES/OTHER variables and call write_sections, verify release_notes.md content has correct markdown headers.

- [ ] **Step 4: Run tests**

Run: `bash tests/run-all.sh`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add tests/test-create-release.sh
git commit -m "test: add changelog categorization tests for create-release.sh"
```

## Chunk 3: cleanup-rc.sh version comparison

### Task 2: test-cleanup-rc.sh

**Files:**
- Create: `tests/test-cleanup-rc.sh`
- Reference: `scripts/cleanup-rc.sh:38-47` (version comparison logic)

The core logic is the should_delete comparison: delete RCs with version <= current production version.

- [ ] **Step 1: Write version comparison tests**

Extract the comparison logic as a function:

```bash
should_delete_rc() {
  local RC_VER="$1"
  local CURR_VER="$2"
  IFS='.' read -r RC_MAJOR RC_MINOR RC_PATCH <<< "$RC_VER"
  IFS='.' read -r CURR_MAJOR CURR_MINOR CURR_PATCH <<< "$CURR_VER"
  if [ "$RC_MAJOR" -lt "$CURR_MAJOR" ]; then echo "true"; return; fi
  if [ "$RC_MAJOR" -eq "$CURR_MAJOR" ]; then
    if [ "$RC_MINOR" -lt "$CURR_MINOR" ]; then echo "true"; return; fi
    if [ "$RC_MINOR" -eq "$CURR_MINOR" ] && [ "$RC_PATCH" -le "$CURR_PATCH" ]; then echo "true"; return; fi
  fi
  echo "false"
}
```

Cases:
- RC 1.0.0 vs current 1.0.0 -> delete (equal)
- RC 1.0.0 vs current 1.0.1 -> delete (patch lower)
- RC 1.0.0 vs current 1.1.0 -> delete (minor lower)
- RC 1.0.0 vs current 2.0.0 -> delete (major lower)
- RC 1.1.0 vs current 1.0.0 -> keep (minor higher)
- RC 2.0.0 vs current 1.0.0 -> keep (major higher)
- RC 1.0.5 vs current 1.1.0 -> delete (escalation: patch RC, minor release)
- RC 1.1.0 vs current 1.0.5 -> keep (higher minor RC preserved)

- [ ] **Step 2: Write RC tag parsing test**

Extract RC tag -> base version parsing:

```bash
parse_rc_version() {
  echo "$1" | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+)-rc\.[0-9]+$/\1/'
}
```

Cases:
- `v1.0.0-rc.1` -> `1.0.0`
- `v2.3.1-rc.15` -> `2.3.1`
- `v0.1.0-rc.1` -> `0.1.0`

- [ ] **Step 3: Run tests**

Run: `bash tests/run-all.sh`
Expected: All pass

- [ ] **Step 4: Commit**

```bash
git add tests/test-cleanup-rc.sh
git commit -m "test: add RC cleanup version comparison tests"
```
