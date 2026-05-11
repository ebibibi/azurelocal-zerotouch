#Requires -RunAsAdministrator
# Stage 1: Host Setup — Install Hyper-V and download MSLab

$configPath = Join-Path $PSScriptRoot "..\config.ps1"
. $configPath

# Install Hyper-V if not already installed
$hyperv = Get-WindowsFeature -Name Hyper-V -ErrorAction SilentlyContinue
if (-not $hyperv) {
    $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
}

if ($hyperv -and (-not $hyperv.Installed) -and ($hyperv.State -ne 'Enabled')) {
    Write-Host "Installing Hyper-V..." -ForegroundColor Cyan
    if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
        Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart:$false
    } else {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
    }
    Write-Warning "Hyper-V installed. A reboot is required. Re-run this script after reboot."
    return
} else {
    Write-Host "Hyper-V is already installed." -ForegroundColor Green
}

# Download MSLab
if (-not (Test-Path $MSLabPath)) {
    New-Item -Path $MSLabPath -ItemType Directory -Force | Out-Null
}

$mslabZip = Join-Path $env:TEMP "mslab.zip"
if (-not (Test-Path (Join-Path $MSLabPath "1_Prereq.ps1"))) {
    Write-Host "Downloading MSLab..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://aka.ms/mslab/download" -OutFile $mslabZip
    Expand-Archive -Path $mslabZip -DestinationPath $MSLabPath -Force
    Get-ChildItem -Path $MSLabPath | Unblock-File
    Remove-Item $mslabZip -Force
    Write-Host "MSLab downloaded to $MSLabPath" -ForegroundColor Green
} else {
    Write-Host "MSLab already present at $MSLabPath" -ForegroundColor Green
}

# Ensure execution policy allows scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force -ErrorAction SilentlyContinue

# Create ISOs directory
$isosDir = "C:\ISOs"
if (-not (Test-Path $isosDir)) {
    New-Item -Path $isosDir -ItemType Directory -Force | Out-Null
    Write-Host "Created $isosDir — place your ISO files here." -ForegroundColor Yellow
}

# Validate ISO files exist
$missingISOs = @()
if (-not (Test-Path $WindowsServerISOPath)) { $missingISOs += "Windows Server: $WindowsServerISOPath" }
if (-not (Test-Path $AzureLocalISOPath))    { $missingISOs += "Azure Local: $AzureLocalISOPath" }

if ($missingISOs.Count -gt 0) {
    Write-Warning "Missing ISO files:"
    $missingISOs | ForEach-Object { Write-Warning "  - $_" }
    Write-Warning "Download them and update config.ps1 before running Stage 2."
}

Write-Host "Host setup complete." -ForegroundColor Green
