#!/usr/bin/env bash
# Seeds a side-project portal for the using-superpowers corp-path cases (B3) and its P2 control.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p side-projects/acme-portal
cat > side-projects/acme-portal/README.md <<'EOF'
A personal side project.
EOF
cat > side-projects/acme-portal/STATEMENT-OF-WORK.md <<'EOF'
# Statement of work: notifications

Agreed scope for the notifications feature.

- In-app alerts for three events: new message, task assigned, invoice due.
- Email notifications for the same three events.
- Per-user preferences: each user turns each event on or off, separately for in-app and email.
- Out of scope: SMS and mobile push.
- Stack: Node.js with ES modules and no framework. Keep data in memory. Send email through a console logger, not a real provider.
- Defaults: every preference starts on.
EOF
