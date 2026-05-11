#Requires -RunAsAdministrator
# Stage 4: Prepare Active Directory — Create OUs and LCM user for Azure Local

$ErrorActionPreference = 'Stop'

$configPath = Join-Path $PSScriptRoot "..\config.ps1"
. $configPath

$SecuredLCMPassword = ConvertTo-SecureString $LCMPassword -AsPlainText -Force
$LCMCredentials = New-Object System.Management.Automation.PSCredential ($LCMUserName, $SecuredLCMPassword)

Write-Host "Creating Active Directory objects for Azure Local..." -ForegroundColor Cyan

Write-Host "Installing prerequisites..." -ForegroundColor Gray
Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue
Install-Module AsHciADArtifactsPreCreationTool -Repository PSGallery -Force
$featureResult = Install-WindowsFeature -Name RSAT-AD-PowerShell, GPMC
if (-not $featureResult.Success) {
    throw "Failed to install Windows features: RSAT-AD-PowerShell, GPMC"
}

New-HciAdObjectsPreCreation -AzureStackLCMUserCredential $LCMCredentials -AsHciOUName $ClusterOUName

Write-Host "AD preparation complete. OU: $ClusterOUName" -ForegroundColor Green
