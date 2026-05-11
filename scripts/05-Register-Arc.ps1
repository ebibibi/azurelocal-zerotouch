#Requires -RunAsAdministrator
# Stage 5: Register Azure Local nodes with Azure Arc
# Assumes Azure session is already established by Setup-AzureConfig.ps1

$configPath = Join-Path $PSScriptRoot "..\config.ps1"
. $configPath

$Servers = 1..$NodeCount | ForEach-Object { "${ClusterName}Node$_" }

$SecuredNodePassword = ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force
$NodeCredentials = New-Object System.Management.Automation.PSCredential ("Administrator", $SecuredNodePassword)

# --- Network prerequisites on nodes ---
Write-Host "Configuring node network (single gateway, static IP)..." -ForegroundColor Cyan
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Get-NetIPConfiguration |
        Where-Object IPV4defaultGateway |
        Get-NetAdapter |
        Sort-Object Name |
        Select-Object -Skip 1 |
        Set-NetIPInterface -Dhcp Disabled

    $InterfaceAlias = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -notlike "169*" -and $_.PrefixOrigin -eq "DHCP" }).InterfaceAlias
    if ($InterfaceAlias) {
        $IPConf   = Get-NetIPConfiguration -InterfaceAlias $InterfaceAlias
        $IPAddr   = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $InterfaceAlias
        $Index    = $IPAddr.InterfaceIndex
        $DNSAddrs = @()
        $IPConf.DnsServer | ForEach-Object { if ($_.AddressFamily -eq 2) { $DNSAddrs += $_.ServerAddresses } }
        Set-NetIPInterface -InterfaceIndex $Index -Dhcp Disabled
        New-NetIPAddress -InterfaceIndex $Index -AddressFamily IPv4 `
            -IPAddress $IPAddr.IPAddress -PrefixLength $IPAddr.PrefixLength `
            -DefaultGateway $IPConf.IPv4DefaultGateway.NextHop -ErrorAction SilentlyContinue
        Set-DnsClientServerAddress -InterfaceIndex $Index -ServerAddresses $DNSAddrs
    }
} -Credential $NodeCredentials

Write-Host "Setting node administrator passwords..." -ForegroundColor Cyan
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Set-LocalUser -Name Administrator -AccountNeverExpires `
        -Password (ConvertTo-SecureString $using:LocalAdminPassword -AsPlainText -Force)
} -Credential $NodeCredentials

# --- Arc Registration ---
Write-Host "Registering nodes with Azure Arc..." -ForegroundColor Cyan
$armtoken = (Get-AzAccessToken).Token
if ($armtoken -is [System.Security.SecureString]) {
    $armtoken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($armtoken))
}
$accountId = (Get-AzContext).Account.Id

Invoke-Command -ComputerName $Servers -ScriptBlock {
    Invoke-AzStackHciArcInitialization `
        -SubscriptionID $using:AzureSubscriptionId `
        -ResourceGroup $using:ResourceGroupName `
        -TenantID $using:AzureTenantId `
        -Cloud "AzureCloud" `
        -Region $using:AzureRegion `
        -ArmAccessToken $using:armtoken `
        -AccountID $using:accountId
} -Credential $NodeCredentials

Write-Host "Arc registration complete. Nodes registered in $ResourceGroupName." -ForegroundColor Green
