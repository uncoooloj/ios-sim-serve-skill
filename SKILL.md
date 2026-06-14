---
name: ios-sim-serve
description: Run an iOS or mobile app on the iOS Simulator and expose the live Simulator to a browser with serve-sim. Use when the user says "sim serve", "sim-serve", "serve sim", "npx serve-sim", "npx sim serve", asks to run a mobile app in a browser or localhost, wants an IDE agent such as Codex or Claude Code to view/test a booted Simulator, or wants the Simulator proxied into a browser.
---

# iOS Sim Serve

## Overview

Use this skill to turn an iOS Simulator run into a browser-visible testing surface. The workflow is valuable for IDE agents because it lets them build and launch the real mobile app, expose the live Simulator through localhost, inspect the actual UI from the browser, capture screenshots, and keep the user inside one review surface instead of asking them to manually inspect Xcode Simulator.

The workflow has two halves:

1. Run the app on the iOS Simulator.
2. Start `serve-sim` so the Simulator is available from a browser.

When the user asks to view or test in a browser, the target state is a visible live Simulator surface in that browser.

## Core Workflow

Use this sequence for requests like "run the app in sim serve", "use serve sim so we can test", "run `npx serve-sim`", or "open the mobile app in browser":

1. Launch the requested app on the booted iOS Simulator.
2. For browser-view requests, start foreground preview mode with `npx serve-sim <udid-or-device-name>`.
3. Open the preview URL printed by the foreground command in the browser.
4. Verify the app is visible and ready for the user to test.

Browser-first rule: when the user asks to open, view, inspect, or test the Simulator in a browser, do not start by opening `--list` URLs or `/stream.mjpeg`. Run foreground preview mode and open its printed `localhost:<preview-port>` URL first. Treat `npx serve-sim --list`, raw stream ports, and `/stream.mjpeg` as inventory, status, or fallback/debug surfaces.

## Why This Helps

- Gives Codex, Claude Code, and other IDE agents a browser surface for a native iOS app.
- Lets the agent prove what is on screen with screenshots instead of describing the Simulator from terminal output.
- Keeps the app, simulator, browser, and logs in one loop for faster debugging.
- Makes mobile UI review feel closer to web UI review: open a URL, inspect what is visible, iterate.
- Supports interactive workflows through `serve-sim` commands such as `tap`, `type`, `button`, and `rotate`.

## Completion Criteria

Classify the result by what the user asked for:

- `Ready`: the app is running and visible in the requested browser surface, or the user only asked for a terminal-level `serve-sim` status and `--list` confirms it.
- `Simulator ready, browser blocked`: the app is running and `serve-sim` is healthy, but the IDE/browser layer cannot render the page. Provide the usable URL plus a Simulator screenshot.
- `Not ready`: the app did not launch, the target Simulator is unavailable, or `serve-sim` is not serving the intended device.

For browser requests, process IDs, `200 OK`, and native screenshots are supporting evidence. The primary proof is the live Simulator surface visible in the browser.

## Mode Selection

- Browser preview: use foreground preview mode with `npx serve-sim <device>`. Keep the process running and use the preview URL printed by the command, commonly `http://localhost:3200`.
- Background stream: use `npx serve-sim --detach <device>` when the user wants a long-running background stream or status check. Confirm with `npx serve-sim --list`.
- Existing stream: reuse an existing `serve-sim` process only after confirming it targets the intended booted device and the app is launched. If the user wants a browser page, still start foreground preview mode instead of opening the existing raw stream URL first.
- Direct stream: use `streamUrl`, commonly `http://127.0.0.1:3100/stream.mjpeg`, only when the user specifically needs the raw MJPEG stream or foreground preview mode is unavailable or fails.

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

For browser requests, start the browser preview surface first:

```bash
npx serve-sim <udid-or-device-name>
```

Use the URL printed by that foreground command as the first browser target. This is usually the browser-friendly preview page, commonly `http://localhost:3200`.

Use current-state checks for inventory, stale-process detection, or background streams, not as the first browser-opening source:

```bash
npx serve-sim --list
```

Start a background stream when the user wants a durable stream or status endpoint:

```bash
npx serve-sim --detach
npx serve-sim --list
```

Capture the URLs:

- Foreground preview mode prints a browser preview page, commonly `http://localhost:3200`.
- Detached/list mode reports the raw stream server, commonly `http://127.0.0.1:3100`, plus `streamUrl` at `/stream.mjpeg`.

Use `--list` JSON as the source of truth for the stream process and device. Use the foreground command output as the source of truth for the preview page URL. A healthy raw stream does not prove the browser preview is open.

### 5. Open or report the browser surface

Use the foreground preview URL for the browser page. Do this before any raw stream probe. Use `streamUrl` only for raw visual stream testing, embedding, or fallback when the preview page is unavailable.

Validate the raw stream directly only when it is relevant, with a bounded probe because MJPEG streams may stay open by design:

```bash
curl --max-time 3 -sS -D - -o /dev/null http://127.0.0.1:<port>/stream.mjpeg
```

When the user asks to see it in Codex or another IDE browser, open the preview URL first. Verify the browser result with a screenshot or inspection of the rendered page. If the browser layer blocks the preview page, then try the raw `streamUrl` as a fallback, provide both URLs, attach a Simulator screenshot as fallback proof, and say the app is ready on Simulator while the browser proxy is blocked.

### 6. Interact With The Simulator

Prefer `serve-sim`'s built-in interaction commands when the browser surface needs taps or typing:

```bash
npx serve-sim tap <x> <y>
npx serve-sim type "hello"
npx serve-sim button home
npx serve-sim rotate landscape_left
```

Check `npx serve-sim --help` or command-specific help when choosing coordinates or options. Use native helpers such as `xcrun simctl io <udid> screenshot` or accessibility/UI inspection to confirm app state when useful.

## Practical Notes

- `serve-sim` complements the app runner; it does not replace Metro, Expo, Flutter, Xcode, or the app's build/install step.
- Foreground `npx serve-sim <device>` is best for an emulator-style browser preview.
- Detached `npx serve-sim --detach` is best for a background raw stream.
- `npx serve-sim --list` is useful for device/process truth, but it is not the browser preview path.
- The raw stream endpoint and the preview page may use different ports.
- Browser tools may block direct MJPEG URLs such as `/stream.mjpeg`; the foreground preview page is the optimal first browser target.
- First-run system prompts, update sheets, and permission dialogs are part of the real mobile state. Inspect or dismiss them before handing the app over for testing.
- A custom wrapper should be a last resort. Prefer the built-in `serve-sim` preview and interaction commands.

## Completion Report

End with the facts the user needs to test:

- app/framework runner used,
- Simulator device/UDID,
- app bundle ID or launch result,
- `serve-sim` preview URL, if foreground preview mode is used,
- `serve-sim` `streamUrl`, if background/raw mode is used or already collected,
- any still-running dev servers,
- whether the requested browser surface is actually visible,
- proof used, prioritizing visible browser state and Simulator screenshots.
