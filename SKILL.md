---
name: ios-sim-serve
description: Run a mobile or iOS app on the iOS Simulator and expose the live Simulator through localhost with serve-sim. Use when the user says "sim serve", "sim-serve", "serve sim", "npx sim serve", asks to run a mobile app in a browser or localhost, asks to view/test a booted Simulator through Codex, or when a serve-sim root URL is black/404 and Codex must distinguish app launch from simulator streaming.
---

# iOS Sim Serve

## Overview

Treat "sim serve" as a two-phase mobile workflow: first run the requested app on the iOS Simulator, then expose the Simulator screen with `npx serve-sim`. Do not stop after finding a running server. When the user asks to view or test in a browser, success means the requested app is visibly rendered in that browser surface; process IDs, `200 OK`, and screenshots are only supporting evidence.

## Core Rule

Use this sequence for user requests like "run the app in sim serve", "use serve sim so we can test", or "open the mobile app in browser":

1. Launch the requested app on the booted iOS Simulator.
2. Start or reuse `serve-sim`.
3. Verify `serve-sim` with `npx serve-sim --list`.
4. Use the reported `streamUrl`, usually `http://127.0.0.1:<port>/stream.mjpeg`.
5. Open the browser surface the user asked for and verify it visually.
6. If the browser layer fails, say it failed in-browser; then prove the Simulator state separately with a screenshot or UI inspection.

## Success Criteria

Classify the result honestly:

- `Worked`: the requested app is visible in the requested browser surface, or the user only asked for a terminal-level serve status and `serve-sim --list` proves that status.
- `Partially worked`: the app is running on Simulator and `serve-sim` exposes a healthy stream, but the in-app browser cannot render it.
- `Did not work`: the app did not launch, `serve-sim` is absent or points at the wrong device, or the browser-visible flow still cannot load after a fix attempt.

Do not report "running correctly" for a browser task just because:

- `npx serve-sim --list` returns JSON,
- `curl` returns `200 OK`,
- a wrapper root page returns `200 OK`,
- a PID is alive,
- or a native Simulator screenshot proves only the Simulator side.

## Decision Tree

- If the user asks only whether Simulator serving is running, run `npx serve-sim --list` and report the PID, device, `url`, `streamUrl`, and `wsUrl`.
- If the user asks to run an app in sim serve or browser, launch the app first, then serve the Simulator.
- If `serve-sim` is already running, reuse it only after confirming it points at the intended booted device; still verify the requested app is launched.
- If the root page is `404`, blank, or black, check `/stream.mjpeg` before calling the stream broken, but still verify the browser can render a useful view.
- If the in-app browser reports `ERR_BLOCKED_BY_CLIENT`, treat that as a browser-layer problem, not an app-launch failure. Report it as partial success for browser tasks.
- If you create a wrapper/viewer page, start it successfully before navigating the browser to it, then verify the rendered browser page. A wrapper root `200 OK` is not enough.

## Workflow

### 1. Identify the target

Find the project type and its preferred runner before inventing commands:

- React Native or Expo: inspect `package.json` scripts, then prefer `yarn ios`, `npm run ios`, `npx expo run:ios`, or the repo's established script.
- Flutter: prefer `flutter run -d <udid>` or a project-local script.
- Native iOS or SwiftUI: prefer the Xcode scheme/build settings already in the repo, then install and launch with `xcrun simctl`.
- Kotlin Multiplatform with iOS target: build the iOS app target and launch the produced app bundle on the Simulator.

Use `rg --files`, `package.json`, `*.xcodeproj`, `*.xcworkspace`, `pubspec.yaml`, and existing run scripts to choose the smallest repo-native path.

### 2. Establish the Simulator

Prefer the booted Simulator. If none is booted and the user wants the task completed, boot a reasonable available iPhone Simulator rather than asking, unless the user named a specific device.

Useful checks:

```bash
xcrun simctl list devices booted
xcrun simctl list devices available
```

Keep the selected UDID visible in your working notes because `serve-sim --list` reports a device ID and stale streams can point at the wrong Simulator.

### 3. Run the app

Start any required bundler or app server first, then build/install/launch the app. For long-running servers such as Metro, keep the process running while the user needs to test and report the URL/session clearly.

Verify app launch through at least one concrete signal:

- successful `simctl launch` output,
- app container exists,
- native Simulator screenshot,
- accessibility/UI tree,
- or visible app state in the `serve-sim` stream.

Useful checks:

```bash
xcrun simctl get_app_container <udid> <bundle-id> app
xcrun simctl io <udid> screenshot /tmp/<app>-simulator.png
```

### 4. Start or reuse serve-sim

Check first:

```bash
npx serve-sim --list
```

If it is not running or it points at the wrong device, start it:

```bash
npx serve-sim --detach
npx serve-sim --list
```

Use the JSON output as the source of truth. Capture `url`, `streamUrl`, `wsUrl`, `port`, `device`, and `pid`.

### 5. Open or report the browser surface

Use `streamUrl` for visual testing. The root `url` can return `404` while the stream is healthy.

Validate the stream directly when possible with a bounded probe because MJPEG streams may stay open by design:

```bash
curl --max-time 3 -sS -D - -o /dev/null http://127.0.0.1:<port>/stream.mjpeg
```

When the user asks to see it in Codex, use the in-app Browser for the reported localhost URL. Verify the browser result with a screenshot or inspection of the rendered page, not just terminal probes. If Browser automation blocks the URL, do not keep retrying the same blocked path; provide the `streamUrl`, attach a Simulator screenshot as fallback proof, and explicitly say the in-browser view did not work.

### Optional viewer wrapper

Only build a small viewer wrapper when the raw `streamUrl` is healthy but the browser cannot render it directly. If you do:

1. Start the wrapper with the needed sandbox/network permission before opening it.
2. Verify its root HTML endpoint and its proxied stream with bounded probes.
3. Open the wrapper URL in the in-app Browser.
4. Verify a visible simulator image in the browser surface.

If any of those steps fail, keep the wrapper running only if it helps debugging, and report the browser task as not yet working.

## Failure Modes

- `npx sim-serve` is usually wrong: the npm package is `serve-sim`.
- `serve-sim` is not Metro, Expo, Flutter, Vite, or the app runner.
- A running `serve-sim` process does not prove the requested app is running.
- Root `404` is normal for detached stream mode; prefer `/stream.mjpeg`.
- A black or blocked browser tab can be a browser-layer failure even when the Simulator and stream are healthy.
- A wrapper page can fail even if the underlying `serve-sim` stream is healthy; do not send the user to a wrapper that has not successfully started.
- `curl -I` can hang or mislead on MJPEG streams; use a bounded request and treat it as diagnostics, not final proof.
- First-run system prompts, update sheets, and permission dialogs can make the stream look wrong; inspect or dismiss them and re-screenshot.

## Completion Report

End with the facts the user needs to test:

- app/framework runner used,
- Simulator device/UDID,
- app bundle ID or launch result,
- `serve-sim` `streamUrl`,
- any still-running dev servers,
- whether the requested browser surface is actually visible,
- proof used, prioritizing visible browser state; screenshots, stream `200 OK`, and PIDs are supporting evidence only.
