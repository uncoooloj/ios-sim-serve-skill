# iOS Sim Serve

This skill fixes a small but costly workflow confusion: "sim serve" is not the app runner.

It teaches Codex to treat simulator serving as a two-phase mobile workflow:

1. Run the requested app on the iOS Simulator.
2. Expose the live Simulator through localhost with `npx serve-sim`.

The important part is the order and the acceptance bar. A running `serve-sim` process does not mean the app is running, and a `200 OK` stream does not mean the browser view worked. The skill makes Codex prove the browser-visible result when that is what the user asked for.

## What It Does

Use this skill when you want Codex to run a mobile app in the iOS Simulator and make it viewable through a browser or localhost.

It covers:

- `sim serve`, `sim-serve`, `serve sim`, and `npx sim serve` shorthand
- React Native, Expo, Flutter, native iOS, SwiftUI, and KMP iOS projects
- booted Simulator discovery
- app build, install, and launch
- foreground `npx serve-sim <device>` preview mode
- `npx serve-sim --detach`
- `npx serve-sim --list` verification
- preview page versus raw stream port confusion, commonly `3200` versus `3100`
- root URL `404` and black browser tab confusion
- `/stream.mjpeg` as the useful visual testing URL
- bounded stream probes for MJPEG endpoints
- browser-visible verification before calling the task done
- Simulator screenshots as fallback proof when the in-app browser blocks the stream

## When To Use It

Use `ios-sim-serve` for requests like:

- "Run this in sim serve so we can test it."
- "Use serve sim and open the mobile app in browser."
- "Run the app on the booted simulator then use sim server."
- "Why is the sim server black?"
- "Open the iOS Simulator stream in Codex."

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

- `SKILL.md` - the simulator serving workflow and failure-mode checklist
- `agents/openai.yaml` - Codex UI metadata

## License

No license has been selected yet.
