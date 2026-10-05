#!/usr/bin/env bash
# Seeds a tiny settings app for the brainstorming eval cases.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p src
cat > README.md <<'EOF'
# Tiny settings app

A minimal example app with a settings page.
EOF
cat > index.html <<'EOF'
<!doctype html>
<html>
  <body>
    <div id="app"></div>
    <script type="module" src="src/app.js"></script>
  </body>
</html>
EOF
cat > src/app.js <<'EOF'
import { renderSettings } from "./settings.js";

const state = { notifications: true };
document.getElementById("app").innerHTML = renderSettings(state);
EOF
cat > src/settings.js <<'EOF'
// Settings page. It currently has one option: a Notifications toggle.
export function renderSettings(state) {
  return `
    <section class="settings">
      <h1>Settings</h1>
      <label>
        <input type="checkbox" id="notifications" ${state.notifications ? "checked" : ""}>
        Notifications
      </label>
    </section>`;
}
EOF
