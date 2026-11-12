# Fourfold — design

Status: **draft for approval**. Nothing is built yet. Numbers are starting values and will be tuned.

Fourfold is an original, solo, browser-based dungeon runner in the style of timed five-player MMO dungeons. You play one hero in a party of four; AI plays the other three.

## 1. Settled decisions

| Area | Decision |
|---|---|
| Control | You play one hero per run. AI plays the other three. |
| Party | 1 tank, 1 healer, 2 DPS. You choose every slot, duplicates allowed. |
| View | Real-time, 2D top-down, camera follows your hero. |
| Run | One linear dungeon: 6 trash packs, 3 bosses, 14-minute timer. |
| Levels | Enemies gain 8% health and damage per level (compounding), plus new abilities at levels 3, 6 and 9. No cap. |
| Unlocks | You may start any level up to one above your highest timed clear. Shared across heroes. |
| Progression | No gear or talents. Highest timed level and best time are recorded per hero. |
| Visuals | Shapes, colour-coded roles, text buttons. No art assets, no audio. |
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
| W A S D | Move. Your hero faces its target, or the move direction if it has none. |
| Tab | Target the next enemy in line of sight, nearest first. |
| Left click | Target the enemy or ally under the mouse. |
| 1–6 | Use ability. |
| Esc | Clear target; again to open the pause menu. |
| P | Pause. |

- **Enemy abilities** go to your enemy target. With no target, they go to the tank's target.
- **Ally abilities** go to the ally under the mouse (hero on the map or party frame). With no ally under the mouse, they go to yourself.
- **Auto-attacks** fire on your enemy target whenever it is in range and in line of sight.

## 4. Combat rules

### Global rules

- **Global cooldown**: 1.5 s, shared by all abilities not marked "off GCD". The Duelist's is 1.0 s.
- **Casting**: moving cancels a cast. Instant abilities can be used while moving.
- **Range**: melee is 3 m. Ranged abilities and heals are 30 m.
- **Interrupts** stop the cast and lock the enemy out of that ability for 3 s. Only casts with a yellow bar can be interrupted; grey bars cannot.
- **Dispels** remove every debuff marked dispellable from one ally.

### Line of sight

- Walls and pillars block movement and line of sight.
- Every ranged attack, cast and heal needs a clear line from caster to target when it starts and when it finishes. A cast that loses its line fails and its cost is refunded.
- This applies to enemies too. An enemy caster or archer with no line to its target walks until it has one, so a tank can gather ranged enemies by pulling them and stepping behind a corner.
- Ground effects and melee attacks ignore line of sight.
- You can see the whole room; line of sight limits actions, not vision.

### Threat

- Each enemy keeps a threat table and attacks whoever is highest.
- Damage generates 1 threat per point. The Warden's damage generates 4 per point.
- Healing generates 0.5 threat per point healed, split across every enemy in combat.
- An enemy switches targets when another hero passes 110% of its current target's threat (130% for heroes outside melee range).
- The Warden's Challenge puts the Warden on top and forces the target for 4 s.

### Death and recovery

- A dead hero stays down until combat ends, then revives. Each death adds 5 s to the timer.
- If all four die, the pack or boss resets to full health and the party revives at the room entrance.
- Out of combat, health and resources refill at 10% per second.

## 5. Heroes

All six have six abilities: three rotational, one interrupt or dispel, one defensive, one major cooldown.

### Warden — tank

2400 health. **Rage** (0–100): +5 per auto-attack, +3 per hit taken, drains out of combat.

| Key | Ability | Cost / cooldown | Effect |
|---|---|---|---|
| 1 | Shield Strike | 4.5 s cd | 110 damage. +15 rage. |
| 2 | Sweep | — | 50 damage to every enemy within 6 m. +5 rage per enemy hit, up to 15. |
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

1200 health. **Mana** (1000): +8 per second in combat. Weak ranged auto-attack.

| Key | Ability | Cost / cooldown | Effect |
|---|---|---|---|
| 1 | Mending Vine | 35 mana, instant | Heal 60 every 2 s for 14 s. One per ally; recasting refreshes it. |
| 2 | Bark Ward | 55 mana, 4 s cd | Shield an ally against the next 350 damage, for 12 s. |
| 3 | Bloom | 60 mana, 10 s cd | Every ally with Mending Vine is healed for 240 at once. The vines keep running. |
| 4 | Cleansing Dew | 30 mana, 8 s cd | Dispel one ally. |
| 5 | Bramble Guard | 45 s cd, off GCD | An ally takes 30% less damage for 8 s. |
| 6 | Verdant Tide | 2 min cd | Put Mending Vine on every ally. For 10 s vines tick twice as fast and Bark Ward has no cooldown. |

### Duelist — melee DPS

1300 health. **Energy** (100): +12 per second. **Combo points** (0–5). Global cooldown 1.0 s.

| Key | Ability | Cost / cooldown | Effect |
|---|---|---|---|
| 1 | Slash | 40 energy | 95 damage. +1 combo point. |
| 2 | Whirl | 45 energy | 55 damage to every enemy within 5 m. +1 combo point. |
| 3 | Finishing Thrust | 25 energy, all combo points | 70 damage per combo point. |
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
| 6 | Kindled Mind | 2 min cd, off GCD | For 12 s, Firebolt casts in half the time. |

## 6. AI teammates

Teammates play reliably well at every level, with reaction delays of 0.3–0.6 s. They do their own job fully and never do yours.

- **All roles**: step out of ground effects and frontals, stay in range and line of sight, use their defensive below 40% health.
- **AI tank**
  - Pulls the next pack when everyone is alive, above 80% health, and the healer is above 60% mana.
  - Gathers ranged enemies with line of sight, and faces enemies away from the party.
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

## 7. The dungeon — The Sunken Bastion

Linear: two packs, a boss, two packs, a boss, two packs, a boss. Rooms are joined by corridors; several rooms have pillars.

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
| 3 | 2 Brutes, 2 Hexers (pillared room) | Line-of-sight pulls. |
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

- **Party frames**: health, resource, shields, heal-over-time, dispellable debuffs (highlighted), active defensives.
- **Target frame**: health, cast bar, your debuffs.
- **Nameplates** over every enemy: health, cast bar (yellow = interruptible, grey = not, **KICK** = your turn), and a border that turns red when the enemy is attacking a non-tank.
- **Action bar**: six buttons with key, cooldown sweep, cost and out-of-range or no-line-of-sight dimming. Hover for a tooltip.
- **Run bar**: timer against 14:00, packs and bosses killed, deaths.
- **Telegraphs**: ground circles and cones drawn on the floor before they hit.
- **Alerts**: a short text call for major boss casts.
- **Party setup** shows each hero's abilities and a short "how to play".

## 9. Technical

- **Simulation** runs on a fixed timestep, separate from rendering and holding no browser state.
- **Automated runs**: the same simulation runs headless in tests with AI in all four slots. These runs tune balance and check that every party composition can finish.
- **Rendering**: Canvas for the world, HTML for the interface.
- **Save data**: `localStorage` only — unlocked level, per-hero bests.
- **Deploy**: a GitHub Action builds and publishes to GitHub Pages on every push to `main`.

## 10. Out of scope for the first version

Gear, talents, run modifiers, route choices, more dungeons, audio, mobile and touch, key rebinding, saving mid-run.
