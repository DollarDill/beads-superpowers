#!/usr/bin/env bash
# Seeds a corporate-work portal for the using-superpowers corp-path met case (B2).
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p corporate-work/acme-portal
cat > corporate-work/acme-portal/README.md <<'EOF'
Client portal for Acme Corp (consultancy engagement). Built to the agreed statement of work.
EOF
cat > corporate-work/acme-portal/STATEMENT-OF-WORK.md <<'EOF'
# Statement of work: notifications

Agreed scope for the notifications feature.

- In-app alerts for three events: new message, task assigned, invoice due.
- Email notifications for the same three events.
- Per-user preferences: each user turns each event on or off, separately for in-app and email.
- Out of scope: SMS and mobile push.
EOF
