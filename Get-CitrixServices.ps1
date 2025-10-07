<#
.SYNOPSIS
    Enumerates Citrix-related services and autorun entries.
#>

Write-Host "=== Citrix Services ===" -ForegroundColor Cyan
Get-Service | Where-Object { $_.DisplayName -match "Citrix" } |
    Select-Object DisplayName, Name, Status, StartType | Format-Table -AutoSize

Write-Host "`n=== Citrix Autoruns (Startup Commands) ===" -ForegroundColor Cyan
Get-CimInstance Win32_StartupCommand | Where-Object { $_.Caption -match "Citrix" } |
    Select-Object Name, Command, Location | Format-Table -AutoSize
