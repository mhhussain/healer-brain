# Fourfold — design

Status: **approved and built** as the TypeScript game on `main`. Numbers below are the tuned values in that game.

On the `godot-rebuild` branch the game is being rebuilt in Godot with an isometric view (see [`docs/godot-rebuild-handoff.md`](docs/godot-rebuild-handoff.md) and [`game/README.md`](game/README.md)). The rules here still hold; the view and section 3 (controls) describe the rebuild, and the rest of the interface is rebuilt milestone by milestone. Where the rebuild differs:

- The dungeon, heroes, enemies, AI, clock, unlocks and bests are all in and run to the same times as before (all-AI: about 7:25 to 8:05 at level 1, 10:15 to 11:00 at level 5, 12:00 to 13:00 at level 7).
- Effects over time always get their last tick. In the TypeScript game rounding dropped it for some, so Mending Kelp healed 360 and Tallow Burn dealt 200; here they give the 420 and 240 their descriptions promise.
- Until the title, party setup and level screens are rebuilt, keys choose the run (see `game/README.md`), and the summary is a plain panel.

Fourfold is an original, solo, browser-based dungeon runner in the style of timed five-player MMO dungeons. You play one hero in a party of four; AI plays the other three.

## 1. Settled decisions

| Area | Decision |
|---|---|
| Control | You play one hero per run. AI plays the other three. |
| Party | 1 tank, 1 healer, 2 DPS. You choose every slot, duplicates allowed. |
| View | Real-time isometric: a 3D floor seen from a fixed camera looking down from one corner, which follows your hero. (The TypeScript game is a belt-scroller seen from the side.) |
| Run | One linear dungeon: 6 trash packs, 3 bosses, 14-minute timer. |
| Levels | Enemies gain 8% health and damage per level (compounding), plus new abilities at levels 3, 6 and 9. No cap. |
| Unlocks | You may start any level up to one above your highest timed clear. Shared across heroes. |
| Progression | No gear or talents. Highest timed level and best time are recorded per hero. |
| Visuals | Storybook figures and scenery drawn in code, one colour and one hat per character. No image files. See section 11. |
| Sound | Music, ambience and effects synthesised in the browser. No audio files. See section 11. |
| Story | The Last Vespers: a light story told through one opening card, speech bubbles and an ending. See section 11. |
| Tech | TypeScript, Vite, Canvas, no backend, `localStorage`, GitHub Pages. Desktop keyboard and mouse only. |

## 2. Run flow

1. **Title** → **Party setup**: pick your hero, then the heroes for the three AI slots.
2. **Level select**: any unlocked level.
3. **Run**: the timer starts on the first pull and stops when the third boss dies.
4. **Summary**: time, result, and per-hero damage, healing, interrupts, dispels and deaths.

Result rules:

- **Timed**: all three bosses dead inside 14:00. Unlocks the next level.
- **Completed**: all three bosses dead after 14:00. Recorded, unlocks nothing.
- There is no way to fail outright; you can abandon from the pause menu.

## 3. Controls

| Input | Action |
|---|---|
| W A S D | Move as the screen shows it: W up the screen, S down it, A left, D right. Two keys together move on the diagonal at the same speed. Your hero faces its target, or the move direction if it has none. |
| Q E | Also left and right. |
| Space | Jump. For show only: it clears nothing and changes nothing in a fight. |
| Mouse wheel | Zoom in and out between two limits. Two-finger scroll or pinch does the same on a trackpad. |
| Tab | Target the next enemy in line of sight, nearest first. |
| Left click | Target the enemy whose figure is under the mouse; a near miss still counts. |
| 1–6 | Use ability. T is also the interrupt and ` is also the personal defensive (the fifth ability). All of these can be changed. |
| Middle and side mouse buttons | Use the ability bound to them, wherever the pointer is. Unbound by default. |
| Esc | Clear target; again to open the pause menu. |
| P | Pause. |

- **Movement** is relative to the camera, not the dungeon: the halls run from the lower left of the screen to the upper right, so W and D together walk straight along them. The hero reaches full speed (8.5 m/s) in about a tenth of a second and stops as quickly.
- **The camera** never turns. It trails the hero slightly and leads about a metre in the direction of travel.
- **Enemy abilities** go to your enemy target. With no target, they go to the tank's target.
- **Ally abilities** go to the ally under the mouse (hero on the map or party frame). With no ally under the mouse, they go to yourself.
- **Auto-attacks** fire on your enemy target whenever it is in range and in line of sight.

### Keys and mouse buttons

- Every ability has two key slots and one mouse-button slot (middle, side back, side forward). The editor is on the party setup screen and in the pause menu, and bindings are saved per hero.
- A key or button does one thing: binding it to an ability takes it away from the ability that had it.
- Movement, Space, Tab, Esc, P and M are kept for the game and cannot be bound.
- An ally ability cast from a key or mouse button lands on the ally under the pointer, as usual.

### Click-to-cast (healers)

- Clicking a party frame casts the spell bound to that click. It applies to party frames only; clicking a hero on the map does nothing.
- Defaults: left click is Mend / Mending Vine, right click is Quick Mend / Bark Ward, Shift + left click is the dispel, Shift + right click is the damage reduction.
- Any ally spell can be rebound to left, right, middle or side click, plain or with Shift, Ctrl or Alt. On a party frame, a click-cast for a button comes before a mouse-button binding for it. Your own frame, above the party row, takes click-casts too. The editor is on the party setup screen and in the pause menu, and bindings are saved per healer.
- Keys 1–6 keep working alongside it.

## 4. Combat rules

### Global rules

- **Global cooldown**: 1.5 s, shared by all abilities not marked "off GCD". The Duelist's is 1.0 s.
- **Casting**: moving cancels a cast. Instant abilities can be used while moving.
- **Range**: melee is 3 m. Ranged abilities and heals are 30 m.
- **Speed**: heroes move 8.5 m a second, enemies 6.5.
- **Interrupts** stop the cast and lock the enemy out of that ability for 3 s. Only casts with a yellow bar can be interrupted; grey bars cannot.
- **Dispels** remove every debuff marked dispellable from one ally.

### Line of sight

- Walls and pillars block movement and line of sight.
- Every ranged attack, cast and heal needs a clear line from caster to target when it starts and when it finishes. A cast that loses its line fails and its cost is refunded.
- This applies to enemies too. An enemy caster or archer with no line to its target walks until it has one, so a tank can gather ranged enemies by pulling them and stepping behind a corner.
- Ground effects and melee attacks ignore line of sight.
- You can see the whole room; line of sight limits actions, not vision.
- Ranges and line of sight are measured on the floor. There are no lanes: an enemy deeper in the room is hit like any other.
- A pillar turns see-through while someone stands behind it.

### Threat

- Each enemy keeps a threat table and attacks whoever is highest.
- Damage generates 1 threat per point. The Warden's damage generates 4 per point.
- Healing generates 0.5 threat per point healed, split across every enemy in combat.
- An enemy switches targets when another hero passes 110% of its current target's threat (130% for heroes outside melee range).
- The Warden's Challenge puts the Warden on top and forces the target for 4 s. It shows on the enemy as a 4 s debuff.

### Death and recovery

- A dead hero stays down until combat ends, then revives. Each death adds 5 s to the timer.
- If all four die, the pack or boss resets to full health, destroyed pillars are rebuilt, and the party revives at the room entrance.
- Out of combat, health and resources refill at 10% per second.

## 5. Heroes

All six have six abilities: three rotational, one interrupt or dispel, one defensive, one major cooldown.

### Warden — tank

2400 health. **Rage** (0–100): +2 per auto-attack, +1 when hit (at most once a second), drains out of combat. Gains are kept low so Brace has to be timed, not held up permanently.

| Key | Ability | Cost / cooldown | Effect |
|---|---|---|---|
| 1 | Shield Strike | 4.5 s cd | 110 damage. +8 rage. |
| 2 | Sweep | — | 50 damage to every enemy within 6 m. +1 rage per enemy hit, up to 5. |
| 3 | Challenge | 8 s cd, off GCD, 30 m | Target attacks you for 4 s and you go to the top of its threat. The ranged pull. |
| 4 | Shield Bash | 15 s cd, off GCD, melee | Interrupt. |
| 5 | Brace | 40 rage, off GCD | Take 50% less physical damage for 6 s. |
| 6 | Unbreakable | 2 min cd, off GCD | Take 40% less damage of all kinds for 10 s and heal 20% of maximum health. |

### Mender — direct healer

1200 health. **Mana** (1000): +8 per second in combat. Weak ranged auto-attack.

| Key | Ability | Cost / cooldown | Effect |
|---|---|---|---|
| 1 | Mend | 40 mana, 2.0 s cast | Heal 420. Also heals the most injured other ally within 10 m of the target for 30%. |
| 2 | Quick Mend | 90 mana, instant | Heal 330. |
| 3 | Rebuke | 1.5 s cast | 70 damage. Restores 15 mana. |
| 4 | Purify | 30 mana, 8 s cd | Dispel one ally. |
| 5 | Guardian Ward | 45 s cd, off GCD | An ally takes 40% less damage for 6 s. |
| 6 | Sanctuary | 2 min cd | Heal every ally for 300 now and 600 more over 8 s. |

### Bloomweaver — heal-over-time and shield healer

1200 health. **Mana** (1000): +12 per second in combat, since there is no damage spell to win mana back with. Weak ranged auto-attack.

| Key | Ability | Cost / cooldown | Effect |
|---|---|---|---|
| 1 | Mending Vine | 30 mana, instant | Heal 60 every 2 s for 14 s. One per ally; recasting refreshes it. |
| 2 | Bark Ward | 42 mana, 3 s cd | Shield an ally against the next 350 damage, for 12 s. |
| 3 | Bloom | 45 mana, 10 s cd | Every ally with Mending Vine is healed for 240 at once. The vines keep running. |
| 4 | Cleansing Dew | 30 mana, 8 s cd | Dispel one ally. |
| 5 | Bramble Guard | 45 s cd, off GCD | An ally takes 30% less damage for 8 s. |
| 6 | Verdant Tide | 2 min cd | Put Mending Vine on every ally. For 10 s vines tick twice as fast and Bark Ward has no cooldown. |

### Duelist — melee DPS

1300 health. **Energy** (100): +20 per second. **Combo points** (0–5). Global cooldown 1.0 s. Energy comes back fast and hits are small, so there is a button to press about every two seconds, and every second during Bloodrush.

| Key | Ability | Cost / cooldown | Effect |
|---|---|---|---|
| 1 | Slash | 40 energy | 60 damage. +1 combo point. |
| 2 | Whirl | 45 energy | 35 damage to every enemy within 5 m. +1 combo point. |
| 3 | Finishing Thrust | 25 energy, all combo points | 45 damage per combo point. |
| 4 | Hilt Jab | 15 s cd, off GCD, melee | Interrupt. |
| 5 | Riposte | 60 s cd, off GCD | Take 50% less damage for 5 s. |
| 6 | Bloodrush | 2 min cd, off GCD | For 12 s, energy regenerates twice as fast and you deal 20% more damage. |

### Ranger — ranged physical DPS

1200 health. **Focus** (100): +4 per second. Every ability can be used while moving. Strong ranged auto-attack.

| Key | Ability | Cost / cooldown | Effect |
|---|---|---|---|
| 1 | Quick Shot | — | 60 damage. +15 focus. |
| 2 | Piercing Shot | 45 focus | 190 damage. |
| 3 | Scatter Volley | 40 focus | 75 damage to the target and every enemy within 6 m of it. |
| 4 | Jarring Shot | 20 s cd, off GCD | Interrupt at range. |
| 5 | Tumble | 20 s cd, off GCD | Roll 8 m in your move direction and take 30% less damage for 3 s. |
| 6 | Hawk's Focus | 90 s cd, off GCD | For 10 s, auto-attacks fire 50% faster and Quick Shot gives double focus. |

### Pyromancer — caster DPS

1100 health. **Heat** (0–100), built by casting and spent on Flame Burst. Weak ranged auto-attack.

| Key | Ability | Cost / cooldown | Effect |
|---|---|---|---|
| 1 | Firebolt | 2.0 s cast | 170 damage. +25 Heat. |
| 2 | Ignite | instant | 240 damage over 12 s. +10 Heat. One per enemy. |
| 3 | Flame Burst | 50 Heat, instant | 200 damage to the target and 90 to every enemy within 6 m of it. |
| 4 | Stifle | 20 s cd, off GCD | Interrupt at range. |
| 5 | Ember Shield | 45 s cd, off GCD | Shield yourself against the next 400 damage, for 8 s. |
| 6 | Kindled Mind | 2 min cd, off GCD | For 12 s, Firebolt casts in half the time (1 s, with a 1 s global cooldown). |

## 6. AI teammates

Teammates play reliably well at every level, with reaction delays of 0.3–0.6 s. They do their own job fully and never do yours.

- **All roles**: step out of ground effects and frontals and never walk into one, stay in range and line of sight, use their defensive below 40% health. They keep 14 m away from packs that are not in the fight.
- **Going in**: every fight happens inside the room. The tank pulls from the doorway and then walks to a spot about 8 m inside (10 m for a boss). Everyone else stays in whatever room the tank is in, so nobody hangs back behind the dividing wall. The story reason: the sea comes in over each doorway once the party is through it.
- **AI tank**
  - Pulls the next pack when everyone is alive, above 80% health, and the healer is above 60% mana.
  - Stands among the ranged enemies so the melee ones are dragged onto them, and faces enemies away from the party.
  - Holds Brace for tank busters and uses Unbreakable below 35% health.
- **AI healer**
  - Heals the most endangered ally first and keeps the tank topped up.
  - Dispels within about a second.
  - Uses the damage-reduction ability on tank busters and the major cooldown when three allies are below half health.
- **AI DPS**
  - Wait 1.5 s after the tank's first hit before attacking, then focus the tank's target.
  - Switch to priority targets (enemy healers first).
  - Use the major cooldown on bosses and large packs.
- **When you tank**: nobody attacks until you do. AI DPS then go all out; holding threat is your job.

### Interrupt turns

- Each interruptible cast is assigned to one party member: whoever has an interrupt ready and has gone longest without using it.
- When the turn is yours, the enemy cast bar is marked **KICK**. AI teammates do not cover a turn that is yours.
- If your interrupt is on cooldown, the turn goes to someone else.

## 7. The dungeon — The Drowned Abbey

Sections 4 to 7 describe mechanics under their original working names. The names players see are listed in section 11.

Linear: two packs, a boss, two packs, a boss, two packs, a boss.

- **Layout**: one straight hall running left to right. Pack rooms are 28 m long and 16 m deep; boss rooms are 34 m long and 20 m deep.
- **Dividing walls**: each room is split from the next by a 3 m wall that juts out from the back and leaves a 6 m doorway along the front edge. The AI tank pulls from the doorway and then goes in. A player tank can still step back behind the wall for a line-of-sight pull; the AI party follows it.
- **Pillars**: several rooms have pillars that block movement and sight.
- **View**: depth is drawn at 60% scale. The front edge of the floor is open; nothing stands between the camera and the party except pillars.

### Enemy types

| Enemy | Behaviour | Added at level 3 |
|---|---|---|
| Brute | Melee. Hits its target hard and often. | Crushing Blow: a telegraphed tank buster. |
| Hexer | Caster. Dark Bolt (interruptible) at a random hero. | Wither: interruptible; if it lands, a dispellable damage-over-time debuff. |
| Archer | Ranged attacks on its target. | Arrow Rain: a ground circle under a random hero. |
| Shaman | Caster. Restore (interruptible) heals an injured enemy. Priority target. | Restore heals more. |
| Berserker | Fast melee. Enrages below 30% health. | Enrage starts at 50%. |
| Overseer | Elite melee. Sweeping Cut: a telegraphed frontal cone. | Rally: nearby enemies deal 15% more damage while it lives. |

At **level 9**, every trash enemy deals 25% more damage below 25% health.

### Packs

| Pack | Enemies | Teaches |
|---|---|---|
| 1 | 3 Brutes, 1 Hexer | Threat, first interrupts. |
| 2 | 2 Brutes, 1 Archer, 1 Shaman | Priority targets. |
| 3 | 2 Brutes, 2 Hexers (pillared room) | Casters and line of sight. |
| 4 | 1 Overseer, 2 Archers, 1 Shaman | Frontals. |
| 5 | 2 Berserkers, 1 Hexer, 1 Shaman | Enrage damage, cooldown use. |
| 6 | 1 Overseer, 1 Berserker, 2 Archers | Everything together. |

### Boss 1 — Krogg the Gatebreaker (tank check)

- **Skullcrack**: telegraphed heavy physical hit on the tank. Answer with Brace or a healer's damage reduction.
- **Rending Sweep**: wide frontal cone. The tank faces Krogg away; everyone else stays behind him.
- **Frenzy**: below 30% health Krogg attacks 30% faster.
- **Level 6 adds** Tremor: ground circles under two random heroes.

### Boss 2 — Matron Velisse (adds and interrupts)

- **Brood**: every 25 s, three Hatchlings spawn. The tank must pick them up; DPS must kill them.
- **Venom Bolt**: Hatchlings cast it constantly (interruptible, weak alone, dangerous together).
- **Brood Mending**: Velisse heals herself for 10% (interruptible, must be stopped).
- **Level 6 adds** Bursting: a Hatchling leaves a ground circle where it dies.

### Boss 3 — Archon Sulmar (party damage, dodging, dispels)

- **Dirge**: unavoidable damage to everyone for 5 s, every 20 s. Healed through.
- **Ashfall**: a ground circle under every hero. Move out.
- **Searing Brand**: a dispellable damage-over-time debuff on two heroes.
- **Annihilation**: at 66% and 33% health, a 5 s cast that nearly kills anyone in line of sight. Hide behind a pillar.
- **Level 6 adds**: Annihilation destroys the pillar that was used.

## 8. Interface

- **Bottom of the screen**, from the bottom up: the action bar; the party frames in one row; then your own frame on the left and the target frame on the right, with your cast bar between them.
- **Party frames**: health, resource, shields, heal-over-time, dispellable debuffs (highlighted), active defensives.
- **Your frame**: name, health and resource with numbers, combo points for the Duelist.
- **Target frame**: health, cast bar, who the enemy is attacking (red when it is not the tank), and everything on it with the seconds left. Your own debuffs come first, edged in gold.
- **Figures**: heroes wear their role colour with a ring under their feet; yours has a yellow ring and a marker overhead. Your target has a red ring.
- **Nameplates** over every enemy: health, cast bar (yellow = interruptible, grey = not, **KICK** = your turn), and a border that turns red when the enemy is attacking a non-tank.
- **Debuff chips** under each nameplate: one per debuff the party has put on the enemy, in its caster's colour, draining as it runs out and showing the seconds left (tenths in the last three). Yours come first, edged in gold.
- **Action bar**: six buttons with their keys and mouse button, cooldown sweep, cost and out-of-range or no-line-of-sight dimming. Hover for a tooltip.
- **Run bar**: timer against 14:00, packs and bosses killed, deaths.
- **Telegraphs**: ground circles and cones drawn on the floor before they hit.
- **Camera**: follows your hero, runs 1 m ahead of the way you are walking, and leans up to 7 m towards the fight, so both stay on screen. AI teammates fight within 21 m of their target for the same reason. A heavy hit on a hero jolts the screen, more so when it is on you; this is off when the system asks for reduced motion.
- **Alerts**: a short text call for major boss casts.
- **Party setup** shows each hero's abilities and a short "how to play".

## 9. Technical

- **Simulation** runs on a fixed timestep of 60 ticks a second, separate from rendering and holding no browser state.
- **Smooth motion**: every unit remembers where it was one tick ago, and the renderer draws it part-way between the two, so movement is even on any refresh rate. A figure's stride eases in and out, and a figure other than yours only turns round after facing the new way for 0.12 s.
- **Automated runs**: the same simulation runs headless with AI in all four slots. `npm test` checks that every party composition times level 1; `npm run sim -- 1,5,8 2` prints times, deaths and per-hero output for the given levels and number of seeds.
- **Balance as tuned**: all-AI parties time level 1 in about 8 minutes and level 7 in 12–13. Most still time level 8; they start wiping on the last boss around level 9–10.
- **Demo flags**: adding `?autostart&autoplay` to the URL starts a run with the AI playing your hero too; `&speed=4` runs it faster. `?debug` exposes the running world as `window.fourfold` for browser tests.
- **Rendering**: Canvas for the world, HTML for the interface. The simulation is still a flat floor plan; the renderer alone turns it into the side-on view.
- **Save data**: `localStorage` only — unlocked level, per-hero bests.
- **Deploy**: a GitHub Action builds and publishes to GitHub Pages on every push to `main`.

## 10. Out of scope for the first version

Gear, talents, run modifiers, route choices, more dungeons, mobile and touch, rebinding the movement keys, saving mid-run.

## 11. Theme: The Drowned Abbey

The theme is a reskin. Ids, numbers and mechanics are unchanged; only names, drawing, sound and words differ.

### Settled decisions

| Area | Decision |
|---|---|
| World | A monastery drowned under a tidal sea. |
| Tone | Melancholy but warm: a small party doing a hard, kind job. |
| Premise | The Last Vespers. A century ago Abbot Sulmar rang the great bell against a storm and the sea took the abbey. Once a season the tide draws back for fourteen minutes. A crew of four, a Fourfold, goes down to relight three sanctuary lamps. |
| Timer | The 14:00 timer is the tide. The sea at the front edge of the hall rises as it runs, and covers the floor once time is up. |
| Enemies | The monks who stayed. They are not evil; they are still at their posts. When one falls it rises into light and bubbles: laid to rest, not killed. |
| Palette | Tidelight: sea-teal glow, candle gold, coral for danger, bone for text. Defined in `src/ui/palette.ts` and `src/style.css`. |
| Figures | Storybook: bell-shaped body, big round head, soft shading, one hat and one prop each. `src/ui/figures.ts`. |
| Level space | Three zones of three encounters, each ending in a lamp. `src/ui/scenery.ts`. |
| Interface | Wet slate: dark see-through panels with gold edges and old-print lettering. Parchment only for the story card and speech bubbles. |
| Story weight | One opening card, one line of banter per pull and boss, a line per lamp, two endings. No cutscenes. `src/ui/story.ts`. |
| Sound | All synthesised with Web Audio in `src/ui/audio.ts`. On by default, with a mute button, a volume slider and the M key. |
| Weather | Drawn from the clock in `src/ui/weather.ts`: rain that leans with the gusts at the Sea Gate, drips from the Infirmary vault, dust and candle smoke in the Nave. |
| Thresholds | Once the party has gone through a doorway the sea comes in over it, and draws back if they are driven out. It is why nobody fights on a threshold. |

### Zones

| Zone | Encounters | Look | Sound |
|---|---|---|---|
| The Sea Gate | The Cloister Walk, The Wet Stair, Brother Krogg | A ruin open to the evening sky: low broken walls, arches onto the sea, hanging kelp, a moon. | Surf and gulls. |
| The Infirmary | The Undercroft, The Dispensary, Sister Velisse | A dark vaulted undercroft: cots, pilasters, clusters of glowing eggs. | Drips and a slow heartbeat. |
| The Nave | The Choir Stalls, The Bell Stair, Abbot Sulmar | Tall coloured-glass windows, candle stands, the great bell overhead. | Creaking rope and a faint choir. |

When a boss is laid to rest its lamp lights and warm gold light floods back through its zone.

### Music

- D minor, 75 beats a minute, scheduled one bar at a time from the state of the run.
- Wandering: a low drone and one or two bells a bar.
- A fight adds a drum and a running figure in the bells.
- A boss adds the drowned choir. It has three voices for Krogg, two for Velisse and one for Sulmar: one voice is lost for each lamp already lit.
- A lit lamp turns the key major for a moment.
- In the last two minutes a low tide bell tolls each bar and the sea grows louder.
- An enemy cast is a sung note that swells until it lands and cuts off when silenced. Boss warnings toll the great bell.

### The cast

| Id | Name | Title | Colour | Hat and prop |
|---|---|---|---|---|
| warden | Hale Dunmarrow | The Gatewarden | Steel blue | Helm, shield and mace |
| mender | Sister Wren | The Lamplighter | Bone and teal | Hood, lantern staff |
| bloomweaver | Old Maren | The Kelpwife | Kelp green | Kelp crown, crook |
| duelist | Corvin Ashby | The Wrecker | Plum | Bandana, cutlass |
| ranger | Isolde Fenn | The Harpooner | Oilskin yellow | Sou'wester, harpoon |
| pyromancer | Tobias Wick | The Chandler | Burnt umber | Candle hat, candle staff |

### Renames

| Was | Is |
|---|---|
| Warden: Rage; Shield Strike, Sweep, Challenge, Shield Bash, Brace, Unbreakable | Grit; Bulwark Blow, Mooring Sweep, Pilot's Hail, Breakwater Bash, Brace, Seawall |
| Mender: Mana; Mend, Quick Mend, Rebuke, Purify, Guardian Ward, Sanctuary | Lamplight; Warm Light, Spark, Rebuke, Absolve, Lantern Ward, Sanctuary |
| Bloomweaver: Mana; Mending Vine, Bark Ward, Bloom, Cleansing Dew, Bramble Guard, Verdant Tide | Tidewater; Mending Kelp, Shell Ward, Kelp Bloom, Salt Rinse, Barnacle Guard, Green Tide |
| Duelist: Energy; Slash, Whirl, Finishing Thrust, Hilt Jab, Riposte, Bloodrush | Nerve; Cutlass, Round Turn, Final Cut, Hilt Jab, Riposte, Wrecker's Luck |
| Ranger: Focus; Quick Shot, Piercing Shot, Scatter Volley, Jarring Shot, Tumble, Hawk's Focus | Focus; Snap Throw, Whaler's Lance, Barb Scatter, Jarring Barb, Deck Roll, Gull's Eye |
| Pyromancer: Heat; Firebolt, Ignite, Flame Burst, Stifle, Ember Shield, Kindled Mind | Heat; Wickfire, Tallow Burn, Flare-Up, Snuff, Wax Seal, Steady Flame |
| Brute: Crushing Blow | Drowned Porter: Heavy Load |
| Hexer: Wither, Dark Bolt | Brine Cantor: Withering Verse, Sour Note |
| Archer: Arrow Rain | Net-Brother: Rain of Hooks |
| Shaman: Restore | Tide Almoner: Alms |
| Berserker: Enrage | Penitent: Fervour |
| Overseer: Sweeping Cut | The Prior: Banner Sweep |
| Hatchling: Venom Bolt | Brineling: Brine Spit |
| Krogg the Gatebreaker: Skullcrack, Rending Sweep, Tremor, Frenzy | Brother Krogg: The Great Key, Chain Sweep, Falling Stones, None Shall Pass |
| Matron Velisse: Brood Mending, Brood | Sister Velisse: Bedside Manner, Wake the Ward |
| Archon Sulmar: Annihilation, Dirge, Ashfall, Searing Brand | Abbot Sulmar: The Last Toll, Dirge, Saltfall, Brine Brand |
| Interrupt, dispel, death | Silence, cleanse, fall |
| Packs 1 to 6 | The Cloister Walk, The Wet Stair, The Undercroft, The Dispensary, The Choir Stalls, The Bell Stair |
