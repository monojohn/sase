<#
.SYNOPSIS
  Finds user-writable paths in executable search locations on Windows 11.

.DESCRIPTION
  Checks every folder in the user's current PATH plus default executable search folders
  (e.g., %WINDIR%, %WINDIR%\System32, %WINDIR%\System, %WINDIR%\SysWOW64 when present).
  Flags directories that the current user can write to (potentially dangerous).

.PARAMETER DryRun
  Estimate writability via ACLs only (no file creation). Faster, but may be inaccurate.

.PARAMETER ExtraPaths
  Add any additional directories you want checked.

.EXAMPLE
  .\Test-ExecWritablePaths.ps1
  .\Test-ExecWritablePaths.ps1 -DryRun
  .\Test-ExecWritablePaths.ps1 -ExtraPaths 'C:\Program Files\App\bin','C:\Tools'
#>

[CmdletBinding()]
param(
  [switch]$DryRun,
  [string[]]$ExtraPaths
)

# Helpers
function Resolve-NormalizedPath {
  param([Parameter(Mandatory)][string]$Path)
  try {
    if (Test-Path -LiteralPath $Path -PathType Container) {
      return (Get-Item -LiteralPath $Path -Force).FullName.TrimEnd('\')
    }
  } catch {}
  return $null
}

function Test-DirectoryWritable {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Directory,
    [switch]$DryRun
  )

  if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return $false }

  if ($DryRun) {
    # Heuristic ACL check (may miss effective denies)
    try {
      $acl = Get-Acl -LiteralPath $Directory
      $id  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
      $principal = New-Object System.Security.Principal.WindowsPrincipal($id)

      $writeBits = [System.Security.AccessControl.FileSystemRights]::Write, `
                   [System.Security.AccessControl.FileSystemRights]::CreateFiles, `
                   [System.Security.AccessControl.FileSystemRights]::AppendData, `
                   [System.Security.AccessControl.FileSystemRights]::WriteData, `
                   [System.Security.AccessControl.FileSystemRights]::Modify, `
                   [System.Security.AccessControl.FileSystemRights]::Delete, `
                   [System.Security.AccessControl.FileSystemRights]::WriteAttributes, `
                   [System.Security.AccessControl.FileSystemRights]::WriteExtendedAttributes

      $allow = $false
      foreach ($rule in $acl.Access) {
        $sid = try { New-Object System.Security.Principal.SecurityIdentifier($rule.IdentityReference.Value) } catch { $null }
        if (-not $sid) { continue }

        $inScope = ($id.User -eq $sid) -or ($id.Groups -contains $sid) -or $principal.IsInRole($sid)
        if (-not $inScope) { continue }

        $hasWrite = ($rule.FileSystemRights -band ($writeBits -join ',')) -ne 0
        if ($hasWrite -and $rule.AccessControlType -eq 'Deny') { return $false }
        if ($hasWrite -and $rule.AccessControlType -eq 'Allow') { $allow = $true }
      }
      return $allow
    } catch {
      return $false
    }
  }
  else {
    # Ground-truth probe: create & delete a tiny temp file
    try {
      $probe = Join-Path -Path $Directory -ChildPath ("._perm_" + [Guid]::NewGuid().ToString("N") + ".tmp")
      $fs = [System.IO.File]::Open($probe, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
      $fs.Close()
      Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
      return $true
    } catch {
      return $false
    }
  }
}

function Get-ExecSearchFolders {
  # Collect from PATH and add the standard Windows search folders
  $paths = @()

  # PATH entries
  if ($env:Path) {
    $paths += ($env:Path -split ';' | Where-Object { $_ -and $_.Trim() -ne '' })
  }

  # Core Windows search folders (order trimmed for our purposes)
  $win = $env:WINDIR
  if ($win) {
    $paths += $win
    $paths += (Join-Path $win 'System32')
    $paths += (Join-Path $win 'System')
    if ([Environment]::Is64BitOperatingSystem) {
      $paths += (Join-Path $win 'SysWOW64')
    }
  }

  # Extra paths from user
  if ($ExtraPaths) { $paths += $ExtraPaths }

  # Normalize, de-dup, and only keep existing folders
  $normalized = @{}
  foreach ($p in $paths) {
    $n = Resolve-NormalizedPath -Path $p
    if ($n -and -not $normalized.ContainsKey($n.ToLowerInvariant())) {
      $normalized[$n.ToLowerInvariant()] = $n
    }
  }
  return $normalized.GetEnumerator() | ForEach-Object { $_.Value }
}

# Main
$folders = Get-ExecSearchFolders

$results = foreach ($dir in $folders) {
  $writable = Test-DirectoryWritable -Directory $dir -DryRun:$DryRun
  $owner = $null
  $isReparse = $false
  $target = $null
  try {
    $item = Get-Item -LiteralPath $dir -Force
    $isReparse = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
    if ($isReparse -and ($item | Get-Member -Name Target -MemberType NoteProperty,Property)) {
      $target = $item.Target -join '; '
    }
    $owner = (Get-Acl -LiteralPath $dir).Owner
  } catch {}

  [PSCustomObject]@{
    Path          = $dir
    Writable      = $writable
    Owner         = $owner
    ReparsePoint  = $isReparse
    Target        = $target
  }
}

# Output
$results |
  Sort-Object -Property @{Expression='Writable';Descending=$true}, Path |
  Tee-Object -Variable Sorted |
  Format-Table -AutoSize

# Also emit only the risky ones as objects for easy piping/saving
$risky = $Sorted | Where-Object { $_.Writable -eq $true }
if ($risky) {
  Write-Host "`n[*] User-writable executable search paths found:`n" -ForegroundColor Yellow
  $risky | ForEach-Object { Write-Host " - $($_.Path)" -ForegroundColor Yellow }
} else {
  Write-Host "`n[+] No user-writable executable search paths detected." -ForegroundColor Green
}
