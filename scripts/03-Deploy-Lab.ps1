#Requires -RunAsAdministrator
# Stage 3: Deploy Lab — Create VMs from MSLab LabConfig

$configPath = Join-Path $PSScriptRoot "..\config.ps1"
. $configPath

# Copy LabConfig to MSLab directory
$labConfigSrc  = Join-Path $PSScriptRoot "..\LabConfig.ps1"
$labConfigDest = Join-Path $MSLabPath "LabConfig.ps1"

Write-Host "Copying LabConfig.ps1 to MSLab directory..." -ForegroundColor Cyan
Copy-Item -Path $labConfigSrc -Destination $labConfigDest -Force

# Also copy config.ps1 so LabConfig.ps1 can load it
Copy-Item -Path $configPath -Destination (Join-Path $MSLabPath "config.ps1") -Force

Push-Location $MSLabPath

try {
    # Disable time synchronization for Azure Local nodes (required for nested Hyper-V)
    Write-Host "Deploying lab VMs..." -ForegroundColor Cyan
    & "$MSLabPath\Deploy.ps1"

    # Post-deploy: disable time sync on Azure Local nodes
    $nodeVMs = Get-VM -Name "${ClusterName}Node*" -ErrorAction SilentlyContinue
    if ($nodeVMs) {
        Write-Host "Disabling Hyper-V time sync on Azure Local nodes..." -ForegroundColor Cyan
        $nodeVMs | Disable-VMIntegrationService -Name "Time Synchronization"
    }
} finally {
    Pop-Location
}

Write-Host "Lab VMs deployed successfully." -ForegroundColor Green
Get-VM | Format-Table Name, State, MemoryAssigned, ProcessorCount -AutoSize
