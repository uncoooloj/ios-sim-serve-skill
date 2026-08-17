# Secure staging authentication for mobile automation

Use this runbook when a staging mobile session requires a username, password,
and rotating TOTP code. It keeps the Mac as the source of truth and treats
simulators and emulators as disposable clients.

## Secret boundary

- Never put credentials, TOTP seeds, recovery codes, or generated codes in a
  repository, prompt, screenshot, fixture, shell history, PR, or test report.
- Use a staging-only account with the minimum useful privileges.
- Store human-managed credentials in macOS Passwords.
- Store automation credentials only in deliberately created generic Keychain
  items. A Passwords entry is not an unattended automation API.
- Inject only the current value into the focused mobile field. Do not install a
  durable password or authenticator database in a disposable simulator.
- Stop before any financial or destructive action unless the test explicitly
  authorizes it.

## Manual Mac Passwords verification

This is the authoritative check that the human-managed Mac entry works.

1. Launch the staging app and navigate to Log in.
2. Ask the user to open the entry in macOS Passwords.
3. Ask the user to copy the username only. Do not ask them to paste it into the
   chat.
4. Transfer the host clipboard without printing it:

   ```bash
   pbpaste | xcrun simctl pbcopy <ios-simulator-udid>
   ```

   For Android, paste through the emulator's host-clipboard integration or a
   test framework's secure input API. Do not print `pbpaste` output.
5. Paste into the focused username field and clear the clipboard if required by
   local policy.
6. Repeat steps 3-5 for the password. Keep each value separate.
7. On the MFA screen, copy the verification code from Passwords and transfer it
   the same way, or use the Keychain helper below if the seed was separately
   provisioned for automation.
8. Submit once. Verify an authenticated screen from the accessibility tree or a
   redacted screenshot. Do not report credential values.

An agent that cannot access macOS Passwords must stop at steps 3 and 6 and ask
the user to perform the copy. It must not weaken Passwords permissions, scrape
the UI, or export the database.

## Automation Keychain setup

Provisioning is a one-time human action. Choose stable service/account labels;
the labels are identifiers, not secrets.

Store the TOTP seed as a generic-password item. Passing `-w` without a value
prompts securely instead of recording the seed in shell history:

```bash
security add-generic-password -U \
  -s <staging-totp-service> \
  -a <staging-account-id> \
  -w
```

The value can be either the base32 seed or this JSON shape:

```json
{"secret":"BASE32-SEED","algorithm":"SHA1","digits":6,"period":30}
```

Do not automate extraction from macOS Passwords. If fully unattended login is
required, create separate generic Keychain items for the staging username and
password, grant only the local test runner access, and have the test framework
read them through a non-logging secret adapter. This duplication is an explicit
security decision, not an automatic migration from Passwords.

## Generate and inject TOTP

The helper reads the seed from Keychain, generates the current code in memory,
and never prints either value. Prefer the direct iOS/Android destinations. If
you use the Mac clipboard, paste immediately and then replace/clear the
clipboard according to local policy.

```bash
# Validate/compile once.
swiftc scripts/keychain-totp.swift -o /tmp/keychain-totp

# Put the current code on the Mac clipboard.
/tmp/keychain-totp --service <service> --account <account> --clipboard

# Put it on an iOS Simulator clipboard.
/tmp/keychain-totp --service <service> --account <account> \
  --ios <simulator-udid>

# Type it into the currently focused Android Emulator field.
/tmp/keychain-totp --service <service> --account <account> \
  --android <adb-serial>
```

The Android mode is deliberately limited to numeric TOTP input. The current
code exists briefly in the local `adb` process arguments, but expires within
one TOTP period and is never stored on the Emulator. Use an established UI test
framework's secure-input mechanism for arbitrary passwords, because
`adb shell input text` has quoting limitations for general secrets.

## End-to-end acceptance checklist

1. Start from a logged-out staging session.
2. Use the Mac Passwords entry for one manual login.
3. Log out and repeat with the automation Keychain path.
4. Exercise the requested non-destructive staging flow on iOS.
5. Repeat the same flow on Android when the app surface exists there.
6. Record only device IDs, app version/build, timestamps, passed screens, and
   redacted screenshots. Record no credential or OTP value.
7. Delete any exported QR-code image or seed file after the Keychain item and a
   fresh login are verified. Prefer Trash first so recovery remains possible.

## Model routing and documentation maintenance

Use the cheapest model that can safely complete each step:

- A fast worker model such as Luna/Haiku class is the default for following
  this runbook, launching tools, collecting deterministic evidence, and updating
  version tables.
- Escalate to a stronger reasoning model only for new security decisions,
  ambiguous authentication failures, architecture changes, or disputed review.
- Never give a cheaper model broader secret access than the task requires.

At the start of each run, verify the commands and versions instead of trusting
the document blindly. When observed behavior changes, capture the exact version,
OS/runtime, command, and failure signature; update this runbook only after a
repeatable test. A failed or killed run is `unknown`, not a pass.
