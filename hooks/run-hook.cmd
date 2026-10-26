: << 'CMDBLOCK'
@echo off
REM Cross-platform polyglot wrapper for hook scripts.
REM On Windows: cmd.exe runs the batch portion, which finds and calls bash.
REM On Unix: the shell interprets this as a script (: is a no-op in bash).
REM
REM Hook scripts use extensionless filenames (e.g. "session-start" not
REM "session-start.sh") so Claude Code's Windows auto-detection -- which
REM prepends "bash" to any command containing .sh -- doesn't interfere.
REM
REM Usage: run-hook.cmd <script-name> [args...]

if "%~1"=="" (
    echo run-hook.cmd: missing script name >&2
    exit /b 1
)

setlocal
set "HOOK_DIR=%~dp0"
set "BASH_EXE="

REM Git for Windows in its standard system-wide locations
if exist "C:\Program Files\Git\bin\bash.exe" set "BASH_EXE=C:\Program Files\Git\bin\bash.exe"
if not defined BASH_EXE if exist "C:\Program Files (x86)\Git\bin\bash.exe" set "BASH_EXE=C:\Program Files (x86)\Git\bin\bash.exe"

REM Per-user Git for Windows install (no admin rights needed). The defined
REM check matters: with LOCALAPPDATA unset the path would collapse to
REM \Programs\Git\... on the current drive, where any user can create it.
if not defined BASH_EXE if defined LOCALAPPDATA if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "BASH_EXE=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"

REM bash on PATH (MSYS2, Cygwin, a non-default Git install). where.exe is
REM called by full path and with $PATH: so neither it nor bash can come from
REM the current directory. The filters use for-variable modifiers, which never
REM re-expand the path, and skip extensionless matches and the WSL launchers
REM (System32, Sysnative, the Store alias in WindowsApps), which fail when no
REM Linux distro is installed.
if not defined BASH_EXE if defined SystemRoot for /f "delims=" %%B in ('"%SystemRoot%\System32\where.exe" $PATH:bash 2^>nul') do if not defined BASH_EXE if not "%%~xB"=="" if /i not "%%~dpB"=="%SystemRoot%\System32\" if /i not "%%~dpB"=="%SystemRoot%\Sysnative\" if /i not "%%~dpB"=="%LOCALAPPDATA%\Microsoft\WindowsApps\" set "BASH_EXE=%%B"

REM No bash found - exit silently rather than error
REM (plugin still works, just without SessionStart context injection)
if not defined BASH_EXE exit /b 0

REM Run bash outside any parenthesized block: cmd expands %ERRORLEVEL%
REM inside a block when it parses the block, which would lose the hook's
REM exit code.
"%BASH_EXE%" "%HOOK_DIR%%~1" %2 %3 %4 %5 %6 %7 %8 %9
exit /b %ERRORLEVEL%
CMDBLOCK

# Unix: run the named script with a bash that never comes from the project.
# An empty or relative PATH entry (or PATH="") makes a command lookup search
# the current directory, which for a hook is an untrusted project, and Claude
# Code can spawn hooks with a broken or empty PATH (anthropics/claude-code#43127).
# POSIX sh, because this half also runs under dash (Linux /bin/sh).
# 1. Clean PATH before any lookup, with hooks/session-start's rule: keep
#    absolute entries, map ~ and ~/x to $HOME when $HOME is absolute, drop
#    everything else, and fall back to /usr/bin:/bin.
# 2. Use `command -v bash` on that PATH, else $BASH, taking each only when it
#    is absolute, has no . or .. component and does not literally start
#    with the cwd (the signatures of a relative PATH entry), and lies outside
#    both the current directory tree and the project root
#    (CLAUDE_PROJECT_DIR, else CURSOR_PROJECT_DIR; with neither set, the
#    highest .git ancestor of the cwd; the cwd can be a subdirectory of it),
#    and not this launcher. A root variable that is relative or unresolvable
#    refuses it. The cleaned PATH can still hold an absolute entry inside
#    the project (<proj>/node_modules/.bin, direnv PATH_add), so the
#    `command -v` result gets the same check as $BASH.
#    $BASH alone is not safe: dash leaves it unset, bash fills it by a PATH
#    search that can land in the cwd, and an ENOEXEC fallback (a harness
#    execing this shebang-less file) sets it to this launcher, which would
#    re-exec itself forever.
# 3. No usable bash: exit 0 silently, as the Windows half does.
bsp_safe_path=""
bsp_old_ifs=$IFS
IFS=:
set -f
for bsp_p in ${PATH:-}; do
  # shellcheck disable=SC2088 # matches literal ~ entries, mapped to $HOME here
  case "$bsp_p" in
    /*) ;;
    "~"|"~/"*)
      case "${HOME:-}" in
        /*) bsp_p="${HOME}${bsp_p#\~}" ;;
        *) continue ;;
      esac ;;
    *) continue ;;
  esac
  bsp_safe_path="${bsp_safe_path:+$bsp_safe_path:}$bsp_p"
done
set +f
IFS=$bsp_old_ifs
PATH="${bsp_safe_path:-/usr/bin:/bin}"; export PATH

# Split $0 on its last / or \ (cmd passes Windows paths) instead of calling
# dirname.
case "$0" in
  */*|*\\*) SCRIPT_DIR="$(cd "${0%[/\\]*}" && pwd)" ;;
  *) SCRIPT_DIR="$(pwd)" ;;
esac

# bsp_outside <bash>: succeeds when the candidate passes the containment in
# step 2. Applied to the `command -v bash` result and to $BASH alike; the
# comments inside say $BASH for either.
bsp_outside() {
  # A . or .. component is the signature of a relative PATH entry: bash
  # records its lookup unnormalised (<cwd>/../bash), which can land above or
  # beside a root that is just the cwd. Refuse it, whatever the root.
  case "$1" in
    */./*|*/../*|*/.|*/..) ;;
    /*)
      # Compare physical paths: $BASH and $PWD can name the same place through
      # different symlinks. cd -P hands the path to chdir unchanged, so the
      # kernel resolves it as exec will: a symlink before the ".." after it
      # (a plain cd would cancel lnk/.. as text first).
      # bash keeps a leading // through cd -P and pwd -P (dash collapses it),
      # and //x never matches a /x prefix: each resolved path has a leading
      # run of slashes collapsed to one.
      bsp_cwd=$(pwd -P 2>/dev/null) || bsp_cwd=""
      case $bsp_cwd in //*) bsp_cwd=/${bsp_cwd#"${bsp_cwd%%[!/]*}"} ;; esac
      # The root is CLAUDE_PROJECT_DIR, else CURSOR_PROJECT_DIR. Either one
      # set but not absolute, or a named root that does not resolve: refuse.
      bsp_ok=1
      bsp_root=""
      case "${CLAUDE_PROJECT_DIR:-}" in
        "") ;;
        /*) bsp_root=$CLAUDE_PROJECT_DIR ;;
        *) bsp_ok=0 ;;
      esac
      case "${CURSOR_PROJECT_DIR:-}" in
        "") ;;
        /*) if [ -z "$bsp_root" ]; then bsp_root=$CURSOR_PROJECT_DIR; fi ;;
        *) bsp_ok=0 ;;
      esac
      # A $BASH that literally starts with the cwd came from a relative PATH
      # entry, symlinked or not: bash builds it as $PWD/<entry>/bash. Compare
      # it with the logical cwd ($PWD, when set) and the physical one, with a
      # leading run of slashes collapsed in each and in $BASH. Refuse a match,
      # whatever the root. Accepted over-refusal: a real bash reached through a
      # symlink under the cwd (cwd = $HOME, ~/.nix-profile/bin/bash) is refused.
      # bash 5.x builds $BASH from its canonical cwd but keeps an inherited
      # $PWD as spelled (//, /./, doubled /), so also compare with the
      # canonical logical cwd, from cd "$PWD" && pwd. If that cd fails, refuse.
      bsp_lit=$1
      case $bsp_lit in //*) bsp_lit=/${bsp_lit#"${bsp_lit%%[!/]*}"} ;; esac
      bsp_pwd=${PWD:-}
      case $bsp_pwd in //*) bsp_pwd=/${bsp_pwd#"${bsp_pwd%%[!/]*}"} ;; esac
      bsp_phys_pfx=${bsp_cwd%/}
      bsp_pwd_pfx=$bsp_phys_pfx
      if [ -n "$bsp_pwd" ]; then bsp_pwd_pfx=${bsp_pwd%/}; fi
      if [ -n "${PWD:-}" ]; then
        bsp_can=$(cd "$PWD" 2>/dev/null && pwd) || bsp_can=""
        case $bsp_can in //*) bsp_can=/${bsp_can#"${bsp_can%%[!/]*}"} ;; esac
        if [ -z "$bsp_can" ]; then bsp_ok=0; fi
      else
        bsp_can=$bsp_cwd
      fi
      bsp_can_pfx=${bsp_can%/}
      case "$bsp_lit" in
        "$bsp_pwd_pfx"/*|"$bsp_phys_pfx"/*|"$bsp_can_pfx"/*) bsp_ok=0 ;;
      esac
      if [ -n "$bsp_root" ]; then
        bsp_root=$(cd -P "$bsp_root/" 2>/dev/null && pwd -P) || bsp_root=""
        case $bsp_root in //*) bsp_root=/${bsp_root#"${bsp_root%%[!/]*}"} ;; esac
        if [ -z "$bsp_root" ]; then bsp_ok=0; fi
      elif [ "$bsp_ok" = 1 ]; then
        # No root variable (Codex sets none): the root is the highest
        # ancestor of the cwd holding a .git entry, else the cwd. Highest,
        # not nearest, so a .git the project plants deeper cannot shrink it.
        bsp_root=$bsp_cwd
        bsp_d=$bsp_cwd
        while [ -n "$bsp_d" ]; do
          if [ -e "${bsp_d%/}/.git" ]; then bsp_root=$bsp_d; fi
          if [ "$bsp_d" = / ]; then break; fi
          bsp_d=${bsp_d%/*}
          if [ -z "$bsp_d" ]; then bsp_d=/; fi
        done
      fi
      bsp_bash_dir=$(cd -P "${1%/*}/" 2>/dev/null && pwd -P) || bsp_bash_dir=""
      case $bsp_bash_dir in //*) bsp_bash_dir=/${bsp_bash_dir#"${bsp_bash_dir%%[!/]*}"} ;; esac
      if [ "$bsp_ok" = 1 ] && [ -n "$bsp_cwd" ] && [ -n "$bsp_root" ] && [ -n "$bsp_bash_dir" ]; then
        # Strip the trailing / into a variable first: at cwd / the prefix is
        # empty, and bash 5.3 does not match "${v%/}"/* when the expansion
        # is empty (dash and bash 3.2 do); "$v"/* matches in all three.
        bsp_cwd_pfx=${bsp_cwd%/}
        bsp_root_pfx=${bsp_root%/}
        case "$bsp_bash_dir/" in
          "$bsp_cwd_pfx"/*|"$bsp_root_pfx"/*) ;;
          *)
            if [ ! "$1" -ef "${SCRIPT_DIR}/${0##*[/\\]}" ]; then
              return 0
            fi ;;
        esac
      fi ;;
  esac
  return 1
}

bsp_bash=$(command -v bash 2>/dev/null) || bsp_bash=""
case "$bsp_bash" in
  /*) ;;
  *) bsp_bash="" ;;
esac
if [ -n "$bsp_bash" ] && ! bsp_outside "$bsp_bash"; then
  bsp_bash=""
fi
if [ -z "$bsp_bash" ] && bsp_outside "${BASH:-}"; then
  bsp_bash=$BASH
fi
if [ -z "$bsp_bash" ]; then
  exit 0
fi

SCRIPT_NAME="$1"
shift
exec "$bsp_bash" "${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"
