# Handoff: rebuilding Fourfold in Godot (isometric)

Status: **planning settled, nothing built yet.** This is the starting brief for a new session. Read it together with [`DESIGN.md`](../DESIGN.md), which is still the source of truth for the game's rules.

## 1. Goal

Rebuild Fourfold as a real game in the **Godot engine**, moving from the browser belt-scroller to an **isometric** view. The TypeScript version was a prototype of the concept. Gameplay does **not** need to match it exactly: use it as a reference, not a spec to copy line by line.

Build **gameplay first with grey-box shapes** (capsules, boxes) until movement and combat feel fluid. Art, voice and polish come after.

## 2. Settled decisions

| Area | Decision |
|---|---|
| Engine | Godot 4 (latest stable; check godotengine.org, use the same version locally and in CI) |
| Language | **GDScript only.** C# cannot export to the web. |
| View | Full 3D with a fixed isometric camera: `Camera3D`, orthographic, about 45° down from a corner. Not 2D isometric sprites. |
| Renderer | **Compatibility** (WebGL 2), so the web export works. Keep lighting simple. |
| Web | Single-threaded web export (the default since Godot 4.3). It runs on plain GitHub Pages with no special headers. Web is the goal, but desktop-only is acceptable if web becomes blocking. |
| Tests | GUT (Godot Unit Test), run headless: `godot --headless ...` |
| Branch | `godot-rebuild`, branched from `main` |
| Location | The Godot project lives in **`game/`**. The TypeScript app stays untouched at the root as a reference and keeps deploying from `main`. |
| Voice | **Kokoro** (local, open-source text-to-speech; check the license on the hexgrad/Kokoro-82M model card) to start. Swap in ElevenLabs files later under the same filenames. |
| Art (later) | Tripo (AI 3D models) → Blender (cleanup, zone building, scriptable with Python) → Mixamo (rigging and animation for humanoids) → Godot. Pick one stylised low-poly style reference and use it for every generation. |
| Audio (later) | The existing synthesised music and effects in `src/ui/audio.ts` are worth recreating or rendering to files. Add free (CC0) libraries as needed. |

## 3. Architecture rule

Keep **rules and AI separate from scene nodes**.

- **Pure GDScript classes** (no scene dependencies): hero and enemy data, the combat rules (global cooldown, casts, auras, threat, interrupts, dispels, level scaling), and AI decisions. These can be unit-tested headless.
- **Nodes** (`CharacterBody3D` units, camera, HUD) ask the rules what is allowed and react to the events they emit. Mirror the existing `SimEvent` kinds: `hit`, `heal`, `death`, `interrupt`, `dispel`, and so on.
- The engine replaces `src/sim/map.ts`: `NavigationRegion3D` / `NavigationAgent3D` for pathfinding, physics raycasts for line of sight, and pillars as real collision objects that can be destroyed.
- The tick is fixed at 60 Hz, which already matches `DT = 1/60` in `src/sim/world.ts`. Use `_physics_process`.
- Map coordinates: the TypeScript floor `{x, y}` becomes Godot's ground plane `x, z`.
- **Bring back the all-AI balance runner** (the equivalent of `npm run sim`) as a headless Godot script. It is the main regression check for long unattended runs.

### Where the TypeScript code goes

| TypeScript | Godot |
|---|---|
| `src/sim/heroes.ts`, `enemies.ts`, `dungeon.ts` (data) | Ported as GDScript data or `Resource` files |
| `src/sim/world.ts` (rules) | Pure rule classes plus a run controller |
| `src/sim/heroAI.ts`, `enemyAI.ts` | AI decision classes; movement goes through the navigation agent |
| `src/sim/map.ts` | Replaced by navigation meshes, collision and raycasts |
| `src/ui/*` (drawing, HUD, audio) | Replaced by scenes, the camera, Control-node UI and audio files |
| `src/ui/story.ts` | Source text for the voice-line manifest |

## 4. Controls change for isometric

`DESIGN.md` §3 is written for the belt-scroller. Update it as part of milestone 1:

- WASD moves relative to the camera. The "W towards the back wall" rule goes away.
- Mouse targeting uses a ray from the camera into the scene.
- Keep: Tab targeting, the 1–6 abilities, rebindable keys and mouse buttons, healer click-to-cast on party frames, Esc and P.
- Jump is optional and cosmetic. Drop it if it doesn't fit.

## 5. Milestones (each one ends playable or verifiable)

0. **Pipeline.** Install Godot locally (`brew install --cask godot`; not installed at the time of writing). Create `game/` with `project.godot` (Compatibility renderer), add GUT and one passing headless test. Add a web export preset and a GitHub Actions workflow that runs the tests and exports Web headless, using the same Godot version as local. **Pages note:** a repo has one Pages site, and `main` currently deploys the TypeScript build. On the branch, upload the web export as a workflow artifact only. Decide at merge time whether Godot replaces the root site or lives at a subpath.
1. **Feel.** A grey-box room, the isometric camera, one capsule hero with smooth movement (acceleration, facing) and camera follow. Tune until it feels good. Update `DESIGN.md` §3.
2. **Combat core.** One enemy, targeting (Tab and click), auto-attack, one ability, the global cooldown, health bars.
3. **Rules port.** All six heroes and the enemy data, casts, auras, threat, interrupts, dispels, line of sight and level scaling, with GUT tests.
4. **AI.** The three AI party members and the enemy AI, plus the headless all-AI balance runner.
5. **Dungeon.** The Drowned Abbey: 6 packs and 3 bosses (Krogg, Velisse, Sulmar), the 14-minute timer, levels, unlocks and saves.
6. **Interface.** HUD, party frames, cast bars, healer click-to-cast, the rebinding editor, the pause menu, the summary screen.
7. **Voice.** A `voice_lines.json` manifest (id, speaker, text) built from `story.ts`, a Kokoro script that writes `game/assets/voice/<id>.wav`, and in-game playback.
8. **Art and audio (later).** The Tripo → Blender → Mixamo pipeline replaces the grey boxes, one asset class at a time.

## 6. Dev loop

- Claude edits `.gd` and `.tscn` files (both plain text), then runs headless import and tests to catch errors before handing over.
- The user plays in the editor (F5) to judge feel and writes notes. Feel is a human call; don't claim it from tests.
- Optional later: a community Godot MCP server (for example Godot Forge or Godot MCP Extended) so Claude can run the game and see screenshots. They are unofficial and of varying quality, so start without one.

## 7. Services available (ask the user for access when needed)

- **Steel.dev** (cloud browsers): smoke-test the **web export** in a real browser. Load it, confirm it boots, take a screenshot.
- **Firecrawl:** scraping documentation and research.
- **Keys:** never commit them or paste them into chat. Use environment variables or a git-ignored `.env`.

## 8. Opening prompt for the new session

> Read `docs/godot-rebuild-handoff.md` and `DESIGN.md`. Create the `godot-rebuild` branch from `main` and start milestone 0 (pipeline). Install or verify Godot, scaffold `game/` with GUT and a passing headless test, and add a CI workflow that exports the web build as an artifact. Then stop and show me before moving on to milestone 1.
