# Public release checklist

NuNuBar can be built locally with ad-hoc signing, but a build intended for other
Mac users must use an Apple Developer ID and Apple notarization.

Every release must use the support language in
[`VERIFIED_PATHS.md`](VERIFIED_PATHS.md). Only exact combinations listed as
verified may be presented as proven setup paths. Testing profiles and Windows
hardware gaps must stay visible on the project page and release notes.

## Create the GitHub repository

Keep the existing source repository as `upstream` and add the new public
repository as `origin`. Creating the remote repository and pushing code are
public actions and require the owner's explicit approval.

```bash
git remote rename origin upstream
git remote add origin https://github.com/OWNER/NuNuBar.git
git push -u origin HEAD:main
```

Replace `OWNER` with the actual GitHub account or organization. Preserve
`LICENSE`, `THIRD_PARTY_NOTICES.md`, bundled third-party license texts, and all
firmware source/build records. Do not upload local DMGs, signing certificates,
notary credentials, VIA backups, official recovery images, or user Hook files.

Before creating a version tag, enable GitHub Actions and configure every Apple
signing and notarization secret. Pushing `v0.13.1` starts the Release workflow.
If any required secret is absent, the workflow refuses to create a public
release. Ad-hoc `UNNOTARIZED` artifacts remain available from ordinary CI for
development testing only and are never the general-user release fallback.

## Verified public audience

The normal public release is currently for Apple Silicon macOS with either
Air65 V3 or Air96 V2 ANSI. Windows and other keyboard targets remain in source
and CI for contributors, but the Release workflow does not publish them as
normal-user downloads.

## User flow

1. Open the downloaded repository in Codex and run the read-only
   `python3 script/preflight.py --json` before choosing a route.
2. Install `NuNuBar.app` from the notarized DMG and launch it.
3. The app directly detects Air65 V3 through its official control interface.
   For an exact Air96 V2 ANSI, run the App light self-test first. If the status
   lights already respond, keep the installed firmware and skip every DFU step.
4. Only when an exact Air96 V2 ANSI has no compatible status-light response, the
   assistant asks the user to confirm ANSI, a VIA backup, and the matching
   official recovery image. The user then enters DFU manually. NuNuBar validates
   the bundled firmware hash, accepts exactly one matching STM32 DFU path, and
   requires a separate final flash confirmation before writing Internal Flash.
5. After USB reconnects, NuNuBar applies the bundled off/orange/red/green
   preset and verifies the custom Raw HID status protocol.
6. Click **Connect Codex**. NuNuBar backs up and merges `~/.codex/hooks.json`
   and enables Hooks in `~/.codex/config.toml`. The user approves the four
   `agent-light` commands in Codex Settings, returns to NuNuBar, and clicks
   **Check Again** until the App reports **Connected**.
7. Grant Input Monitoring when macOS asks. The final page can enable
   **Launch at Login** for persistent background sync.

The app bundle includes separate model-specific firmware images, `dfu-util`,
and `libusb`; the user does not need Homebrew or a terminal. After setup, Codex
events are handled locally. The app does not require a cloud service, account,
or conversation-content access.

## Build and notarize

Create a notarytool profile once:

```bash
xcrun notarytool store-credentials NuNuBar-notary \
  --apple-id you@example.com \
  --team-id TEAMID \
  --password APP_SPECIFIC_PASSWORD
```

Then package the public release:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Example (TEAMID)" \
NOTARY_PROFILE="NuNuBar-notary" \
./script/package_public_release.sh
```

The script signs `libusb`, `dfu-util`, the status helper, and the app with
hardened runtime, builds the DMG, submits it to Apple, staples the ticket, runs
Gatekeeper assessment, and prints the final SHA-256.

## Release blockers

- A Developer ID Application certificate and Apple notary credentials are
  required; the repository cannot supply them, and the public Release workflow
  fails closed when they are missing.
- The public normal-user build supports only Apple Silicon, macOS 14 or later,
  Air65 V3 official wired control, and the verified Air96 V2 ANSI v7 route.
- Air60 V2, Air75 V2, Halo75 V2, Windows, and other targets remain contributor
  assets until matching hardware validation is complete.
- Firmware remains model-specific. USB VID/PID detection does not replace the
  user's exact model/layout confirmation, recovery image, and separate final
  flash confirmation.
- Each distributed firmware binary needs a published SHA-256 and a matching
  source/build record.
- A macOS public release must be Developer ID signed and Apple notarized.
  `UNNOTARIZED` CI artifacts can support contributors and local development,
  but are never published as the preferred path for general users.
- The exact host/keyboard path must complete the success checklist before its
  status changes from testing to verified.
