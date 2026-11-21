[CmdletBinding()]
param([string]$InstallPath = "")
$ErrorActionPreference = "Continue"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -Wait
  exit 0
}
Unregister-ScheduledTask -TaskName "BlueStacks_AdBlock_AutoHeal" -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetFirewallRule -DisplayName "BS_AdBlock_Web","BS_AdBlock_Helper","BS_AdBlock_Services" -ErrorAction SilentlyContinue
if (-not $InstallPath) { $InstallPath = "C:\Program Files\BlueStacks_nxt" }
$adb = Join-Path $InstallPath "HD-Adb.exe"
if (Test-Path $adb) {
  & $adb connect 127.0.0.1:5555 2>&1 | Out-Null
  & $adb -s 127.0.0.1:5555 shell settings delete global private_dns_mode 2>&1 | Out-Null
  & $adb -s 127.0.0.1:5555 shell settings delete global private_dns_specifier 2>&1 | Out-Null
  & $adb -s 127.0.0.1:5555 shell pm enable gg.now.ads.service 2>&1 | Out-Null
}
Write-Output "BlueStacks Ad-Block rollback completed."
