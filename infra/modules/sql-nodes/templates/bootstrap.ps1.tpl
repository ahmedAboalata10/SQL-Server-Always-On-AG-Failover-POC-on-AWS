<powershell>
# Phase 2 bootstrap: hostname + hosts-file (no AD DNS) + Failover Clustering feature.
# WSFC cluster formation and SQL Server install happen in Phase 3 (manual-first, then scripted).

$ErrorActionPreference = "Stop"
Start-Transcript -Path "C:\bootstrap-log.txt" -Append

$currentName = (Get-WmiObject Win32_ComputerSystem).Name
if ($currentName -ne "${node_name}") {
    Rename-Computer -NewName "${node_name}" -Force
}

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsEntries = @"
${hosts_entries}
"@
Add-Content -Path $hostsPath -Value $hostsEntries

Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools

Stop-Transcript

if ($currentName -ne "${node_name}") {
    Restart-Computer -Force
}
</powershell>
<persist>false</persist>
