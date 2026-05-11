#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Orchestrates a full zero-touch Azure Local deployment on nested Hyper-V.
.DESCRIPTION
    Three-phase deployment:

    Phase 1 (automatic, no Azure auth):
      1. Host setup — Hyper-V + MSLab download
      2. MSLab hydration — ISO to VHD conversion
      3. MSLab deploy — create VMs
      4. Active Directory preparation

    Phase 2 (one-time interactive):
      Azure sign-in via browser, subscription/region selection,
      permission check, resource provider registration.

    Phase 3 (automatic, authenticated):
      5. Azure Arc registration
      6. Cluster deployment
#>

[CmdletBinding()]
param(
    [switch]$SkipHostSetup,
    [switch]$SkipHydration,
    [switch]$SkipDeploy,
    [switch]$SkipAD,
    [switch]$SkipAzureSetup,
    [switch]$SkipArc,
    [switch]$SkipCluster
)

$ErrorActionPreference = 'Stop'

# Load configuration
$configPath = Join-Path $PSScriptRoot "config.ps1"
if (-not (Test-Path $configPath)) {
    $examplePath = Join-Path $PSScriptRoot "config.example.ps1"
    if (Test-Path $examplePath) {
        Copy-Item $examplePath $configPath
        Write-Host "Created config.ps1 from template." -ForegroundColor Yellow
    } else {
        Write-Error "config.ps1 not found. Copy config.example.ps1 to config.ps1 first."
        return
    }
}
. $configPath

$scriptsDir = Join-Path $PSScriptRoot "scripts"

function Invoke-Stage {
    param([string]$Name, [string]$Script, [bool]$Skip)
    if ($Skip) {
        Write-Host "[$Name] Skipped." -ForegroundColor Yellow
        return
    }
    Write-Host "[$Name] Starting..." -ForegroundColor Cyan
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & (Join-Path $scriptsDir $Script)
    $sw.Stop()
    Write-Host "[$Name] Completed in $($sw.Elapsed.ToString('mm\:ss'))." -ForegroundColor Green
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Magenta
Write-Host "  Azure Local Zero-Touch Deployment" -ForegroundColor Magenta
Write-Host "====================================================" -ForegroundColor Magenta
Write-Host "  Cluster: $ClusterName | Nodes: $NodeCount | RAM/node: ${NodeMemoryGB}GB" -ForegroundColor White
Write-Host "====================================================" -ForegroundColor Magenta
Write-Host ""

# =====================================================================
# Phase 1: Local Infrastructure (no Azure auth needed)
# =====================================================================
Write-Host "--- Phase 1: Local Infrastructure ---" -ForegroundColor Magenta
Write-Host ""

Invoke-Stage -Name "Host Setup"  -Script "01-Setup-Host.ps1"  -Skip $SkipHostSetup
Invoke-Stage -Name "Hydration"   -Script "02-Hydrate-Lab.ps1" -Skip $SkipHydration
Invoke-Stage -Name "Deploy VMs"  -Script "03-Deploy-Lab.ps1"  -Skip $SkipDeploy
Invoke-Stage -Name "AD Prep"     -Script "04-Prepare-AD.ps1"  -Skip $SkipAD

# =====================================================================
# Phase 2: Azure Authentication & Configuration (one-time interactive)
# =====================================================================
if (-not $SkipAzureSetup) {
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "  Phase 1 Complete — Local Infrastructure Ready" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Hyper-V, MSLab VMs, and Active Directory are set up." -ForegroundColor White
    Write-Host "  Next: Azure authentication (one-time, via browser)." -ForegroundColor White
    Write-Host ""
    Write-Host "  You will need:" -ForegroundColor Yellow
    Write-Host "    - An Azure account with Contributor + User Access Administrator" -ForegroundColor White
    Write-Host "    - An Azure subscription to register Azure Arc resources" -ForegroundColor White
    Write-Host ""
    Write-Host "  Press Enter to open Azure sign-in..." -ForegroundColor Yellow
    Read-Host | Out-Null

    & (Join-Path $scriptsDir "Setup-AzureConfig.ps1")

    # Reload config after Setup-AzureConfig.ps1 updated it
    . $configPath
} else {
    Write-Host "[Azure Setup] Skipped." -ForegroundColor Yellow
    if (-not $AzureSubscriptionId) {
        Write-Error "Azure settings are empty in config.ps1. Run without -SkipAzureSetup or fill in manually."
        return
    }
}

# =====================================================================
# Phase 3: Azure Integration (automatic, authenticated)
# =====================================================================
Write-Host ""
Write-Host "--- Phase 3: Azure Integration ---" -ForegroundColor Magenta
Write-Host ""

Invoke-Stage -Name "Arc Register"   -Script "05-Register-Arc.ps1"   -Skip $SkipArc
Invoke-Stage -Name "Cluster Deploy" -Script "06-Deploy-Cluster.ps1" -Skip $SkipCluster

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Azure Local cluster '$ClusterName' is now provisioning." -ForegroundColor White
Write-Host "  Monitor: https://portal.azure.com/#view/Microsoft_Azure_StackHCI" -ForegroundColor Cyan
Write-Host ""
