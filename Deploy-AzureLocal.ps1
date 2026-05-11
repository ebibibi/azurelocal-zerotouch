#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Orchestrates a full zero-touch Azure Local deployment on nested Hyper-V.
.DESCRIPTION
    Runs all deployment stages in sequence:
    1. Host setup (Hyper-V, MSLab download)
    2. MSLab hydration (ISO to VHD conversion)
    3. MSLab deploy (create VMs)
    4. Active Directory preparation
    5. Azure Arc registration
    6. Cluster deployment via ARM template
#>

[CmdletBinding()]
param(
    [switch]$SkipHostSetup,
    [switch]$SkipHydration,
    [switch]$SkipDeploy,
    [switch]$SkipAD,
    [switch]$SkipArc,
    [switch]$SkipCluster
)

$ErrorActionPreference = 'Stop'

# Load configuration
$configPath = Join-Path $PSScriptRoot "config.ps1"
if (-not (Test-Path $configPath)) {
    Write-Error "config.ps1 not found. Copy config.example.ps1 to config.ps1 and fill in your values."
    return
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

Write-Host "=== Azure Local Zero-Touch Deployment ===" -ForegroundColor Magenta
Write-Host "Cluster: $ClusterName | Nodes: $NodeCount | RAM/node: ${NodeMemoryGB}GB" -ForegroundColor Magenta
Write-Host ""

Invoke-Stage -Name "Host Setup"     -Script "01-Setup-Host.ps1"     -Skip $SkipHostSetup
Invoke-Stage -Name "Hydration"      -Script "02-Hydrate-Lab.ps1"    -Skip $SkipHydration
Invoke-Stage -Name "Deploy VMs"     -Script "03-Deploy-Lab.ps1"     -Skip $SkipDeploy
Invoke-Stage -Name "AD Prep"        -Script "04-Prepare-AD.ps1"     -Skip $SkipAD
Invoke-Stage -Name "Arc Register"   -Script "05-Register-Arc.ps1"   -Skip $SkipArc
Invoke-Stage -Name "Cluster Deploy" -Script "06-Deploy-Cluster.ps1" -Skip $SkipCluster

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host "Azure Local cluster '$ClusterName' is now provisioning." -ForegroundColor Green
Write-Host "Monitor progress at: https://portal.azure.com/#view/Microsoft_Azure_StackHCI" -ForegroundColor Cyan
