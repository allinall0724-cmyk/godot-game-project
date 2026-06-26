# CrazyGames readiness

What's been set up in code, and what you still have to do by hand (the steps that
need the Godot editor + a browser, which can't be automated here).

## ✅ Done in the project
- **Web-compatible renderer.** Switched from Forward+/D3D12 to the **Compatibility**
  renderer (`project.godot`), which is the only one Godot can export to the web.
- **Web export preset** (`export_presets.cfg`) → exports to `build/web/index.html`,
  with the **CrazyGames SDK v3** script injected into the page `<head>` and an
  adaptive canvas.
- **CrazyGames SDK wrapper** autoload (`scenes/web/crazygames.gd`, registered as
  `CrazyGames`). No-ops off the web. Provides `loading_stop()`, `gameplay_start()`,
  `gameplay_stop()`, `happytime()`, and `midgame_ad()` (mutes audio during ads).
- **Gameplay events wired:** `loading_stop()` once the world is ready, a browser
  **"Click to Play"** gate that provides the user gesture pointer-lock/audio need,
  `gameplay_start()` when play begins, and `happytime()` on level-up.

## ⬜ You still need to do (editor + browser)
1. **Install Web export templates:** Editor → *Manage Export Templates* → download
   for your exact Godot version (4.7).
2. **Open the project once** so it re-imports under the Compatibility renderer, then
   **playtest on desktop** and do a **LIGHTING AUDIT** — Compatibility caps lights at
   ~8 per object and is heavy with many dynamic lights. We have lots of `OmniLight3D`s
   (village torches + per-house fireplace/lamp, cave chambers, evil totems, landmark
   lights). Expect some to drop out or hurt performance; reduce/merge the clustered
   ones (especially the village) and lower ranges.
3. **Export:** Project → *Export* → **Web** preset → export to `build/web/`.
4. **Test in a browser over HTTP** (not `file://`): run a local server in `build/web`
   (e.g. `python -m http.server`) and open it. Verify:
   - "Click to Play" → pointer lock works, mouse-look works, Esc behaves.
   - The chosen character **saves and persists** across reloads.
   - Frame-rate is acceptable (watch dense forests + night swarms).
   - Browser console shows the CrazyGames SDK initialising with no errors.
5. **Add audio** — there is currently **no sound** at all. CrazyGames' quality bar
   effectively expects music + SFX (and audio must start after the first click —
   the Click-to-Play gate already gives that gesture).
6. **Consider a real loading screen.** World generation still runs synchronously in
   `_ready()` (terrain mesh, 22k grass, trees, caves, landmarks), which is a multi-
   second freeze on load in the browser. A boot/loading scene that defers generation
   would make the load look intentional instead of like a hang.
7. **Submit:** create a developer account at `developer.crazygames.com`, upload the
   `build/web` output (zipped), fill in metadata, and pass their QA review. Re-check
   their current SDK docs — the API in `crazygames.gd` follows **SDK v3** and may
   have changed.

## Notes
- **Desktop-only** right now (keyboard/mouse, no touch). CrazyGames accepts that, but
  mobile support (touch controls + UI scaling) is a separate, larger effort.
- The SDK wrapper is intentionally defensive (try/catch, web-guarded) so the desktop
  build is unchanged. Rewarded ads aren't wired to a gameplay reward yet — add a
  `CrazyGames.midgame_ad()` call (or a rewarded variant) where it fits your design.
