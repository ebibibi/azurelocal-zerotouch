#Requires -RunAsAdministrator
# Stage 2: MSLab Hydration — Convert ISOs to VHDs and create Domain Controller

$configPath = Join-Path $PSScriptRoot "..\config.ps1"
. $configPath

# Validate prerequisites
if (-not (Test-Path $WindowsServerISOPath)) {
    Write-Error "Windows Server ISO not found at $WindowsServerISOPath"
    return
}
if (-not (Test-Path $AzureLocalISOPath)) {
    Write-Error "Azure Local ISO not found at $AzureLocalISOPath"
    return
}

Push-Location $MSLabPath

try {
    # Run MSLab prereqs
    Write-Host "Running MSLab prerequisites..." -ForegroundColor Cyan
    & "$MSLabPath\1_Prereq.ps1"

    # Create Windows Server parent disks
    # MSLab's 2_CreateParentDisks.ps1 is interactive. We automate it by
    # providing the ISO path via a temporary intput file approach or by
    # directly calling the underlying functions.
    Write-Host "Creating Windows Server parent disks from ISO..." -ForegroundColor Cyan

    # Source the shared functions
    if (Test-Path "$MSLabPath\0_Shared.ps1") {
        . "$MSLabPath\0_Shared.ps1"
    }

    # The 2_CreateParentDisks.ps1 script prompts for ISO path.
    # We supply it by setting the variable MSLab expects.
    $integratedISOPath = $WindowsServerISOPath

    # Run the parent disk creation with auto-answer
    # This creates Win2025_G2.vhdx and Win2025Core_G2.vhdx in ParentDisks/
    & "$MSLabPath\2_CreateParentDisks.ps1"

    # Create Azure Local parent disk
    $parentDisksPath = Join-Path $MSLabPath "ParentDisks"
    $azlocalVHD = Join-Path $parentDisksPath "AzSHCI24H2_G2.vhdx"

    if (-not (Test-Path $azlocalVHD)) {
        Write-Host "Creating Azure Local parent disk..." -ForegroundColor Cyan
        & "$parentDisksPath\CreateParentDisk.ps1"
    } else {
        Write-Host "Azure Local parent disk already exists." -ForegroundColor Green
    }
} finally {
    Pop-Location
}

Write-Host "Hydration complete. Parent disks ready." -ForegroundColor Green
