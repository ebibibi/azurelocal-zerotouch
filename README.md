# azurelocal-zerotouch

Zero-touch Azure Local deployment on nested Hyper-V using [MSLab](https://github.com/microsoft/MSLab).

> **日本語対応**: `Start.ps1` は日本語と英語の両方に対応しています。起動時に言語を選択できます。

## Getting Started

**3 commands. That's all you need.**

```powershell
git clone https://github.com/ebibibi/azurelocal-zerotouch.git
cd azurelocal-zerotouch
.\Start.ps1
```

`Start.ps1` guides you through everything:

1. **Language selection** — English or Japanese (auto-detected from your system)
2. **Mode selection** — USB creation (Mode A) or direct deployment (Mode B)
3. **Configuration** — creates `config.ps1` from the template, lets you review and edit
4. **ISO download guidance** — shows you exactly where to download each ISO and where to save it
5. **Execution** — creates the USB or runs the full deployment pipeline

You don't need to read this entire README to get started. Just run `Start.ps1` and follow the prompts.

### Prerequisites

| Requirement | Details |
|------------|---------|
| **Azure subscription** | With Contributor + User Access Administrator permissions |
| **ISO files (2)** | `Start.ps1` tells you where to download them — no need to find them yourself |
| **Hardware** | 64GB+ RAM, Hyper-V capable (VT-x/VT-d enabled in BIOS) |
| **USB drive** | 32GB+ — only needed for Mode A |

### Two Modes

| Mode | When to use | What you do |
|------|------------|-------------|
| **A) USB Creation** | You have a bare-metal machine with no OS | Run `Start.ps1` on any Windows PC → create USB → plug into target → boot → done |
| **B) Direct Deploy** | Windows Server 2025 is already installed | Run `Start.ps1` on the target machine → deployment runs directly |

### What Happens After You Start

```
Mode A: Start.ps1 → Create USB → Boot target machine from USB
Mode B: Start.ps1 → Deploy directly
                          ↓
         ┌─────────────────────────────────────────┐
         │  Phase 1 (automatic — no Azure needed)  │
         │  Hyper-V install → MSLab download →     │
         │  VHD creation → VM deploy → AD setup    │
         └──────────────────┬──────────────────────┘
                            ↓
         ┌─────────────────────────────────────────┐
         │  Phase 2 (one-time interaction)         │
         │  Browser opens → sign in to Azure →     │
         │  select subscription/region → done      │
         └──────────────────┬──────────────────────┘
                            ↓
         ┌─────────────────────────────────────────┐
         │  Phase 3 (automatic — Azure auth done)  │
         │  Arc registration → cluster deployment  │
         │  → ready to manage from Azure Portal    │
         └─────────────────────────────────────────┘
```

## Why This Project?

Microsoft's official zero-touch provisioning ([Simplified Machine Provisioning](https://learn.microsoft.com/azure/azure-local/deploy/simplified-machine-provisioning)) is limited to specific OEM hardware (Dell AX, HPE ProLiant, Lenovo ThinkAgile) and is still in preview. This project brings zero-touch deployment to **any hardware** that can run Hyper-V, using nested virtualization.

## Architecture

| Layer | Technology |
|-------|-----------|
| Physical host | Any machine with 64GB+ RAM and Hyper-V support |
| Host OS | Windows Server 2025 (unattended install via `autounattend.xml`) |
| Lab framework | [MSLab](https://github.com/microsoft/MSLab) (nested Hyper-V) |
| Azure Local | Azure Stack HCI OS (single-node, ~20GB RAM) |
| Azure integration | Azure Arc + ARM template for cluster deployment |

## Project Structure

```
azurelocal-zerotouch/
├── README.md
├── Start.ps1                   # Entry point — run this first (bilingual guide)
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
