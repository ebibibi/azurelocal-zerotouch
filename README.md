# azurelocal-zerotouch

Zero-touch Azure Local deployment on nested Hyper-V using [MSLab](https://github.com/microsoft/MSLab).

## Goal

Plug in a USB, boot from it, and get a fully functional Azure Local (single-node) lab environment — **automatically**.

```
USB Boot → Windows Server 2025 auto-install → Hyper-V + MSLab + AD (all automatic)
  → One-time Azure sign-in (browser) → Arc registration + cluster deploy (automatic)
  → Ready to use from Azure Portal
```

## Deployment Flow

| Phase | What happens | User action |
|-------|-------------|-------------|
| **Phase 1** | OS install, Hyper-V, MSLab hydration, VM deploy, AD setup | None (automatic) |
| **Phase 2** | Azure sign-in, subscription/region selection, permission check | Sign in once via browser |
| **Phase 3** | Arc registration, cluster deployment | None (automatic) |

## Architecture

| Layer | Technology |
|-------|-----------|
| Physical host | Dell Precision (Intel Core Ultra 7, 64GB DDR5, 1TB NVMe) |
| Host OS | Windows Server 2025 (unattended install via `autounattend.xml`) |
| Lab framework | [MSLab](https://github.com/microsoft/MSLab) (nested Hyper-V) |
| Azure Local | Azure Stack HCI OS (single-node, ~20GB RAM) |
| Azure integration | Azure Arc + ARM template for cluster deployment |

## Why?

Microsoft's official zero-touch provisioning ([Simplified Machine Provisioning](https://learn.microsoft.com/azure/azure-local/deploy/simplified-machine-provisioning)) is limited to specific OEM hardware (Dell AX, HPE ProLiant, Lenovo ThinkAgile) and is still in preview. This project brings zero-touch deployment to **any hardware** that can run Hyper-V, using nested virtualization.

## Quick Start

### Prerequisites

- **Azure subscription** with Contributor + User Access Administrator permissions
- Two ISO files (the script guides you through downloading them):
  - Windows Server 2025 evaluation ISO — from [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2025)
  - Azure Local (Azure Stack HCI) ISO — from [Azure Portal](https://portal.azure.com/#view/Microsoft_Azure_StackHCI/HCIGetStarted.ReactView)
- USB drive (32GB+ recommended)

### Option A: Full Zero-Touch (USB Boot)

```powershell
# 1. Create bootable USB (guided — tells you where to download ISOs)
.\Create-USB.ps1 -USBDiskNumber 2

# 2. Plug USB into target machine and boot from it
# 3. Phase 1 runs automatically (OS install → Hyper-V → MSLab → AD)
# 4. When prompted, sign in to Azure via browser (one time only)
# 5. Phase 3 runs automatically (Arc → cluster deploy → done!)
```

> **Note:** Use `Get-Disk` to find your USB disk number. The script refuses to format non-USB disks.

### Option B: Run on Existing Windows Server

```powershell
# 1. Clone this repo
git clone https://github.com/ebibibi/azurelocal-zerotouch.git
cd azurelocal-zerotouch

# 2. Copy config template (Azure settings are auto-configured during deployment)
cp config.example.ps1 config.ps1

# 3. Place ISOs in C:\ISOs (or the script tells you where to download them)

# 4. Run — handles everything including Azure sign-in
.\Deploy-AzureLocal.ps1
```

## Project Structure

```
azurelocal-zerotouch/
├── README.md
├── Create-USB.ps1              # USB creation tool (guided ISO download)
├── config.example.ps1          # Config template (Azure settings auto-populated)
├── Deploy-AzureLocal.ps1       # Main orchestrator (Phase 1 → 2 → 3)
├── LabConfig.ps1               # MSLab VM definitions (single-node Azure Local)
├── scripts/
│   ├── 01-Setup-Host.ps1       # Install Hyper-V, download MSLab
│   ├── 02-Hydrate-Lab.ps1      # MSLab hydration (ISO → VHD, non-interactive)
│   ├── 03-Deploy-Lab.ps1       # MSLab deploy (create VMs)
│   ├── 04-Prepare-AD.ps1       # Active Directory prerequisites
│   ├── Setup-AzureConfig.ps1   # Azure auth wizard (subscription/region/permissions)
│   ├── 05-Register-Arc.ps1     # Azure Arc registration
│   └── 06-Deploy-Cluster.ps1   # Cluster deployment (ARM template / portal guide)
└── unattend/
    └── autounattend.xml        # Windows Server 2025 unattended install (UEFI)
```

## References

- [MSLab](https://github.com/microsoft/MSLab) — Microsoft's rapid lab deployment scripts
- [MSLab HOL: Deploying Azure Local](https://github.com/microsoft/MSLab/tree/main/HandsOnLabs/02-DeployingAzureLocal)
- [AzSHCI](https://github.com/schmittnieto/AzSHCI) — Community Azure Local lab scripts
- [Azure Local deployment docs](https://learn.microsoft.com/azure/azure-local/deploy/deployment-introduction)

## License

MIT
