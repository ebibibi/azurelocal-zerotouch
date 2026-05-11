#Requires -RunAsAdministrator
# Stage 2: MSLab Hydration — Convert ISOs to VHDs and create Domain Controller
# Fully non-interactive: uses ServerISOFolder and direct Convert-WindowsImage calls.

$ErrorActionPreference = 'Stop'

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
    # --- Phase A: MSLab Prereqs ---
    Write-Host "Running MSLab prerequisites..." -ForegroundColor Cyan
    & "$MSLabPath\1_Prereq.ps1"

    # --- Phase B: Windows Server Parent Disks (non-interactive) ---
    # Set ServerISOFolder so MSLab skips the OpenFileDialog prompt.
    # Also set TelemetryLevel to skip the telemetry prompt.
    $isoDir = Split-Path $WindowsServerISOPath -Parent

    $labConfigContent = @"
`$LabConfig = @{
    DomainAdminName  = 'LabAdmin'
    AdminPassword    = 'LS1setup!'
    DCEdition        = '4'
    Internet         = `$true
    TelemetryLevel   = 'None'
    TelemetryNickName = ''
    ServerISOFolder  = '$isoDir'
    VMs              = @()
}
"@
    $labConfigContent | Set-Content -Path "$MSLabPath\LabConfig.ps1" -Force

    Write-Host "Creating Windows Server parent disks (non-interactive)..." -ForegroundColor Cyan
    & "$MSLabPath\2_CreateParentDisks.ps1"

    # --- Phase C: Azure Local Parent Disk (direct Convert-WindowsImage) ---
    $parentDisksPath = Join-Path $MSLabPath "ParentDisks"
    $azlocalVHD = Join-Path $parentDisksPath "AzSHCI24H2_G2.vhdx"

    if (Test-Path $azlocalVHD) {
        Write-Host "Azure Local parent disk already exists." -ForegroundColor Green
    } else {
        Write-Host "Creating Azure Local parent disk..." -ForegroundColor Cyan

        # Load Convert-WindowsImage function
        $convertScript = Join-Path $parentDisksPath "Convert-WindowsImage.ps1"
        if (-not (Test-Path $convertScript)) {
            $convertScript = Join-Path $MSLabPath "Tools\Convert-WindowsImage.ps1"
        }
        if (-not (Test-Path $convertScript)) {
            Invoke-WebRequest -UseBasicParsing `
                -Uri "https://raw.githubusercontent.com/microsoft/MSLab/master/Tools/Convert-WindowsImage.ps1" `
                -OutFile (Join-Path $parentDisksPath "Convert-WindowsImage.ps1")
            $convertScript = Join-Path $parentDisksPath "Convert-WindowsImage.ps1"
        }
        . $convertScript

        # Mount Azure Local ISO and find the image
        $isoMount = Mount-DiskImage -ImagePath $AzureLocalISOPath -PassThru
        $isoLetter = $null
        for ($attempt = 0; $attempt -lt 10 -and -not $isoLetter; $attempt++) {
            Start-Sleep -Seconds 1
            $isoLetter = (Get-Volume -DiskImage $isoMount).DriveLetter
        }
        if (-not $isoLetter) { throw "Failed to get drive letter for mounted Azure Local ISO." }
        $installWim = "$($isoLetter):\sources\install.wim"

        try {
            # List available editions and pick the first one
            $images = Get-WindowsImage -ImagePath $installWim
            $selectedImage = $images | Select-Object -First 1
            Write-Host "  Edition: $($selectedImage.ImageName)" -ForegroundColor Gray

            # Convert to VHDX
            Convert-WindowsImage -SourcePath $installWim `
                -Edition $selectedImage.ImageIndex `
                -VHDPath $azlocalVHD `
                -SizeBytes 127GB `
                -VHDFormat VHDX `
                -VHDType Dynamic `
                -DiskLayout UEFI
        } finally {
            $isoMount | Dismount-DiskImage
        }

        Write-Host "Azure Local parent disk created: $azlocalVHD" -ForegroundColor Green
    }

} finally {
    # Always restore our LabConfig even if earlier stages failed
    $ourLabConfig = Join-Path $PSScriptRoot "..\LabConfig.ps1"
    $ourConfig    = Join-Path $PSScriptRoot "..\config.ps1"
    Copy-Item -Path $ourLabConfig -Destination "$MSLabPath\LabConfig.ps1" -Force -ErrorAction SilentlyContinue
    Copy-Item -Path $ourConfig    -Destination "$MSLabPath\config.ps1"    -Force -ErrorAction SilentlyContinue
    Pop-Location
}

Write-Host "Hydration complete. All parent disks ready." -ForegroundColor Green
