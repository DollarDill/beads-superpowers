#!/usr/bin/env bash
# runtime-detect.sh — container-runtime selection for the installer E2E harness.
# Sourceable: defines select_runtime with a strict I/O contract so that
# `RUNTIME=$(select_runtime)` captures ONLY the runtime name.
#   stdout : chosen runtime name (docker|podman), nothing else
#   stderr : all diagnostics / errors
#   return : 0 on success, non-zero on failure
# No top-level side effects — safe to source.

select_runtime() {
  local rt
  if [ -n "${CONTAINER_RUNTIME:-}" ]; then
    rt="$CONTAINER_RUNTIME"
    if ! command -v "$rt" >/dev/null 2>&1; then
      echo "error: CONTAINER_RUNTIME=$rt set but '$rt' not found on PATH" >&2
      return 1
    fi
    printf '%s\n' "$rt"
    return 0
  fi
  if command -v docker >/dev/null 2>&1; then
    printf 'docker\n'
    return 0
  fi
  if command -v podman >/dev/null 2>&1; then
    printf 'podman\n'
    return 0
  fi
  echo "error: neither docker nor podman found on PATH (set CONTAINER_RUNTIME or install one)" >&2
  return 1
}
