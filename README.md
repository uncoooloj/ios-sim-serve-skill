# iOS Sim Serve

Run an iOS app on the iOS Simulator and expose the live Simulator in a browser with `serve-sim`.

This skill is for Codex, Claude Code, and other IDE agents that need to see and test a native iOS app without asking the user to manually inspect the macOS Simulator. It teaches the agent to run the app, start `serve-sim`, open the browser preview, and verify the real mobile UI.

## Why Use It

- Turns the iOS Simulator into a browser-accessible review surface.
- Lets agents capture proof with screenshots and browser inspection.
- Keeps mobile debugging inside the IDE loop: build, launch, view, tap, type, inspect, repeat.
- Makes it easier to collaborate on native UI because the user can open a URL instead of switching tools.
- Supports interaction through `serve-sim` commands such as `tap`, `type`, `button`, and `rotate`.

## What It Does

Use this skill when you want an agent to run a mobile app in the iOS Simulator and make it viewable through a browser or localhost.

It covers:

- `sim serve`, `sim-serve`, `serve sim`, and `npx sim serve` shorthand
- React Native, Expo, Flutter, native iOS, SwiftUI, and KMP iOS projects
- booted Simulator discovery
- app build, install, and launch
- foreground `npx serve-sim <device>` preview mode
- `npx serve-sim --detach`
- `npx serve-sim --list` verification
- preview page and raw stream URLs, commonly `3200` and `3100`
- `/stream.mjpeg` as a raw fallback/debug URL, not the first browser target
- browser-visible verification before calling the task done
- Simulator screenshots as fallback proof when the in-app browser blocks the stream

## Quick Start

The agent should follow this shape:

```bash
# 1. Confirm or choose the Simulator.
xcrun simctl list devices booted

# 2. Run the app with the project-native command.
# Examples: yarn ios, npm run ios, npx expo run:ios, flutter run -d <udid>,
# or xcodebuild + xcrun simctl install/launch for native iOS projects.

# 3. Start the serve-sim browser preview.
npx serve-sim <udid-or-device-name>

# 4. Open the printed preview URL, often:
# http://localhost:3200
```

For browser viewing, open the printed preview URL first. Do not start by opening `npx serve-sim --list` URLs or `/stream.mjpeg`; those are status and raw-stream fallback surfaces.

For background streaming instead of a foreground preview:

```bash
npx serve-sim --detach <udid-or-device-name>
npx serve-sim --list
```

## Agent Workflow

1. Identify the app framework and preferred run command from the repo.
2. Confirm the target Simulator and keep the UDID visible.
3. Build, install, and launch the app on that Simulator.
4. Start `serve-sim` in the right mode:
   - foreground preview for a browser page,
   - detached mode for a background stream.
5. Open the foreground preview URL in the IDE browser before any raw stream URL.
6. Verify the live mobile UI with a screenshot or browser inspection.
7. Report the app runner, Simulator, bundle/app identity, preview URL, any raw stream URL that was used, and proof.

## URL Modes

`serve-sim` exposes two useful surfaces:

- Preview page: usually `http://localhost:3200`, printed by foreground `npx serve-sim <device>`.
- Raw stream: usually `http://127.0.0.1:3100/stream.mjpeg`, reported by `npx serve-sim --list`.

Use the preview page when the user wants to see or test the emulator in a browser. Use the raw stream for lower-level checks, screenshots, embedding, or fallback after the preview page is unavailable or blocked.

## For IDE Agents

This skill is written for Codex, but the workflow is portable:

- Claude Code can read `SKILL.md` as an operating guide before running commands.
- Cursor, Windsurf, or other IDE agents can use the same command sequence.
- Any agent should prefer project-native app launch commands, then `serve-sim` for the browser proxy.
- The acceptance bar is the same everywhere: the real app should be running on the Simulator and visible through the browser proxy, or the agent should clearly explain which layer is blocked.

## When To Use It

Use `ios-sim-serve` for requests like:

- "Run this in sim serve so we can test it."
- "Use serve sim and open the mobile app in browser."
- "Run the app on the booted simulator then use sim server."
- "Open the iOS Simulator stream in Codex."
- "Run `npx serve-sim` for this app."

Do not use it for ordinary web dev servers, unless the task is specifically to show an iOS Simulator over localhost.

## Install

Clone the public repo, then install it under the canonical skill name:

```bash
git clone https://github.com/uncoooloj/ios-sim-serve-skill.git
mkdir -p ~/.codex/skills/ios-sim-serve
cp -R ios-sim-serve-skill/SKILL.md ios-sim-serve-skill/agents ~/.codex/skills/ios-sim-serve/
```

The repo uses the public `-skill` suffix. The installed skill name stays clean: `ios-sim-serve`.

Invoke it with:

```text
Use $ios-sim-serve to run this mobile app on the iOS Simulator and expose it in the browser.
```

## Package Shape

- Repository: `ios-sim-serve-skill`
- Skill folder: `ios-sim-serve`
- Skill name: `ios-sim-serve`

The skill is intentionally small: one `SKILL.md` workflow and Codex UI metadata in `agents/openai.yaml`.

## Files

- `SKILL.md` - the simulator serving workflow and verification checklist
- `agents/openai.yaml` - Codex UI metadata

## License

No license has been selected yet.
