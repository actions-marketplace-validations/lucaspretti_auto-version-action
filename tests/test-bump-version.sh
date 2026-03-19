#!/usr/bin/env bash
set -euo pipefail

# test-bump-version.sh
# Tests for helper functions and production logic in scripts/bump-version.sh.
# Extracts functions without running the main script (which needs git).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helper.sh"

# Source only the helper functions from bump-version.sh.
# We extract them to avoid triggering the main script logic.
eval "$(sed -n '/^# --- Helpers ---$/,/^# ===== PRODUCTION =====$/{ /^# ===== PRODUCTION =====$/d; p; }' "$SCRIPT_DIR/../scripts/bump-version.sh")"

echo "=== bump-version.sh helpers ==="

# --- get_bump_priority ---

test_start "get_bump_priority: major"
assert_eq "3" "$(get_bump_priority "major")"

test_start "get_bump_priority: minor"
assert_eq "2" "$(get_bump_priority "minor")"

test_start "get_bump_priority: patch"
assert_eq "1" "$(get_bump_priority "patch")"

test_start "get_bump_priority: unknown"
assert_eq "0" "$(get_bump_priority "whatever")"

# --- version_gte ---

test_start "version_gte: equal versions"
if version_gte "1.2.3" "1.2.3"; then
  assert_true "1.2.3 >= 1.2.3"
else
  assert_unexpected "1.2.3 should be >= 1.2.3"
fi

test_start "version_gte: patch higher"
if version_gte "1.2.4" "1.2.3"; then
  assert_true "1.2.4 >= 1.2.3"
else
  assert_unexpected "1.2.4 should be >= 1.2.3"
fi

test_start "version_gte: patch lower"
if version_gte "1.2.3" "1.2.4"; then
  assert_unexpected "1.2.3 should not be >= 1.2.4"
else
  assert_false "1.2.3 < 1.2.4"
fi

test_start "version_gte: minor higher"
if version_gte "1.3.0" "1.2.9"; then
  assert_true "1.3.0 >= 1.2.9"
else
  assert_unexpected "1.3.0 should be >= 1.2.9"
fi

test_start "version_gte: minor lower"
if version_gte "1.1.0" "1.2.0"; then
  assert_unexpected "1.1.0 should not be >= 1.2.0"
else
  assert_false "1.1.0 < 1.2.0"
fi

test_start "version_gte: major higher"
if version_gte "2.0.0" "1.9.9"; then
  assert_true "2.0.0 >= 1.9.9"
else
  assert_unexpected "2.0.0 should be >= 1.9.9"
fi

test_start "version_gte: major lower"
if version_gte "0.9.9" "1.0.0"; then
  assert_unexpected "0.9.9 should not be >= 1.0.0"
else
  assert_false "0.9.9 < 1.0.0"
fi

test_start "version_gte: bug scenario (0.1.0 vs 0.0.1)"
if version_gte "0.1.0" "0.0.1"; then
  assert_true "0.1.0 >= 0.0.1 (the downgrade bug scenario)"
else
  assert_unexpected "0.1.0 should be >= 0.0.1"
fi

test_start "version_gte: single-branch scenario (0.0.0 vs 0.0.1)"
if version_gte "0.0.0" "0.0.1"; then
  assert_unexpected "0.0.0 should not be >= 0.0.1"
else
  assert_false "0.0.0 < 0.0.1 (needs bump)"
fi

test_start "version_gte: zeros"
if version_gte "0.0.0" "0.0.0"; then
  assert_true "0.0.0 >= 0.0.0"
else
  assert_unexpected "0.0.0 should be >= 0.0.0"
fi

# --- production_bump_allowed ---

test_start "production_bump_allowed: single-branch mode (no staging), always allowed"
if production_bump_allowed "false" "0"; then
  assert_true "single-branch mode allows bump even with 0 RCs"
else
  assert_unexpected "single-branch mode should always allow bump"
fi

test_start "production_bump_allowed: two-branch mode, RC tags exist"
if production_bump_allowed "true" "2"; then
  assert_true "two-branch mode allows bump when RCs exist"
else
  assert_unexpected "two-branch mode with RCs should allow bump"
fi

test_start "production_bump_allowed: two-branch mode, no RC tags"
if production_bump_allowed "true" "0"; then
  assert_unexpected "two-branch mode without RCs should NOT allow bump"
else
  assert_false "two-branch mode blocks bump when no RCs exist"
fi

test_start "production_bump_allowed: two-branch mode, single RC"
if production_bump_allowed "true" "1"; then
  assert_true "two-branch mode allows bump with 1 RC"
else
  assert_unexpected "two-branch mode with 1 RC should allow bump"
fi

# --- Summary ---
test_summary "bump-version helpers"
