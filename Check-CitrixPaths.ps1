<#
.SYNOPSIS
    Checks Citrix installation folders for weak ACLs (user-writable).
#>

$paths = @(
    "$env:ProgramFiles\Citrix",
    "$env:ProgramFiles(x86)\Citrix",
    "$env:ProgramData\Citrix",
    "$env:LOCALAPPDATA\Citrix",
    "$env:APPDATA\Citrix"
)

foreach ($p in $paths) {
    if (Test-Path $p) {
        $acl = Get-Acl $p
        $writable = $false
        foreach ($ar in $acl.Access) {
            if ($ar.IdentityReference -match "Everyone|Users|Authenticated Users" -and
                $ar.AccessControlType -eq "Allow" -and
                $ar.FileSystemRights.ToString() -match "Write|Modify|FullControl") {
                $writable = $true
            }
        }
        [PSCustomObject]@{
            Path = $p
            WritableByUsers = $writable
        }
    }
}
