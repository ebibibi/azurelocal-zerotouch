# Azure Local Zero-Touch Lab Configuration
# Copy this file to config.ps1 before deployment.

# =============================================================================
# LOCAL SETTINGS — Edit these before deployment if needed
# =============================================================================

# --- Cluster Settings ---
$ClusterName         = "ALab01"
$ClusterOUName       = "OU=$ClusterName,DC=Corp,DC=contoso,DC=com"
$LCMUserName         = "$ClusterName-LCMUser"
$LCMPassword         = "LS1setup!LS1setup!"
$LocalAdminPassword  = "LS1setup!LS1setup!"

# --- MSLab Settings ---
$MSLabPath           = "C:\MSLab"

# --- ISO Paths ---
$WindowsServerISOPath = "C:\ISOs\WindowsServer2025.iso"
$AzureLocalISOPath    = "C:\ISOs\AzureLocal.iso"

# --- Network Settings (for Azure Local cluster) ---
$ManagementIPStart   = "10.0.0.111"
$ManagementIPEnd     = "10.0.0.116"
$ManagementSubnet    = "255.255.255.0"
$ManagementGateway   = "10.0.0.1"
$ManagementDNS       = "10.0.0.1"

# --- Node Configuration ---
$NodeCount           = 1            # Single-node deployment (set to 2 for dual-node)
$NodeMemoryGB        = 20           # RAM per node in GB
$NodeHDDCount        = 4            # Number of virtual HDDs per node
$NodeHDDSizeGB       = 1024         # Size of each virtual HDD in GB

# =============================================================================
# AZURE SETTINGS — Auto-populated by Setup-AzureConfig.ps1 during deployment
# You do NOT need to fill these in manually.
# =============================================================================
$AzureSubscriptionId = ""
$AzureTenantId       = ""
$AzureRegion         = ""
$ResourceGroupName   = "rg-azurelocal-lab"
