# Azure Local Zero-Touch Lab Configuration
# Copy this file to config.ps1 and fill in your values.

# --- Azure Settings ---
$AzureSubscriptionId = ""          # Your Azure subscription ID
$AzureRegion         = "eastus"    # Azure region for Arc registration
$AzureTenantId       = ""          # Your Entra ID tenant ID
$ResourceGroupName   = "rg-azurelocal-lab"

# --- Cluster Settings ---
$ClusterName         = "ALab01"
$ClusterOUName       = "OU=$ClusterName,DC=Corp,DC=contoso,DC=com"
$LCMUserName         = "$ClusterName-LCMUser"
$LCMPassword         = "LS1setup!LS1setup!"
$LocalAdminPassword  = "LS1setup!LS1setup!"

# --- MSLab Settings ---
$MSLabPath           = "C:\MSLab"

# --- ISO Paths ---
# Place your ISOs in C:\ISOs or update these paths
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
