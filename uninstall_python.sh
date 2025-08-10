#!/bin/sh
set -eu

# Uninstall python.org CPython builds on macOS (POSIX shell).
# Removes:
#   /Library/Frameworks/Python.framework/Versions/<ver>
#   /Applications/Python <ver>
#   /usr/local/bin symlinks pointing into that Framework
#   pkgutil receipts for that version
#
# Dry-run by default; pass --yes to actually delete.

DRY_RUN=1
ONLY_VERSIONS=""

say() { printf "%s\n" "$*"; }

usage() {
  cat <<'EOF'
Usage:
  sh uninstall_python_org.sh [--yes] [--versions 3.10 3.11]

By default this is a dry run. Add --yes to actually remove.
EOF
  exit 0
}

# Parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) DRY_RUN=0 ;;
    --versions)
      shift
      while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do
        ONLY_VERSIONS="$ONLY_VERSIONS $1"
        shift
      done
      continue
      ;;
    -h|--help) usage ;;
    *) say "Unknown option: $1"; exit 2 ;;
  esac
  shift
done

FRAME_ROOT="/Library/Frameworks/Python.framework/Versions"
APP_ROOT="/Applications"
BIN_DIR="/usr/local/bin"

# Helpers
rm_path() {
  p="$1"
  if [ -e "$p" ] || [ -L "$p" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      say "DRY-RUN: rm -rf \"$p\""
    else
      sudo rm -rf "$p"
    fi
  fi
}

in_list() {
  needle="$1"; list="$2"
  for x in $list; do [ "$x" = "$needle" ] && return 0; done
  return 1
}

remove_symlinks_for_version() {
  ver="$1"
  target_prefix="$FRAME_ROOT/$ver"
  [ -d "$BIN_DIR" ] || return 0
  for f in "$BIN_DIR"/*; do
    [ -L "$f" ] || continue
    base=`basename "$f"`
    # Resolve link (one hop is enough for python.org layout)
    ( cd "$BIN_DIR" 2>/dev/null || exit 0
      tgt=`readlink "$base" 2>/dev/null || true`
      [ -n "$tgt" ] || exit 0
      case "$tgt" in
        /*) abs="$tgt" ;;
        *) abs="$BIN_DIR/$tgt" ;;
      esac
      case "$abs" in
        "$target_prefix"*)
          if [ "$DRY_RUN" -eq 1 ]; then
            say "DRY-RUN: rm \"$BIN_DIR/$base\"   (-> $abs)"
          else
            sudo rm "$BIN_DIR/$base"
            say "Removed symlink: $BIN_DIR/$base"
          fi
        ;;
      esac
    )
  done
}

forget_receipts_for_version() {
  ver="$1"
  # Escape dots for grep
  ver_re=`echo "$ver" | sed 's/\./\\./g'`
  receipts=`pkgutil --pkgs | grep -E "org\.python\.Python\.(PythonFramework|Python|Documentation)-$ver_re" || true`
  if [ -z "$receipts" ]; then
    receipts=`pkgutil --pkgs | grep -E "org\.python\.(Python|PythonFramework).*${ver_re}" || true`
  fi
  [ -z "$receipts" ] && return 0
  echo "$receipts" | while IFS= read -r rid; do
    [ -n "$rid" ] || continue
    if [ "$DRY_RUN" -eq 1 ]; then
      say "DRY-RUN: sudo pkgutil --forget \"$rid\""
    else
      sudo pkgutil --forget "$rid" >/dev/null && say "Forgot receipt: $rid"
    fi
  done
}

# Find installed python.org versions
if [ ! -d "$FRAME_ROOT" ]; then
  say "No python.org framework directory at $FRAME_ROOT"
  exit 0
fi

FOUND_VERSIONS=`ls -1 "$FRAME_ROOT" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+' || true`
[ -n "$FOUND_VERSIONS" ] || { say "No python.org versions found."; exit 0; }

# Filter if ONLY_VERSIONS was provided
if [ -n "$ONLY_VERSIONS" ]; then
  FILTERED=""
  for v in $FOUND_VERSIONS; do
    if in_list "$v" "$ONLY_VERSIONS"; then
      FILTERED="$FILTERED $v"
    fi
  done
  FOUND_VERSIONS=`echo "$FILTERED" | awk '{$1=$1;print}'`
  [ -n "$FOUND_VERSIONS" ] || { say "No matching versions found for:$ONLY_VERSIONS"; exit 1; }
fi

say "Found python.org versions: $FOUND_VERSIONS"
[ "$DRY_RUN" -eq 1 ] && say "(dry run; add --yes to actually delete)\n"

for ver in $FOUND_VERSIONS; do
  say "—— Uninstalling python.org Python $ver ——"
  rm_path "$APP_ROOT/Python $ver"                    # IDLE & scripts
  remove_symlinks_for_version "$ver"                 # /usr/local/bin symlinks
  rm_path "$FRAME_ROOT/$ver"                         # Framework version
  forget_receipts_for_version "$ver"                 # pkgutil receipts
  say ""
done

say "Done."
# Quick post-check
cmd=`command -v python3 || true`; ver=`python3 --version 2>/dev/null || true`
[ -n "$cmd" ] && say "python3 now points to: $cmd ($ver)"
