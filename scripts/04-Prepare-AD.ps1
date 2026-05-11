#Requires -RunAsAdministrator
# Stage 4: Prepare Active Directory — Create OUs and LCM user for Azure Local

$configPath = Join-Path $PSScriptRoot "..\config.ps1"
. $configPath

$SecuredLCMPassword = ConvertTo-SecureString $LCMPassword -AsPlainText -Force
$LCMCredentials = New-Object System.Management.Automation.PSCredential ($LCMUserName, $SecuredLCMPassword)

Write-Host "Creating Active Directory objects for Azure Local..." -ForegroundColor Cyan

# Install prerequisites
Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue
Install-Module AsHciADArtifactsPreCreationTool -Repository PSGallery -Force -ErrorAction SilentlyContinue
Install-WindowsFeature -Name RSAT-AD-PowerShell, GPMC -ErrorAction SilentlyContinue

# Create AD objects
New-HciAdObjectsPreCreation -AzureStackLCMUserCredential $LCMCredentials -AsHciOUName $ClusterOUName

Write-Host "AD preparation complete. OU: $ClusterOUName" -ForegroundColor Green
