# Android Emulator testing for agents

`serve-sim` is iOS-specific. Android has no exact first-party equivalent that
turns a local Emulator into the same localhost browser preview.

Use the smallest surface that satisfies the test:

- Android Studio Running Devices: best for a human using the IDE.
- [scrcpy](https://github.com/Genymobile/scrcpy): closest local interactive
  mirror. It gives an agent/human a low-latency desktop window, not a browser
  URL. The current official release at the last check was `v4.1`.
- ADB plus accessibility/UI automation: best for deterministic agent work and
  CI evidence.
- A managed device farm: use only when remote browser access or a real-device
  matrix is required. Keep staging credentials in the provider's secret store.

## Local deterministic path

```bash
adb devices
adb -s <serial> shell pm list packages | rg <package-prefix>
adb -s <serial> shell monkey -p <staging-package> 1
adb -s <serial> exec-out screencap -p > /tmp/android-emulator.png
```

Inspect the app's own build configuration before choosing the package ID or
launch command. Do not copy an example package blindly.

For interaction, prefer the project's existing Compose/UIAutomator, Maestro,
Appium, or other UI harness. Use coordinate taps only as a last resort because
screen size, keyboard, and system dialogs make them fragile.

For an interactive local mirror:

```bash
scrcpy --serial <serial>
```

Do not expose ADB or scrcpy over an untrusted network. A browser wrapper around
scrcpy is a separate remote-control system with its own authentication and
transport risk; it is not a drop-in `serve-sim` command.

## Evidence checklist

1. Record Emulator name/API level and ADB serial.
2. Record the installed staging package/version.
3. Exercise the requested path once with the real app.
4. Capture a redacted screenshot and accessibility/UI assertion.
5. Report any server, emulator, scrcpy, or test-runner process left running.

Use `references/secure-staging-auth.md` for Mac-sourced TOTP and credential
handling. The same host Keychain helper can type a current numeric TOTP into a
focused Android field without storing the seed on the Emulator.
