#!/bin/bash
set -uo pipefail
REPO_PATH="${REPO_PATH:-/config}"
BRANCH="${BRANCH:-main}"
POLL="${POLL:-5}"
DEBOUNCE="${DEBOUNCE:-30}"
STATE_DIR="$REPO_PATH/.git-sync"
LOG_FILE="$STATE_DIR/watcher.log"
STOP_FILE="$STATE_DIR/stop"
STATE_FILE="$STATE_DIR/state.json"
mkdir -p "$STATE_DIR"; rm -f "$STOP_FILE"
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-ChronoSeal HA}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-ha@chronoseal.local}"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
cd "$REPO_PATH" || { echo "no access to $REPO_PATH"; exit 1; }
[ -d ".git" ] || { echo "not a git repo"; exit 1; }
STARTED_AT=$(date '+%Y-%m-%d %H:%M:%S')
LAST_CHANGE_STR="-"; LAST_COMMIT_STR="-"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
save_state() {
  cat > "$STATE_FILE" <<JSON
{
  "pid": $$,
  "status": "$1",
  "started": "$STARTED_AT",
  "lastChange": "$LAST_CHANGE_STR",
  "lastCommit": "$LAST_COMMIT_STR",
  "repoPath": "$REPO_PATH",
  "branch": "$BRANCH",
  "platform": "linux"
}
JSON
}
log "START watcher (PID=$$)"
save_state "running"
last_sig=""; last_change=0
while :; do
  if [ -f "$STOP_FILE" ]; then log "STOP marker"; save_state "stopped"; rm -f "$STOP_FILE"; exit 0; fi
  sleep "$POLL"
  sig=$(find "$REPO_PATH" -type f -not -path '*/.git/*' -not -path '*/.git-sync/*' -printf '%p %T@ %s\n' 2>/dev/null | sort | md5sum)
  if [ "$sig" != "$last_sig" ]; then
    last_sig="$sig"; last_change=$(date +%s); LAST_CHANGE_STR=$(date '+%Y-%m-%d %H:%M:%S')
    log "change detected"; save_state "running"; continue
  fi
  now=$(date +%s)
  [ "$last_change" -eq 0 ] && continue
  [ $((now - last_change)) -lt "$DEBOUNCE" ] && continue
  cd "$REPO_PATH" || continue
  git add -A
  if ! git diff --cached --quiet; then
    log "commit..."
    git commit -m "auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null
    if git push -u origin "$BRANCH" >/dev/null 2>&1; then
      LAST_COMMIT_STR=$(date '+%Y-%m-%d %H:%M:%S'); log "push OK"
    else log "push failed"; fi
    save_state "running"
  fi
  last_change=0
done
