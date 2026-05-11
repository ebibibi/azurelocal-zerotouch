# azurelocal-zerotouch

Zero-touch Azure Local deployment on nested Hyper-V using [MSLab](https://github.com/microsoft/MSLab).

## Goal

Plug in a USB, boot from it, and get a fully functional Azure Local (single-node) lab environment — **automatically**.

```
USB Boot
 → Windows Server 2025 unattended install
 → Hyper-V enabled + MSLab hydration
 → Single-node Azure Local VM deployed
 → Azure Arc registered + cluster provisioned
 → Ready to use from Azure Portal
```

## Architecture

| Layer | Technology |
|-------|-----------|
| Physical host | Dell Precision (Intel Core Ultra 7, 64GB DDR5, 1TB NVMe) |
| Host OS | Windows Server 2025 (unattended install via `unattend.xml`) |
| Lab framework | [MSLab](https://github.com/microsoft/MSLab) (nested Hyper-V) |
| Azure Local | Azure Stack HCI OS (single-node, ~20GB RAM) |
| Azure integration | Azure Arc + ARM template for cluster deployment |

## Why?

Microsoft's official zero-touch provisioning ([Simplified Machine Provisioning](https://learn.microsoft.com/azure/azure-local/deploy/simplified-machine-provisioning)) is limited to specific OEM hardware (Dell AX, HPE ProLiant, Lenovo ThinkAgile) and is still in preview. This project brings zero-touch deployment to **any hardware** that can run Hyper-V, using nested virtualization.

## Quick Start

### Prerequisites

- **Azure subscription** with permissions to register Arc resources
- Two ISO files (the script guides you through downloading them):
  - Windows Server 2025 evaluation ISO — from [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2025)
  - Azure Local (Azure Stack HCI) ISO — from [Azure Portal](https://portal.azure.com/#view/Microsoft_Azure_StackHCI/HCIGetStarted.ReactView)
- USB drive (32GB+ recommended)

### Option A: Full Zero-Touch (USB Boot)

```powershell
# Guided mode — the script tells you where to download ISOs:
.\Create-USB.ps1 -USBDiskNumber 2

# Or provide ISOs directly:
.\Create-USB.ps1 -WindowsServerISO "D:\ISOs\WinServer2025.iso" `
                 -AzureLocalISO "D:\ISOs\AzureLocal.iso" `
                 -USBDiskNumber 2 `
                 -ConfigPath ".\config.ps1"

# Then plug the USB into the target machine and boot from it.
# Everything else is automatic.
```

> **Note:** Use `Get-Disk` to find your USB disk number. The script refuses to format non-USB disks.

### Option B: Run on Existing Windows Server

```powershell
# 1. Clone this repo
git clone https://github.com/ebibibi/azurelocal-zerotouch.git
cd azurelocal-zerotouch

# 2. Edit config
# Place your ISOs and update config.ps1 with your Azure details
cp config.example.ps1 config.ps1
notepad config.ps1

# 3. Run the full deployment
.\Deploy-AzureLocal.ps1
```

## Project Structure

```
azurelocal-zerotouch/
├── README.md
├── Create-USB.ps1           # USB creation tool (FAT32 boot + NTFS data)
├── config.example.ps1       # Configuration template (Azure sub, region, etc.)
├── Deploy-AzureLocal.ps1    # Main orchestrator script
├── LabConfig.ps1            # MSLab VM definitions (single-node Azure Local)
├── scripts/
│   ├── 01-Setup-Host.ps1    # Install Hyper-V, download MSLab
│   ├── 02-Hydrate-Lab.ps1   # MSLab hydration (ISO → VHD, non-interactive)
│   ├── 03-Deploy-Lab.ps1    # MSLab deploy (create VMs)
│   ├── 04-Prepare-AD.ps1    # Active Directory prerequisites
│   ├── 05-Register-Arc.ps1  # Azure Arc registration
│   └── 06-Deploy-Cluster.ps1 # ARM template cluster deployment
└── unattend/
    └── autounattend.xml     # Windows Server 2025 unattended install (UEFI)
```

## References

- [MSLab](https://github.com/microsoft/MSLab) — Microsoft's rapid lab deployment scripts
- [MSLab HOL: Deploying Azure Local](https://github.com/microsoft/MSLab/tree/main/HandsOnLabs/02-DeployingAzureLocal)
- [AzSHCI](https://github.com/schmittnieto/AzSHCI) — Community Azure Local lab scripts
- [Azure Local deployment docs](https://learn.microsoft.com/azure/azure-local/deploy/deployment-introduction)

## License

MIT
