#!/usr/bin/env bash
# Seeds a tiny CLI with no spec for the writing-plans no-spec case.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
cat > package.json <<'EOF'
{
  "name": "tinytool",
  "version": "1.4.2",
  "bin": { "tinytool": "cli.js" }
}
EOF
cat > cli.js <<'EOF'
#!/usr/bin/env node
const args = process.argv.slice(2);

if (args.includes('--help')) {
  console.log('Usage: tinytool [--help]');
  process.exit(0);
}

console.error('Unknown arguments. Try --help.');
process.exit(1);
EOF
