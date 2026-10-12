#!/usr/bin/env bash
# Seeds a tiny range() module whose test fails on a planted off-by-one.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p src test
cat > package.json <<'EOT'
{
  "name": "range-demo",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
EOT
cat > src/range.js <<'EOT'
/**
 * Returns the integers from start to end, inclusive.
 */
export function range(start, end) {
  const result = [];
  for (let i = start; i < end; i++) {
    result.push(i);
  }
  return result;
}
EOT
cat > test/range.test.js <<'EOT'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { range } from '../src/range.js';

test('range is inclusive of end', () => {
  assert.deepStrictEqual(range(1, 4), [1, 2, 3, 4]);
});
EOT
