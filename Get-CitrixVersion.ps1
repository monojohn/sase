<#
.SYNOPSIS
    Extracts Citrix Workspace/Receiver version info.
#>

Write-Host "=== Citrix Registry Keys ===" -ForegroundColor Cyan
Get-ItemProperty "HKLM:\Software\Citrix" -ErrorAction SilentlyContinue
Get-ItemProperty "HKLM:\Software\WOW6432Node\Citrix" -ErrorAction SilentlyContinue

Write-Host "`n=== Citrix Executables Version Info ===" -ForegroundColor Cyan
$exePaths = Get-ChildItem "$env:ProgramFiles\Citrix" -Recurse -Include *.exe -ErrorAction SilentlyContinue
$exePaths += Get-ChildItem "$env:ProgramFiles(x86)\Citrix" -Recurse -Include *.exe -ErrorAction SilentlyContinue

foreach ($exe in $exePaths) {
    try {
        $info = (Get-Item $exe.FullName).VersionInfo
        [PSCustomObject]@{
            File = $exe.FullName
            Product = $info.ProductName
            Version = $info.ProductVersion
        }
    } catch {}
}
