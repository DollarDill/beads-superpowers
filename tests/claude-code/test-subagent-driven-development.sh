#!/usr/bin/env bash
# Test: subagent-driven-development skill
# Verifies that the skill is loaded and follows correct workflow
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: subagent-driven-development skill ==="
echo ""

# Test 1: Verify skill can be loaded
echo "Test 1: Skill loading..."

output=$(run_claude "What is the subagent-driven-development skill? Describe its key steps briefly." 30)

if assert_contains "$output" "subagent-driven-development\|Subagent-Driven Development\|Subagent Driven" "Skill is recognized"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Load Plan\|read.*plan\|extract.*tasks" "Mentions loading plan"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 2: Verify skill describes the single-reviewer model
echo "Test 2: Single task-reviewer model..."

output=$(run_claude "In the subagent-driven-development skill, does ONE task reviewer return both a spec-compliance verdict and a code-quality verdict in a single pass, or are there two separate sequential reviewers? Answer briefly." 30)

# Check that Claude identifies a single reviewer returning both verdicts
# Use multiple greps since assert_contains uses basic grep (no -E for alternation)
if echo "$output" | grep -iq "one\|single\|both\|same reviewer\|task reviewer"; then
    echo "  [PASS] Single task reviewer returns both verdicts"
else
    echo "  [FAIL] Single task reviewer returns both verdicts"
    echo "  Expected Claude to indicate one reviewer returns spec + quality verdicts"
    echo "  Output: $output"
    exit 1
fi

echo ""

# Test 3: Verify self-review is mentioned
echo "Test 3: Self-review requirement..."

output=$(run_claude "Does the subagent-driven-development skill require implementers to do self-review? What should they check?" 30)

if assert_contains "$output" "self-review\|self review" "Mentions self-review"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "completeness\|Completeness" "Checks completeness"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 4: Verify plan is read once
echo "Test 4: Plan reading efficiency..."

output=$(run_claude "In subagent-driven-development, how many times should the controller read the plan file? When does this happen?" 30)

if assert_contains "$output" "once\|one time\|single" "Read plan once"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Step 1\|beginning\|start\|Load Plan" "Read at beginning"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 5: Verify the task reviewer is skeptical
echo "Test 5: Task reviewer mindset..."

output=$(run_claude "What is the task reviewer's attitude toward the implementer's report in subagent-driven-development?" 30)

# Accept the range of vocabulary the model uses for an adversarial stance
# ("skeptic" matches skeptical/skepticism; assert_contains is case-insensitive).
if assert_contains "$output" "skeptic\|distrust\|not trust\|don't trust\|unverified\|adversarial\|verify.*independently\|suspicious" "Reviewer is skeptical"; then
    : # pass
else
    exit 1
fi

# The reviewer inspects the actual changes; the skill's task-reviewer-prompt uses
# "diff"/"ground truth" as the object, so accept that vocabulary as well as "code".
if assert_contains "$output" "read.*code\|inspect.*code\|verify.*code\|against.*diff\|the diff\|ground truth" "Reviewer inspects the code/diff"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 6: Verify review loops
echo "Test 6: Review loop requirements..."

output=$(run_claude "In subagent-driven-development, what happens if a reviewer finds issues? Is it a one-time review or a loop?" 30)

if assert_contains "$output" "loop\|again\|repeat\|until.*approved\|until.*compliant" "Review loops mentioned"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "implementer.*fix\|fix.*issues" "Implementer fixes issues"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 7: Verify the task is handed off as a brief file (File Handoffs model)
echo "Test 7: Task handoff via brief file..."

output=$(run_claude "In subagent-driven-development, how does the controller hand the task to the implementer subagent — by pasting the full task text into the prompt, or by writing a task brief file the implementer reads?" 30)

if assert_contains "$output" "brief\|task-brief\|file\|\.superpowers\|read this first" "Hands off task as a brief file"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 8: Verify worktree requirement
echo "Test 8: Worktree requirement..."

output=$(run_claude "What workflow skills are required before using subagent-driven-development? List any prerequisites or required skills." 30)

if assert_contains "$output" "using-git-worktrees\|worktree" "Mentions worktree requirement"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 9: Verify main branch warning
echo "Test 9: Main branch red flag..."

output=$(run_claude "In subagent-driven-development, is it okay to start implementation directly on the main branch?" 30)

if assert_contains "$output" "worktree\|feature.*branch\|not.*main\|never.*main\|avoid.*main\|don't.*main\|consent\|permission" "Warns against main branch"; then
    : # pass
else
    exit 1
fi

echo ""

echo "=== All subagent-driven-development skill tests passed ==="
