#!/usr/bin/env bash
# Guard-the-guards for tests/skills/test-skill-references.sh. Each mutation runs
# in a fixture-isolated copy (mktemp -d, ROOT-relative layout) and must turn the
# test RED with ITS OWN tag (FAIL C1..C8); any other tag is a rig error, so a
# mutation proves a check only if that check is what went red. Controls stay GREEN.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILLS=(subagent-driven-development executing-plans write-documentation)
fails=0
FIX=""
trap 'if [ -n "$FIX" ]; then rm -rf "$FIX"; fi' EXIT

WD=skills/write-documentation
REG=tests/skills/skill-references-moved

stage() {  # rebuild a pristine fixture
  if [ -n "$FIX" ]; then rm -rf "$FIX"; fi
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/skills/using-superpowers" "$FIX/tests/skills" || return 1
  local s
  for s in "${SKILLS[@]}"; do
    cp -rf "$ROOT/skills/$s" "$FIX/skills/$s" || return 1
  done
  cp -rf "$ROOT/skills/using-superpowers/references" "$FIX/skills/using-superpowers/references" || return 1
  cp -f "$ROOT/tests/skills/test-skill-references.sh" "$FIX/tests/skills/test-skill-references.sh" || return 1
  cp -rf "$ROOT/tests/skills/skill-references-moved" "$FIX/$REG" || return 1
}

# add_entry <name> <total-lines> <with-contents:yes|no>: a valid registry file in
# write-documentation, its pointer line in SKILL.md, and its registry entry.
add_entry() {
  local name="$1" total="$2" contents="$3" f="$FIX/$WD/references/$1.md" i
  {
    printf '# Good File\n\nRead this when you are exercising the structure test.\n'
    if [ "$contents" = yes ]; then printf '\nContents: filler only.\n'; fi
  } > "$f"
  i=$(grep -c '' "$f")
  while [ "$i" -lt "$total" ]; do
    printf 'filler %s\n' "$i" >> "$f"
    i=$((i + 1))
  done
  printf '%s\n' "" "**Read \`references/${name}.md\` (in this skill's directory) before testing the thing** — keep the rule that guards the thing well." >> "$FIX/$WD/SKILL.md"
  printf '%s.md\n' "$name" >> "$FIX/$REG/write-documentation.txt"
}

run_test() {
  OUT="$(bash "$FIX/tests/skills/test-skill-references.sh" 2>&1)"
  RC=$?
}

expect_green() {  # expect_green <label>
  run_test
  if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q '^PASS'; then
    echo "GREEN ok: $1"
  else
    echo "SELFTEST FAIL: control should be GREEN (rc=$RC): $1"
    printf '%s\n' "$OUT" | sed 's/^/     | /'
    fails=$((fails + 1))
  fi
}

expect_red() {  # expect_red <label> <tag e.g. C3>
  local tags
  run_test
  tags="$(printf '%s\n' "$OUT" | grep -oE '^FAIL C[0-9]:' | sort -u | tr '\n' ' ')"
  if [ "$RC" -eq 0 ]; then
    echo "SELFTEST FAIL: not caught (rc=0): $1"
    fails=$((fails + 1))
  elif [ "$tags" = "FAIL $2: " ]; then
    echo "RED ok ($2): $1"
  else
    echo "SELFTEST FAIL: rig error, wanted only 'FAIL $2:' got '${tags:-none}': $1"
    printf '%s\n' "$OUT" | sed 's/^/     | /'
    fails=$((fails + 1))
  fi
}

setup() {  # setup <label>: stage or count a rig failure
  if ! stage; then
    echo "SELFTEST FAIL: fixture setup failed (rig broken): $1"
    fails=$((fails + 1))
    return 1
  fi
}

if setup baseline; then expect_green "baseline fixture"; fi

if setup M1; then
  rm -f "$FIX/skills/subagent-driven-development/references/breaker-trip.md"
  expect_red "M1 delete breaker-trip.md (dangling pointer)" C1
fi

if setup M2; then
  printf '# Orphan\n\nRead this when never.\n' > "$FIX/skills/subagent-driven-development/references/orphan.md"
  expect_red "M2 unreferenced references/orphan.md" C2
fi

if setup M3; then
  rm -rf "$FIX/$WD/references"
  mkdir -p "$FIX/$WD/references"
  sed -i.bak 's#references/long-form-diagnostics\.md#REMOVED#g' "$FIX/$WD/SKILL.md"
  rm -f "$FIX/$WD/SKILL.md.bak"
  expect_red "M3 empty references dir, no same-skill pointers (vacuous pass)" C3
fi

if setup M4; then
  printf '# Bad\n\nRead this when never.\n' > "$FIX/$WD/references/Bad_Name.md"
  printf '\nSee references/Bad_Name.md for nothing.\n' >> "$FIX/$WD/SKILL.md"
  expect_red "M4 references/Bad_Name.md (ill-formed name)" C4
fi

if setup M5; then
  printf '# X\n\nRead this when you test.\n' > "$FIX/$WD/references/x.md"
  printf '%s\n' "" "**Read \`references/x.md\` (in this skill's directory) before y**" >> "$FIX/$WD/SKILL.md"
  printf 'x.md\n' >> "$FIX/$REG/write-documentation.txt"
  expect_red "M5 registry pointer with no gist" C5
fi

if setup M6; then
  add_entry good 10 no
  printf '# Good File\n\nNothing useful here.\n' > "$FIX/$WD/references/good.md"
  expect_red "M6 registry file missing its 'Read this when' line" C6
fi

if setup M7a; then
  add_entry good 101 no
  expect_red "M7 registry file of 101 lines without Contents:" C7
fi
if setup M7b; then
  add_entry good 100 no
  expect_green "M7 control: exactly 100 lines needs no Contents:"
fi
if setup M7c; then
  add_entry good 101 yes
  expect_green "M7 control: 101 lines with Contents:"
fi

if setup M8a; then
  add_entry good 10 no
  printf 'See references/other.md for more.\n' >> "$FIX/$WD/references/good.md"
  expect_red "M8 registry file names same-skill references/other.md" C8
fi
if setup M8b; then
  add_entry good 10 no
  printf 'See ../using-superpowers/references/codex-tools.md for more.\n' >> "$FIX/$WD/references/good.md"
  expect_green "M8 control: cross-skill pointer is not a chain"
fi

if setup M9; then
  add_entry good 10 no
  sed -i.bak 's/$/\r/' "$FIX/$WD/SKILL.md" "$FIX/$WD/references/good.md" "$FIX/$REG/write-documentation.txt"
  rm -f "$FIX/$WD/SKILL.md.bak" "$FIX/$WD/references/good.md.bak" "$FIX/$REG/write-documentation.txt.bak"
  expect_green "M9 CRLF SKILL.md + registry + moved file"
fi

if [ "$fails" -eq 0 ]; then
  echo "SELFTEST OK: skill-references guard"
  exit 0
fi
echo "SELFTEST FAILED: $fails problem(s)"
exit 1
