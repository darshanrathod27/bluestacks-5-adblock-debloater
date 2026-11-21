<#
.SYNOPSIS
  Universal 1-command BlueStacks 5 Ad-Blocker, Debloater & Update-Proof Auto-Heal Guard.
.DESCRIPTION
  Auto-detects BlueStacks 5 install path and ProgramData path across any drive (C:, D:, E:, etc.),
  backs up bluestacks.conf, disables ad/promo/NowBux flags, strips known exit-popup endpoints
  from local cached API JSON, blocks ad/web helper binaries in Windows Firewall, disables
  gg.now.ads.service and sets Private DNS over ADB when an emulator instance is running,
  and installs a logon auto-heal guard that survives BlueStacks updates.
#>
[CmdletBinding()]
param(
  [string]$CustomInstallPath = "",
  [string]$CustomDataPath = ""
)

$ErrorActionPreference = "Continue"

function Get-BlueStacksPaths {
  param([string]$InstOverride, [string]$DataOverride)

  $instDir = $InstOverride
  $dataDir = $DataOverride

  if (-not $instDir) {
    $regCandidates = @(
      "HKLM:\SOFTWARE\BlueStacks_nxt",
      "HKLM:\SOFTWARE\WOW6432Node\BlueStacks_nxt"
    )
    foreach ($rp in $regCandidates) {
      if (Test-Path $rp) {
        $props = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
        foreach ($propName in @("InstallDir", "InstallPath", "Path")) {
          if ($props.$propName -and (Test-Path (Join-Path $props.$propName "HD-Player.exe"))) {
            $instDir = $props.$propName
            break
          }
        }
      }
      if ($instDir) { break }
    }
  }

  if (-not $instDir) {
    foreach ($drv in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 })) {
      foreach ($sub in @("Program Files\BlueStacks_nxt", "Program Files (x86)\BlueStacks_nxt", "BlueStacks_nxt")) {
        $cand = Join-Path "$($drv.Root)" $sub
        if (Test-Path (Join-Path $cand "HD-Player.exe")) {
          $instDir = $cand
          break
        }
      }
      if ($instDir) { break }
    }
  }

  if (-not $dataDir) {
    foreach ($drv in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 })) {
      foreach ($sub in @("ProgramData\BlueStacks_nxt", "BlueStacks_nxt_Data")) {
        $cand = Join-Path "$($drv.Root)" $sub
        if (Test-Path (Join-Path $cand "bluestacks.conf")) {
          $dataDir = $cand
          break
        }
      }
      if ($dataDir) { break }
    }
  }

  [PSCustomObject]@{
    InstallDir = $instDir
    DataDir    = $dataDir
  }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
  if ($CustomInstallPath) { $argList += @("-CustomInstallPath", "`"$CustomInstallPath`"") }
  if ($CustomDataPath)    { $argList += @("-CustomDataPath", "`"$CustomDataPath`"") }
  Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait
  exit 0
}

$paths = Get-BlueStacksPaths -InstOverride $CustomInstallPath -DataOverride $CustomDataPath
if (-not $paths.InstallDir -or -not $paths.DataDir) {
  Write-Warning "BlueStacks_nxt paths not auto-detected. Pass -CustomInstallPath and -CustomDataPath."
  exit 1
}

Write-Output "Detected InstallDir : $($paths.InstallDir)"
Write-Output "Detected DataDir    : $($paths.DataDir)"

$guardDir = Join-Path $env:ProgramData "BlueStacks_AdBlock_Guard"
$bakDir   = Join-Path $guardDir ("backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $bakDir -Force | Out-Null

$confFile = Join-Path $paths.DataDir "bluestacks.conf"
if (Test-Path $confFile) {
  Copy-Item $confFile (Join-Path $bakDir "bluestacks.conf") -Force
}

Stop-Process -Name "HD-Player","BlueStacksAppplayerWeb","BlueStacksServices","BlueStacksHelper" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$guardScript = Join-Path $guardDir "bs_guard.ps1"
$guardCode = @"
`$ErrorActionPreference = "SilentlyContinue"
`$instDir  = "$($paths.InstallDir)"
`$dataDir  = "$($paths.DataDir)"
`$confFile = Join-Path `$dataDir "bluestacks.conf"
`$cdnFile  = Join-Path `$dataDir "Engine\cdn_cached_apis.json"
`$adbExe   = Join-Path `$instDir "HD-Adb.exe"

Stop-Process -Name "BlueStacksServices","BlueStacksAppplayerWeb","BlueStacksHelper" -Force -ErrorAction SilentlyContinue
`$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
if (Get-ItemProperty -Path `$runKey -Name "electron.app.BlueStacks Services" -ErrorAction SilentlyContinue) {
  Remove-ItemProperty -Path `$runKey -Name "electron.app.BlueStacks Services" -Force
}

`$hdRunning = Get-Process -Name "HD-Player" -ErrorAction SilentlyContinue
if (-not `$hdRunning -and (Test-Path `$confFile)) {
  `$flags = @{
    "bst.enable_adb_access"                          = "1"
    "bst.enable_boot_banner"                         = "0"
    "bst.enable_programmatic_ads"                    = "0"
    "bst.launch_store_on_boot"                       = "0"
    "bst.feature.bluestacksX"                        = "0"
    "bst.feature.enable_boot_promotion_grid"         = "0"
    "bst.feature.enable_mobile_notification"         = "0"
    "bst.feature.nowbux"                             = "0"
    "bst.feature.nowgg_login_popup"                  = "0"
    "bst.feature.programmatic_ads"                   = "0"
    "bst.feature.show_gp_ads"                        = "0"
    "bst.feature.smart_downloads"                    = "0"
    "bst.instance.Pie64.split_ad_enabled"            = "0"
    "bst.instance.Pie64.enable_notifications"        = "0"
  }
  `$lines = [System.IO.File]::ReadAllLines(`$confFile)
  `$seen  = @{}
  `$updated = foreach (`$line in `$lines) {
    if (`$line -match '^([^=]+)="?(.*?)"?$') {
      `$k = `$matches[1].Trim()
      if (`$flags.ContainsKey(`$k)) {
        `$seen[`$k] = `$true
        "`$k=`"`$(`$flags[`$k])`""
        continue
      }
    }
    `$line
  }
  foreach (`$k in `$flags.Keys) {
    if (-not `$seen.ContainsKey(`$k)) { `$updated += "`$k=`"`$(`$flags[`$k])`"" }
  }
  [System.IO.File]::WriteAllLines(`$confFile, `$updated, (New-Object System.Text.UTF8Encoding `$false))

  if (Test-Path `$cdnFile) {
    try {
      `$j = Get-Content `$cdnFile -Raw | ConvertFrom-Json
      foreach (`$ep in @("/appcenter/game_center_home","/app_player/bs_exclusive_tags","/app_player_v2/get_exit_popup_mobile_apps","/app_player/get_game_onboarding_data")) {
        if (`$j.data.endpoints.PSObject.Properties[`$ep]) { `$j.data.endpoints.PSObject.Properties.Remove(`$ep) }
        if (`$j.data.query_params.PSObject.Properties[`$ep]) { `$j.data.query_params.PSObject.Properties.Remove(`$ep) }
      }
      [System.IO.File]::WriteAllText(`$cdnFile, (`$j | ConvertTo-Json -Depth 10 -Compress), (New-Object System.Text.UTF8Encoding `$false))
    } catch {}
  }
}

if (`$hdRunning -and (Test-Path `$adbExe)) {
  & `$adbExe connect 127.0.0.1:5555 2>&1 | Out-Null
  & `$adbExe -s 127.0.0.1:5555 shell settings put global private_dns_mode hostname 2>&1 | Out-Null
  & `$adbExe -s 127.0.0.1:5555 shell settings put global private_dns_specifier dns.adguard-dns.com 2>&1 | Out-Null
  & `$adbExe -s 127.0.0.1:5555 shell pm disable-user --user 0 gg.now.ads.service 2>&1 | Out-Null
}
"@
[System.IO.File]::WriteAllText($guardScript, $guardCode, (New-Object System.Text.UTF8Encoding $false))

$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$guardScript`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "BlueStacks_AdBlock_AutoHeal" -Action $action -Trigger $trigger -Force | Out-Null

$svcExe = Join-Path $env:LOCALAPPDATA "Programs\bluestacks-services\BlueStacksServices.exe"
foreach ($item in @(
  @{ Name="BS_AdBlock_Web";      Bin=(Join-Path $paths.InstallDir "BlueStacksAppplayerWeb.exe") },
  @{ Name="BS_AdBlock_Helper";   Bin=(Join-Path $paths.InstallDir "BlueStacksHelper.exe") },
  @{ Name="BS_AdBlock_Services"; Bin=$svcExe }
)) {
  Remove-NetFirewallRule -DisplayName $item.Name -ErrorAction SilentlyContinue
  if ($item.Bin -and (Test-Path $item.Bin)) {
    New-NetFirewallRule -DisplayName $item.Name -Direction Outbound -Action Block -Program $item.Bin -Profile Any | Out-Null
  }
}

& $guardScript
Write-Output "BlueStacks 5 Ad-Block & Auto-Heal Guard installed successfully."
