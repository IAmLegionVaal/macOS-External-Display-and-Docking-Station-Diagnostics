#!/bin/bash
set -u

HOURS=24
OUTPUT_DIR=""

usage(){ echo "Usage: display_dock_diagnostics.sh [--hours N] [--output DIR]"; }
while [ "$#" -gt 0 ]; do case "$1" in --hours) HOURS="${2:-24}"; shift 2;; --output) OUTPUT_DIR="${2:-}"; shift 2;; -h|--help) usage; exit 0;; *) echo "Unknown argument: $1" >&2; exit 2;; esac; done
case "$HOURS" in ''|*[!0-9]*) echo "--hours must be numeric" >&2; exit 2;; esac
[ "$(uname -s)" = Darwin ] || { echo "This tool must run on macOS." >&2; exit 1; }
STAMP=$(date +%Y%m%d_%H%M%S); OUTPUT_DIR="${OUTPUT_DIR:-./display-dock-$STAMP}"; mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/display-dock-report.txt"; CSV="$OUTPUT_DIR/displays.csv"; JSON="$OUTPUT_DIR/summary.json"; ERRORS="$OUTPUT_DIR/command-errors.log"; :>"$REPORT"; :>"$ERRORS"
echo 'display,resolution,refresh_rate,connection' > "$CSV"
section(){ t="$1"; shift; { printf '\n===== %s =====\n' "$t"; "$@"; } >>"$REPORT" 2>>"$ERRORS" || true; }
section "Metadata" /bin/bash -c 'date -u +%Y-%m-%dT%H:%M:%SZ; hostname; sw_vers; id'
section "Displays and graphics" /usr/sbin/system_profiler SPDisplaysDataType
section "Thunderbolt devices" /usr/sbin/system_profiler SPThunderboltDataType
section "USB devices" /usr/sbin/system_profiler SPUSBDataType
section "Power information" /usr/sbin/system_profiler SPPowerDataType
section "Power state" /usr/bin/pmset -g batt
section "WindowServer process" /bin/bash -c 'ps -Ao pid,user,etime,comm,args | grep -Ei "WindowServer|displaypolicyd|corebrightnessd" | grep -v grep || true'
section "Recent display events" /bin/bash -c "/usr/bin/log show --last ${HOURS}h --style compact --predicate '(process == \"WindowServer\") OR (process == \"displaypolicyd\") OR (eventMessage CONTAINS[c] \"Thunderbolt\") OR (eventMessage CONTAINS[c] \"DisplayPort\") OR (eventMessage CONTAINS[c] \"external display\")' 2>/dev/null | tail -n 4000"

system_profiler SPDisplaysDataType 2>/dev/null | awk '
  /^[[:space:]]{8}[^ ].*:$/ {name=$0; gsub(/^[[:space:]]+|:$/,"",name)}
  /Resolution:/ {res=$0; sub(/.*Resolution: /,"",res)}
  /Refresh Rate:/ {rate=$0; sub(/.*Refresh Rate: /,"",rate); print name"\t"res"\t"rate}
' | while IFS=$'\t' read -r name resolution rate; do
  printf '"%s","%s","%s","%s"\n' "$name" "$resolution" "$rate" "detected" >> "$CSV"
done
DISPLAY_COUNT=$(awk 'END{print NR-1}' "$CSV")
WINDOWSERVER_RUNNING=false; pgrep -x WindowServer >/dev/null 2>&1 && WINDOWSERVER_RUNNING=true
THUNDERBOLT_PRESENT=false; system_profiler SPThunderboltDataType 2>/dev/null | grep -q 'Thunderbolt Bus' && THUNDERBOLT_PRESENT=true
POWER_SOURCE=$(pmset -g batt 2>/dev/null | head -n1 | sed 's/.*Now drawing from //' | tr -d "\"'")
OVERALL="Healthy"; { ! $WINDOWSERVER_RUNNING || [ "$DISPLAY_COUNT" -eq 0 ]; } && OVERALL="Attention required"
cat > "$JSON" <<EOF
{"collected_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","hostname":"$(hostname)","display_count":$DISPLAY_COUNT,"windowserver_running":$WINDOWSERVER_RUNNING,"thunderbolt_bus_present":$THUNDERBOLT_PRESENT,"power_source":"$POWER_SOURCE","overall_status":"$OVERALL"}
EOF
printf '\nDisplay and dock diagnostics completed: %s\n' "$OUTPUT_DIR" | tee -a "$REPORT"
