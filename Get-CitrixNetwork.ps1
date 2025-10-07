<#
.SYNOPSIS
    Lists Citrix-related listening ports and processes.
#>

Get-NetTCPConnection -State Listen | ForEach-Object {
    try {
        $p = Get-Process -Id $_.OwningProcess -ErrorAction Stop
        if ($p.ProcessName -match "Citrix|wfica32|Receiver|SelfService") {
            [PSCustomObject]@{
                Process    = $p.ProcessName
                PID        = $p.Id
                LocalPort  = $_.LocalPort
                LocalAddr  = $_.LocalAddress
                Path       = $p.Path
            }
        }
    } catch {}
} | Format-Table -AutoSize
