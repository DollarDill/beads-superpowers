#!/usr/bin/env bash
# make-shims.sh <shim-dir> <marker-dir> <binary>... — inert-failing PATH shims.
set -euo pipefail
SHIM_DIR="$1"; MARKER_DIR="$2"; shift 2
mkdir -p "$SHIM_DIR" "$MARKER_DIR"
for bin in "$@"; do
  cat > "$SHIM_DIR/$bin" << SHIM
#!/usr/bin/env bash
touch "$MARKER_DIR/$bin.invoked"
exit 1
SHIM
  chmod +x "$SHIM_DIR/$bin"
done
