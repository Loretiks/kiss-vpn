# Releasing Kiss VPN

End-to-end checklist for cutting a new public release with working auto-update.

## One-time setup

1. **Create the public release repo** on GitHub: `Loretiks/kiss-vpn`
   (`Settings → General → Visibility → Public`). The app code/panel can
   stay in your existing private repo — this one is just for binary
   releases that the in-app updater pulls from.
2. (Optional) Add a small `README.md` at the repo root explaining what
   the repo is and pointing users at https://kissmain.ru.

## Per-release steps

### 1. Bump the version

Both files must agree, otherwise the in-app updater won't recognise
that a newer build is available:

| File | Field |
|---|---|
| `kiss_vpn/pubspec.yaml` | `version: X.Y.Z+N` (N = monotonic build number) |
| `installer/kiss_vpn.iss` | `#define MyAppVersion "X.Y.Z"` |
| `kiss_vpn_helper/KissVPN.Helper.csproj` | `<Version>` and `<FileVersion>` (optional but tidy) |

### 2. Build the installer

```powershell
# From repo root
powershell -ExecutionPolicy Bypass -File scripts\build.ps1
```

Produces:

* `dist\Release\` — loose tree (sanity-check, don't ship)
* `dist\installer\KissVPN-Setup-X.Y.Z.exe` — the file to upload

> Requires **Inno Setup 6** in `C:\Program Files (x86)\Inno Setup 6`.
> Without it, the script still builds the loose tree but skips installer
> packaging. Install Inno Setup once:
> `winget install JRSoftware.InnoSetup`.

### 3. Update release notes

Edit `RELEASE_NOTES.md` with what changed since the previous tag. Keep
the first line short — the in-app update card shows it as a one-liner
preview under the "Доступна версия X.Y.Z" banner.

### 4. Tag + push

```powershell
git tag vX.Y.Z
git push origin vX.Y.Z
```

### 5. Create the GitHub release

```powershell
gh release create vX.Y.Z `
  --repo Loretiks/kiss-vpn `
  --title "Kiss VPN X.Y.Z" `
  --notes-file RELEASE_NOTES.md `
  dist\installer\KissVPN-Setup-X.Y.Z.exe
```

The installer file **must** be named `KissVPN-Setup-X.Y.Z.exe` — the
updater looks for `kissvpn-setup-*.exe` (case-insensitive). Tag must be
parseable as `X.Y.Z` with optional `v` prefix.

### 6. Verify auto-update fires

On a machine running the previous version:

* Open Kiss VPN → Settings → Обновления
* Click `Проверить обновления`
* Card should switch to `Доступна версия X.Y.Z`
* Click `Скачать` → progress bar → `Установить и перезапустить`
* Installer runs silently, app restarts on new version

The startup silent check fires ~2 s after launch, then every 6 hours
while the app is open — so most users get notified without any action.

## Updater architecture

* `lib/core/updater/github_updater.dart` — talks to
  `https://api.github.com/repos/Loretiks/kiss-vpn/releases/latest`,
  compares semver, finds matching installer asset, downloads it.
* `lib/core/updater/update_controller.dart` — Riverpod state machine
  (idle → checking → available → downloading → ready → installing).
* `lib/features/settings/update_card.dart` — UI card embedded in
  Settings showing current phase + actions.
* `lib/app/app.dart` — kicks off `checkSilent()` 2 s after launch and
  every 6 hours.

To repoint the updater at a different repo, change the constructor
defaults in `GithubUpdater`.
