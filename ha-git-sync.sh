#!/bin/bash
set -uo pipefail

REPO_PATH="${REPO_PATH:-/config}"
BRANCH="${BRANCH:-main}"
POLL=5
DEBOUNCE=30

export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-ChronoSeal Watcher}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-watcher@chronoseal.local}"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

cd "$REPO_PATH" || { echo "Няма достъп до $REPO_PATH"; exit 1; }
[ -d ".git" ] || { echo "Не е Git репозиторий"; exit 1; }

echo "[$(date '+%F %T')] Наблюдение над $REPO_PATH (клон $BRANCH)..."

last_sig=""
last_change=0

while :; do
  sleep "$POLL"
  sig=$(find "$REPO_PATH" -type f -not -path '*/.git/*' \
        -printf '%p %T@ %s\n' 2>/dev/null | sort | md5sum)

  if [ "$sig" != "$last_sig" ]; then
    last_sig="$sig"
    last_change=$(date +%s)
    continue
  fi

  now=$(date +%s)
  [ "$last_change" -eq 0 ] && continue
  [ $((now - last_change)) -lt "$DEBOUNCE" ] && continue

  cd "$REPO_PATH" || continue
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null
    if git push -u origin "$BRANCH" >/dev/null 2>&1; then
      echo "[$(date '+%H:%M:%S')] Commit + push OK"
    else
      echo "[$(date '+%H:%M:%S')] Push неуспешен"
    fi
  fi
  last_change=0
done
