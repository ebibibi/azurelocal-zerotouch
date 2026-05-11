#Requires -RunAsAdministrator
# Stage 6: Deploy Azure Local cluster via ARM template
# This stage can also be done manually via Azure Portal.

$configPath = Join-Path $PSScriptRoot "..\config.ps1"
. $configPath

Write-Host "=== Cluster Deployment ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Azure Local nodes are registered with Arc. You can now deploy the cluster." -ForegroundColor Green
Write-Host ""
Write-Host "Option A: Deploy via Azure Portal" -ForegroundColor Yellow
Write-Host "  1. Go to: https://portal.azure.com/#view/Microsoft_Azure_StackHCI" -ForegroundColor White
Write-Host "  2. Click 'Create instance'" -ForegroundColor White
Write-Host "  3. Select your Arc-registered nodes from resource group: $ResourceGroupName" -ForegroundColor White
Write-Host ""
Write-Host "Option B: Deploy via ARM template (automated)" -ForegroundColor Yellow
Write-Host "  ARM template deployment for Azure Local is coming in a future update." -ForegroundColor White
Write-Host ""

# Display recommended portal settings for reference
Write-Host "--- Recommended Portal Settings ---" -ForegroundColor Cyan
$settings = @"
Basics:
    Resource Group:   $ResourceGroupName
    Cluster Name:     $ClusterName
    Key Vault:        (generate new)

Configuration:
    New Configuration

Networking:
    Storage:          No switch for storage (single node)
    Starting IP:      $ManagementIPStart
    Ending IP:        $ManagementIPEnd
    Subnet mask:      $ManagementSubnet
    Default Gateway:  $ManagementGateway
    DNS Server:       $ManagementDNS
    RDMA Protocol:    Disabled (nested Hyper-V)
    Jumbo Frames:     1514 (nested Hyper-V)

Management:
    Domain:           corp.contoso.com
    Computer prefix:  $ClusterName
    OU:               $ClusterOUName
    Deployment user:  $LCMUserName / (see config.ps1)
    Local admin:      Administrator / (see config.ps1)

Security:
    Customized — unselect BitLocker for data volumes (saves space in lab)

Advanced:
    Create workload volumes (default)
"@
Write-Host $settings -ForegroundColor Gray
