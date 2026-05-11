#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Entry point for Azure Local Zero-Touch Deployment.
.DESCRIPTION
    Guides you through the entire process:
    - Mode A: Create a bootable USB for fresh hardware
    - Mode B: Deploy directly on this Windows Server machine
    Bilingual support (English / Japanese).
.EXAMPLE
    .\Start.ps1
#>

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot

# =============================================================================
# Bilingual message table
# =============================================================================
$messages = @{
    en = @{
        LangPrompt      = "Select language / 言語を選択"
        LangOption1     = "  [1] English"
        LangOption2     = "  [2] 日本語 (Japanese)"
        LangDefault     = "Language: English"
        LangSelected    = "Language: Japanese"

        Welcome         = @"

====================================================
  Azure Local Zero-Touch Deployment
====================================================
  Deploy a fully functional Azure Local lab
  on nested Hyper-V — automatically.
====================================================

"@
        WhatYouNeed     = "What you need:"
        NeedAzure       = "  - Azure subscription (Contributor + User Access Administrator)"
        NeedISOs        = "  - Two ISO files (we'll guide you through downloading them)"
        NeedHardware    = "  - A machine with 64GB+ RAM and Hyper-V support"
        NeedUSB         = "  - A USB drive (32GB+) — only for Mode A"

        ModePrompt      = "Choose your deployment mode:"
        ModeA           = "  [A] Create bootable USB — for a bare-metal machine with no OS"
        ModeADesc       = "      Builds a USB that auto-installs Windows Server + deploys Azure Local"
        ModeB           = "  [B] Deploy on this machine — Windows Server is already installed"
        ModeBDesc       = "      Runs the deployment pipeline directly on this machine"
        ModeSelect      = "Select mode (A/B)"

        # Mode A messages
        ModeAStart      = "=== Mode A: USB Creation ==="
        ModeAStepISO    = "Step 1: Prepare ISO files"
        ModeAStepConfig = "Step 2: Review configuration"
        ModeAStepUSB    = "Step 3: Create bootable USB"
        USBListPrompt   = "Available USB drives:"
        USBNoFound      = "No USB drives found. Please insert a USB drive and try again."
        USBSelectPrompt = "Enter the disk number of the USB drive"
        USBConfirm      = "This will ERASE all data on the selected USB. Continue?"

        # Mode B messages
        ModeBStart      = "=== Mode B: Direct Deployment ==="
        ModeBStepConfig = "Step 1: Review configuration"
        ModeBStepDeploy = "Step 2: Start deployment"
        ModeBReady      = "Ready to deploy. The process will:"
        ModeBPhase1     = "  Phase 1: Install Hyper-V, download MSLab, create VMs, set up AD (automatic)"
        ModeBPhase2     = "  Phase 2: Azure sign-in via browser (one-time, interactive)"
        ModeBPhase3     = "  Phase 3: Arc registration + cluster deployment (automatic)"
        ModeBConfirm    = "Start deployment? (yes/no)"

        # Config
        ConfigCreated   = "Created config.ps1 from template. Review settings:"
        ConfigExists    = "Config file found. Current settings:"
        ConfigEditPrompt = "Edit config.ps1 now? (yes/no — press Enter to skip)"
        ConfigOpening   = "Opening config.ps1 in notepad. Save and close when done."

        # Common
        PressEnter      = "Press Enter to continue..."
        Aborted         = "Aborted."
        InvalidChoice   = "Invalid choice. Please try again."
        Done            = "Done!"
    }
    ja = @{
        LangPrompt      = "Select language / 言語を選択"
        LangOption1     = "  [1] English"
        LangOption2     = "  [2] 日本語 (Japanese)"
        LangDefault     = "言語: English"
        LangSelected    = "言語: 日本語"

        Welcome         = @"

====================================================
  Azure Local ゼロタッチ デプロイ
====================================================
  Azure Local ラボ環境を Nested Hyper-V 上に
  全自動で構築します。
====================================================

"@
        WhatYouNeed     = "必要なもの:"
        NeedAzure       = "  - Azure サブスクリプション（共同作成者 + ユーザーアクセス管理者権限）"
        NeedISOs        = "  - ISO ファイル 2つ（ダウンロード先はスクリプトが案内します）"
        NeedHardware    = "  - 64GB 以上のメモリと Hyper-V 対応のマシン"
        NeedUSB         = "  - USB ドライブ（32GB 以上）— モード A のみ"

        ModePrompt      = "デプロイモードを選択してください:"
        ModeA           = "  [A] USB 作成 — OS未インストールのベアメタルマシン向け"
        ModeADesc       = "      Windows Server 自動インストール + Azure Local デプロイ用の USB を作成"
        ModeB           = "  [B] このマシンに直接デプロイ — Windows Server インストール済みの場合"
        ModeBDesc       = "      このマシン上で直接デプロイパイプラインを実行"
        ModeSelect      = "モードを選択 (A/B)"

        # Mode A
        ModeAStart      = "=== モード A: USB 作成 ==="
        ModeAStepISO    = "ステップ 1: ISO ファイルの準備"
        ModeAStepConfig = "ステップ 2: 設定の確認"
        ModeAStepUSB    = "ステップ 3: USB の作成"
        USBListPrompt   = "利用可能な USB ドライブ:"
        USBNoFound      = "USB ドライブが見つかりません。USB を挿入してからやり直してください。"
        USBSelectPrompt = "USB ドライブのディスク番号を入力してください"
        USBConfirm      = "選択した USB のデータはすべて消去されます。続行しますか？"

        # Mode B
        ModeBStart      = "=== モード B: 直接デプロイ ==="
        ModeBStepConfig = "ステップ 1: 設定の確認"
        ModeBStepDeploy = "ステップ 2: デプロイ開始"
        ModeBReady      = "デプロイの準備ができました。以下の処理を実行します:"
        ModeBPhase1     = "  Phase 1: Hyper-V インストール、MSLab ダウンロード、VM 作成、AD 構成（自動）"
        ModeBPhase2     = "  Phase 2: ブラウザで Azure にサインイン（1回だけ、対話式）"
        ModeBPhase3     = "  Phase 3: Arc 登録 + クラスター展開（自動）"
        ModeBConfirm    = "デプロイを開始しますか？ (yes/no)"

        # Config
        ConfigCreated   = "テンプレートから config.ps1 を作成しました。設定内容:"
        ConfigExists    = "config.ps1 が見つかりました。現在の設定:"
        ConfigEditPrompt = "config.ps1 を編集しますか？ (yes/no — Enter でスキップ)"
        ConfigOpening   = "config.ps1 を notepad で開きます。編集後、保存して閉じてください。"

        # Common
        PressEnter      = "Enter キーを押して続行..."
        Aborted         = "中止しました。"
        InvalidChoice   = "無効な選択です。もう一度入力してください。"
        Done            = "完了！"
    }
}

# =============================================================================
# Language selection
# =============================================================================
$systemLang = (Get-Culture).TwoLetterISOLanguageName
$lang = if ($systemLang -eq 'ja') { 'ja' } else { 'en' }

Write-Host ""
Write-Host $messages.en.LangPrompt -ForegroundColor Cyan
Write-Host $messages.en.LangOption1
Write-Host $messages.en.LangOption2
Write-Host ""
$langChoice = Read-Host "(1/2, default=$( if ($lang -eq 'ja') { '2' } else { '1' } ))"

if ($langChoice -eq '2') { $lang = 'ja' }
elseif ($langChoice -eq '1') { $lang = 'en' }

$m = $messages[$lang]

# =============================================================================
# Welcome
# =============================================================================
Write-Host $m.Welcome -ForegroundColor Magenta
Write-Host $m.WhatYouNeed -ForegroundColor Yellow
Write-Host $m.NeedAzure
Write-Host $m.NeedISOs
Write-Host $m.NeedHardware
Write-Host $m.NeedUSB
Write-Host ""

# =============================================================================
# Mode selection
# =============================================================================
Write-Host $m.ModePrompt -ForegroundColor Cyan
Write-Host ""
Write-Host $m.ModeA -ForegroundColor White
Write-Host $m.ModeADesc -ForegroundColor Gray
Write-Host ""
Write-Host $m.ModeB -ForegroundColor White
Write-Host $m.ModeBDesc -ForegroundColor Gray
Write-Host ""

do {
    $mode = (Read-Host $m.ModeSelect).ToUpper()
} while ($mode -ne 'A' -and $mode -ne 'B')

# =============================================================================
# Config setup (common to both modes)
# =============================================================================
function Initialize-Config {
    param([hashtable]$Msg)

    $configPath = Join-Path $repoRoot "config.ps1"
    $examplePath = Join-Path $repoRoot "config.example.ps1"

    if (-not (Test-Path $configPath)) {
        if (Test-Path $examplePath) {
            Copy-Item $examplePath $configPath
            Write-Host ""
            Write-Host $Msg.ConfigCreated -ForegroundColor Yellow
        } else {
            throw "config.example.ps1 not found in $repoRoot"
        }
    } else {
        Write-Host ""
        Write-Host $Msg.ConfigExists -ForegroundColor Green
    }

    # Show key settings
    . $configPath
    Write-Host "  ClusterName:    $ClusterName" -ForegroundColor Gray
    Write-Host "  NodeCount:      $NodeCount" -ForegroundColor Gray
    Write-Host "  NodeMemoryGB:   $NodeMemoryGB" -ForegroundColor Gray
    Write-Host "  MSLabPath:      $MSLabPath" -ForegroundColor Gray
    Write-Host ""

    $editChoice = Read-Host $Msg.ConfigEditPrompt
    if ($editChoice -eq 'yes') {
        Write-Host $Msg.ConfigOpening -ForegroundColor Cyan
        Start-Process notepad.exe -ArgumentList $configPath -Wait
        Write-Host ""
    }
}

# =============================================================================
# Mode A: USB Creation
# =============================================================================
if ($mode -eq 'A') {
    Write-Host ""
    Write-Host $m.ModeAStart -ForegroundColor Magenta
    Write-Host ""

    # Step 1: Config
    Write-Host $m.ModeAStepConfig -ForegroundColor Cyan
    Initialize-Config -Msg $m

    # Step 2: USB selection
    Write-Host $m.ModeAStepUSB -ForegroundColor Cyan
    Write-Host ""
    Write-Host $m.USBListPrompt -ForegroundColor Yellow

    $usbDisks = Get-Disk | Where-Object { $_.BusType -eq 'USB' }
    if (-not $usbDisks) {
        Write-Error $m.USBNoFound
        return
    }

    $usbDisks | Format-Table Number, FriendlyName, @{
        Name = 'Size (GB)'; Expression = { [math]::Round($_.Size / 1GB, 1) }
    } -AutoSize

    $diskNum = -1
    do {
        $input = Read-Host $m.USBSelectPrompt
        if (-not [int]::TryParse($input, [ref]$diskNum)) { $diskNum = -1 }
    } while ($diskNum -lt 0 -or ($usbDisks.Number -notcontains $diskNum))

    Write-Host ""

    # Launch Create-USB.ps1
    & (Join-Path $repoRoot "Create-USB.ps1") -USBDiskNumber $diskNum
}

# =============================================================================
# Mode B: Direct Deployment
# =============================================================================
if ($mode -eq 'B') {
    Write-Host ""
    Write-Host $m.ModeBStart -ForegroundColor Magenta
    Write-Host ""

    # Step 1: Config
    Write-Host $m.ModeBStepConfig -ForegroundColor Cyan
    Initialize-Config -Msg $m

    # Step 2: Deploy
    Write-Host $m.ModeBStepDeploy -ForegroundColor Cyan
    Write-Host ""
    Write-Host $m.ModeBReady -ForegroundColor Yellow
    Write-Host $m.ModeBPhase1
    Write-Host $m.ModeBPhase2
    Write-Host $m.ModeBPhase3
    Write-Host ""

    $confirm = Read-Host $m.ModeBConfirm
    if ($confirm -ne 'yes') {
        Write-Host $m.Aborted -ForegroundColor Yellow
        return
    }

    Write-Host ""

    # Launch Deploy-AzureLocal.ps1
    & (Join-Path $repoRoot "Deploy-AzureLocal.ps1")
}
