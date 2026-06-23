$scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "gemini_rewrite_selection.ahk"
$autoHotkey = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

Start-Process -WindowStyle Hidden -FilePath $autoHotkey -ArgumentList $scriptPath
