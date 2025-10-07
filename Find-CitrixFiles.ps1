<#
.SYNOPSIS
    Searches for ICA files and Citrix logs that may contain sensitive info.
#>

$searchPaths = @(
    "$env:USERPROFILE",
    "$env:LOCALAPPDATA\Citrix",
    "$env:APPDATA\Citrix"
)

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Recurse -Include *.ica,*.log -ErrorAction SilentlyContinue |
            Select-Object FullName, Length, LastWriteTime
    }
}
