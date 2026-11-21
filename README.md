# BlueStacks 5 Ad-Block & Debloater (Update-Proof PowerShell)

Remove ads, promotional banners, NowBux/store popups, and background ad helpers from **BlueStacks 5** using a single PowerShell command — with automatic path detection across any drive and update-proof auto-healing.

## One-Command Install (Run PowerShell as Administrator)

```powershell
irm https://raw.githubusercontent.com/darshanrathod27/bluestacks-5-adblock-debloater/main/install.ps1 | iex
```

### With Custom Paths (Optional)

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/darshanrathod27/bluestacks-5-adblock-debloater/main/install.ps1))) -CustomInstallPath "D:\BlueStacks_nxt" -CustomDataPath "D:\BlueStacks_Data"
```

## How It Works

- **Auto Path Detection**: Checks Registry (`BlueStacks_nxt`) and scans drives automatically so custom install paths work without manual edits.
- **Safe Config & Popup Trim**: Disables ad/store/NowBux feature flags in `bluestacks.conf` and removes promotional/exit-popup endpoints from cached API JSON while keeping Google Play Store working.
- **Android Instance Shield**: When an emulator instance (`127.0.0.1:5555`) is active, enables Private DNS (`dns.adguard-dns.com`) and disables `gg.now.ads.service`.
- **Update-Proof Auto-Heal**: Registers a logon task (`BlueStacks_AdBlock_AutoHeal`) and blocks outbound traffic only on ad/web helper binaries (`BlueStacksAppplayerWeb.exe`, `BlueStacksHelper.exe`, `BlueStacksServices.exe`).

## Rollback

```powershell
irm https://raw.githubusercontent.com/darshanrathod27/bluestacks-5-adblock-debloater/main/rollback.ps1 | iex
```

## Common User Issues & Fixes

- **Emulator fails integrity check**: Always back up `bluestacks.conf` first and avoid modifying `Root.vhd` or core hypervisor binaries.
- **ADB shows offline**: Open your BlueStacks instance first so port 5555 is listening, then re-run the script.
- **Want to remove bottom launcher game shelf too**: Install a lightweight launcher (such as Nova Launcher or Lawnchair) inside Android and set it as default home.

## License

MIT — see [LICENSE](LICENSE).
