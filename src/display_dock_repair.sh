#!/bin/bash
set -u

DO_REPAIR=false
DRY_RUN=false
ASSUME_YES=false
RESET_LAYOUT=false
RESTART_USB=false
OUTPUT_DIR=""
FAILURES=0
ACTIONS=0

usage() {
  cat <<'EOF'
Usage: display_dock_repair.sh [options]

  --repair          Restart display-policy and user-interface services.
  --restart-usb     Also restart the USB service. Connected devices may disconnect briefly.
  --reset-layout    Back up and reset saved WindowServer display-layout preferences.
  --dry-run         Show actions without changing the Mac.
  --yes             Skip confirmation prompts.
  --output DIR      Save logs, backup and verification output in DIR.
  -h, --help        Show help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repair) DO_REPAIR=true; shift ;;
    --restart-usb) RESTART_USB=true; DO_REPAIR=true; shift ;;
    --reset-layout) RESET_LAYOUT=true; DO_REPAIR=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 1; }

TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME=$(/usr/bin/dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
[ -n "$TARGET_HOME" ] || TARGET_HOME="$HOME"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./display-dock-repair-$STAMP}"
BACKUP_DIR="$OUTPUT_DIR/backup"
mkdir -p "$OUTPUT_DIR" "$BACKUP_DIR"
LOG="$OUTPUT_DIR/repair.log"
VERIFY="$OUTPUT_DIR/verification.txt"
: > "$LOG"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
confirm() {
  $ASSUME_YES && return 0
  printf '%s [y/N]: ' "$1"
  read -r answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
run_action() {
  description="$1"; shift
  ACTIONS=$((ACTIONS + 1)); log "$description"
  if $DRY_RUN; then
    printf 'DRY-RUN:' >> "$LOG"; for arg in "$@"; do printf ' %q' "$arg" >> "$LOG"; done; printf '\n' >> "$LOG"; return 0
  fi
  if "$@" >> "$LOG" 2>&1; then log "SUCCESS: $description"; return 0; fi
  FAILURES=$((FAILURES + 1)); log "WARNING: $description failed"; return 1
}
run_admin() {
  description="$1"; shift
  if [ "$(id -u)" -eq 0 ]; then run_action "$description" "$@"; else run_action "$description" /usr/bin/sudo "$@"; fi
}
verify() {
  {
    echo "Collected: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Host: $(hostname)"
    echo
    echo "Displays and graphics:"
    /usr/sbin/system_profiler SPDisplaysDataType 2>/dev/null | head -n 450
    echo
    echo "Thunderbolt and USB:"
    /usr/sbin/system_profiler SPThunderboltDataType SPUSBDataType 2>/dev/null | head -n 600
    echo
    echo "Power state:"
    /usr/bin/pmset -g batt 2>/dev/null || true
    echo
    echo "Display-related processes:"
    ps -Ao pid,user,etime,comm,args | awk 'NR == 1 || /WindowServer|displaypolicyd|corebrightnessd|SystemUIServer|Dock|usbd/' || true
  } > "$VERIFY" 2>&1
}
backup_layout_preferences() {
  found=false
  for pref in "$TARGET_HOME"/Library/Preferences/ByHost/com.apple.windowserver.*.plist "$TARGET_HOME"/Library/Preferences/com.apple.windowserver.plist; do
    [ -e "$pref" ] || continue
    found=true
    target="$BACKUP_DIR/$(basename "$pref")"
    run_action "Backing up display layout preference $(basename "$pref")" /bin/mv "$pref" "$target" || true
  done
  $found || log "INFO: No saved WindowServer display-layout preference files were found."
}

verify
if ! $DO_REPAIR; then log "Verification-only mode completed. Use --repair to apply repairs."; exit 0; fi
if ! confirm "Restart display and docking-related services? Screens or devices may flicker briefly."; then log "Repair cancelled by user."; exit 0; fi

for process_name in Dock SystemUIServer corebrightnessd; do
  if pgrep -x "$process_name" >/dev/null 2>&1; then run_action "Restarting $process_name" /usr/bin/killall "$process_name" || true; fi
done
run_admin "Restarting display policy service" /bin/launchctl kickstart -k system/com.apple.displaypolicyd || \
  run_admin "Requesting display policy process restart" /usr/bin/killall displaypolicyd || true

if $RESTART_USB && confirm "Restart the USB service now? USB devices may disconnect temporarily."; then
  run_admin "Restarting USB service" /bin/launchctl kickstart -k system/com.apple.usbd || \
    run_admin "Requesting USB process restart" /usr/bin/killall usbd || true
fi

if $RESET_LAYOUT && confirm "Back up and reset saved display-layout preferences? A sign-out or restart may be required."; then
  backup_layout_preferences
  log "INFO: Display-layout reset will take full effect after sign-out or restart."
fi

if ! $DRY_RUN; then sleep 6; fi
verify

DISPLAY_POLICY_OK=false
pgrep -x displaypolicyd >/dev/null 2>&1 && DISPLAY_POLICY_OK=true
if ! $DISPLAY_POLICY_OK; then FAILURES=$((FAILURES + 1)); log "WARNING: displaypolicyd is not running after repair."; fi

if [ "$FAILURES" -gt 0 ]; then log "Repair completed with $FAILURES warning(s). Backup: $BACKUP_DIR"; exit 1; fi
log "Repair completed successfully. Actions performed: $ACTIONS. Backup: $BACKUP_DIR"
exit 0
