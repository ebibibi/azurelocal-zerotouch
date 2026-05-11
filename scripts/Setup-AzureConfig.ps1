#Requires -RunAsAdministrator
# Azure Configuration Wizard
# Runs once after local infrastructure (Stages 1-4) is ready.
# Authenticates to Azure, lets the user select subscription/region,
# validates permissions, registers resource providers, and saves config.

$ErrorActionPreference = 'Stop'

$configPath = Join-Path $PSScriptRoot "..\config.ps1"
. $configPath

# --- Install Az modules ---
Write-Host "Checking Azure PowerShell modules..." -ForegroundColor Cyan
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
$requiredModules = @('Az.Accounts', 'Az.Resources')
foreach ($mod in $requiredModules) {
    if (-not (Get-InstalledModule -Name $mod -ErrorAction SilentlyContinue)) {
        Write-Host "  Installing $mod..." -ForegroundColor Gray
        Install-Module -Name $mod -Force -AllowClobber
    }
}

# --- Azure login (browser-based) ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Azure Sign-In" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "A browser window will open for Azure authentication." -ForegroundColor White
Write-Host "Sign in with an account that has Contributor + User Access Administrator" -ForegroundColor White
Write-Host "permissions on the target subscription." -ForegroundColor White
Write-Host ""

Connect-AzAccount -ErrorAction Stop

# --- Select subscription ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Select Subscription" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$subscriptions = Get-AzSubscription -ErrorAction Stop | Where-Object { $_.State -eq 'Enabled' }

if ($subscriptions.Count -eq 0) {
    Write-Error "No active Azure subscriptions found for this account."
    return
}

for ($i = 0; $i -lt $subscriptions.Count; $i++) {
    $sub = $subscriptions[$i]
    Write-Host "  [$($i + 1)] $($sub.Name)" -ForegroundColor White
    Write-Host "      ID: $($sub.Id) | Tenant: $($sub.TenantId)" -ForegroundColor Gray
}
Write-Host ""

if ($subscriptions.Count -eq 1) {
    $selectedSub = $subscriptions[0]
    Write-Host "Only one subscription available. Using: $($selectedSub.Name)" -ForegroundColor Green
} else {
    do {
        $choice = Read-Host "Select subscription (1-$($subscriptions.Count))"
        $idx = -1
        if ([int]::TryParse($choice, [ref]$idx)) { $idx-- } else { $idx = -1 }
    } while ($idx -lt 0 -or $idx -ge $subscriptions.Count)
    $selectedSub = $subscriptions[$idx]
}

Set-AzContext -Subscription $selectedSub.Id -Tenant $selectedSub.TenantId | Out-Null
Write-Host "  -> $($selectedSub.Name) ($($selectedSub.Id))" -ForegroundColor Green

$selectedSubscriptionId = $selectedSub.Id
$selectedTenantId = $selectedSub.TenantId

# --- Select region ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Select Region" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$hciProvider = Get-AzResourceProvider -ProviderNamespace Microsoft.AzureStackHCI -ErrorAction SilentlyContinue
$supportedRegions = @()
if ($hciProvider) {
    $clusterType = $hciProvider.ResourceTypes | Where-Object { $_.ResourceTypeName -eq 'clusters' }
    if ($clusterType) {
        $supportedRegions = $clusterType.Locations | Sort-Object
    }
}

if ($supportedRegions.Count -eq 0) {
    $supportedRegions = @(
        "East US", "West Europe", "Australia East", "Southeast Asia",
        "Japan East", "UK South", "Canada Central", "Central India"
    )
    Write-Host "  (Could not query Azure for supported regions, showing common ones)" -ForegroundColor Gray
}

for ($i = 0; $i -lt $supportedRegions.Count; $i++) {
    Write-Host "  [$($i + 1)] $($supportedRegions[$i])" -ForegroundColor White
}
Write-Host ""

do {
    $regionChoice = Read-Host "Select region (1-$($supportedRegions.Count))"
    $regionIdx = -1
    if ([int]::TryParse($regionChoice, [ref]$regionIdx)) { $regionIdx-- } else { $regionIdx = -1 }
} while ($regionIdx -lt 0 -or $regionIdx -ge $supportedRegions.Count)

$selectedRegionDisplay = $supportedRegions[$regionIdx]
$selectedRegion = ($selectedRegionDisplay -replace '\s', '').ToLower()
Write-Host "  -> $selectedRegionDisplay ($selectedRegion)" -ForegroundColor Green

# --- Resource Group name ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Resource Group" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$rgDefault = $ResourceGroupName
if (-not $rgDefault) { $rgDefault = "rg-azurelocal-lab" }
$rgInput = Read-Host "Resource group name (Enter for '$rgDefault')"
$selectedRG = if ($rgInput) { $rgInput } else { $rgDefault }
Write-Host "  -> $selectedRG" -ForegroundColor Green

# --- Validate permissions ---
Write-Host ""
Write-Host "Checking permissions..." -ForegroundColor Cyan

$currentUser = (Get-AzContext).Account.Id
$roleAssignments = Get-AzRoleAssignment -SignInName $currentUser -Scope "/subscriptions/$selectedSubscriptionId" -ErrorAction SilentlyContinue

$hasContributor = $roleAssignments | Where-Object {
    $_.RoleDefinitionName -in @('Contributor', 'Owner')
}
$hasUAA = $roleAssignments | Where-Object {
    $_.RoleDefinitionName -in @('User Access Administrator', 'Owner')
}

if (-not $hasContributor) {
    Write-Warning "Contributor role not found on subscription. Arc registration may fail."
    Write-Warning "Ask your admin to assign Contributor on subscription: $selectedSubscriptionId"
}
if (-not $hasUAA) {
    Write-Warning "User Access Administrator role not found. Arc node registration may fail."
    Write-Warning "Ask your admin to assign User Access Administrator on subscription: $selectedSubscriptionId"
}
if ($hasContributor -and $hasUAA) {
    Write-Host "  Permissions OK (Contributor + User Access Administrator)" -ForegroundColor Green
}

# --- Register resource providers ---
Write-Host ""
Write-Host "Registering Azure resource providers..." -ForegroundColor Cyan
$providers = @(
    "Microsoft.HybridCompute"
    "Microsoft.GuestConfiguration"
    "Microsoft.HybridConnectivity"
    "Microsoft.AzureStackHCI"
    "Microsoft.Kubernetes"
    "Microsoft.KubernetesConfiguration"
    "Microsoft.ExtendedLocation"
    "Microsoft.ResourceConnector"
    "Microsoft.HybridContainerService"
    "Microsoft.Attestation"
    "Microsoft.Storage"
    "Microsoft.Insights"
    "Microsoft.AzureArcData"
)
foreach ($p in $providers) {
    $state = (Get-AzResourceProvider -ProviderNamespace $p -ErrorAction SilentlyContinue).RegistrationState
    if ($state -ne 'Registered') {
        Write-Host "  Registering $p..." -ForegroundColor Gray
        Register-AzResourceProvider -ProviderNamespace $p -ErrorAction Stop | Out-Null
    }
}
Write-Host "  Resource providers registered." -ForegroundColor Green

# --- Create resource group ---
if (-not (Get-AzResourceGroup -Name $selectedRG -ErrorAction SilentlyContinue)) {
    Write-Host "Creating resource group: $selectedRG in $selectedRegion..." -ForegroundColor Cyan
    New-AzResourceGroup -Name $selectedRG -Location $selectedRegion | Out-Null
    Write-Host "  Resource group created." -ForegroundColor Green
} else {
    Write-Host "  Resource group '$selectedRG' already exists." -ForegroundColor Green
}

# --- Write Azure settings back to config.ps1 ---
Write-Host ""
Write-Host "Saving Azure settings to config.ps1..." -ForegroundColor Cyan

$content = Get-Content $configPath -Raw -Encoding UTF8

$replacements = @{
    'AzureSubscriptionId' = $selectedSubscriptionId
    'AzureTenantId'       = $selectedTenantId
    'AzureRegion'         = $selectedRegion
    'ResourceGroupName'   = $selectedRG
}

foreach ($key in $replacements.Keys) {
    $val = $replacements[$key]
    $pattern = "(?m)^\`$$key\s*=\s*`"[^`"]*`""
    $literal = "`$$key = `"$val`""
    $content = [regex]::Replace($content, $pattern, $literal.Replace('$', '$$'))
}

Set-Content -Path $configPath -Value $content -Force -Encoding UTF8

# Reload config so subsequent stages see the new values
. $configPath

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Azure Configuration Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Subscription: $($selectedSub.Name)" -ForegroundColor White
Write-Host "  Tenant:       $selectedTenantId" -ForegroundColor White
Write-Host "  Region:       $selectedRegion" -ForegroundColor White
Write-Host "  RG:           $selectedRG" -ForegroundColor White
Write-Host ""
