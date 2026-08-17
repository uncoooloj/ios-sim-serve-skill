# serve-sim compatibility and fallback policy

Last runtime check: 2026-08-17 on iOS Simulator 26.3.

| Version | Result | Evidence |
| --- | --- | --- |
| `0.1.45` (`latest`) | Intermittent on this host | One run repeatedly logged `error encoding frame: encodingFailed`; a clean restart later produced a visibly updating browser preview |
| `0.1.39` | Browser preview works | Live Simulator visible through the preview page |

Upstream status at the last check:

- [Issue #103](https://github.com/EvanBacon/serve-sim/issues/103) reports the
  infinite-connecting regression on `0.1.40+` and identifies `0.1.39` as
  working.
- [PR #105](https://github.com/EvanBacon/serve-sim/pull/105) proposes automatic
  H.264-to-MJPEG downgrade. It was open, conflicted, and had a failing simulator
  test. Do not assume it has shipped.

## Runtime policy

1. Resolve/probe `serve-sim@latest` on every new run.
2. Observe startup for at least eight seconds, then keep monitoring logs for the
   life of the process. HTTP 200 alone is not proof that frames encode.
3. Fall back to `0.1.39` only for the known encoder signature
   `encodingFailed` / `error encoding frame`.
4. Fail visibly for every unknown startup or runtime error. A fallback must not
   hide a wrong device, occupied port, package failure, or app-launch problem.
5. Keep the working process in the foreground and report its exact version.

Use the bundled launcher:

```bash
scripts/serve-sim-safe.sh -p 3201 <simulator-udid>
```

## Updating the fallback

When npm's `latest` changes or either upstream item closes:

1. Run `npm view serve-sim version` and read the upstream release/issue state.
2. Run the new latest version against a booted Simulator and a real app.
3. Verify the browser preview visibly changes as the app changes.
4. Inspect logs for encoder failures for at least eight seconds.
5. Run the same acceptance check twice on a clean start.
6. Only then change `DEFAULT_FALLBACK_VERSION` and this table in one PR.

Agents must report evidence and uncertainty. They must not silently pin a newer
version because its process stays alive or its root URL returns HTTP 200.
