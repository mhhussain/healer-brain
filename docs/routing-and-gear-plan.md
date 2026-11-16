# Plan: routing, a big dungeon, and gear

Status: **agreed on 15 November 2026. Milestones 9 and 10 are built; 11 to 13 are not.** This is the record of a design session: every decision below was put to the owner and accepted. Build it in the five milestones of section 6. To start work in a new session, read [`routing-and-gear-handoff.md`](routing-and-gear-handoff.md) first.

[`DESIGN.md`](../DESIGN.md) describes the game as it is built today. As each milestone lands, move its decisions from here into `DESIGN.md`.

## 1. What is being added, and why

Fourfold is a timed dungeon runner in the style of WoW's Mythic+ and of Fellowship. Three things turn it from one short dungeon into a game you push:

- **Routing.** Before a run you open a map of the dungeon and plan which packs the tank pulls, in what order, where it holds them and where everyone else stands. This is meant to be a key feature of the game. All of it is optional: start without a plan and the AI runs a safe default.
- **A big dungeon.** Several wings, many packs, more trash than you need, and real choices about which way to go. Routing is built and tested while building it.
- **Gear.** Drops give progression and unique abilities, so there is a reason to climb dungeon levels without end ("pushing keys").

The levers a player has are then: the hero they play, the route and what the AI is told to do, and gear.

**Dropped:** talents. Gear abilities (trinkets, epics, sets, legendaries) do that job.

**Later, not in this plan:**

- A cooldown manager for teammates, as part of routing ("save big cooldowns for pull 6").
- Logins, so a player keeps a profile with progress and saved routes. Everything saved by this plan must be plain, versioned data so it can move to a profile.
- Weekly modifiers on dungeon levels.

## 2. Routing

### What a route is

- A route is an **ordered list of pulls**.
- A pull holds:
  - one or more **packs**, taken together, in the order they were added;
  - an optional **tank spot**, where the tank holds them;
  - an optional **spot for the healer and for each damage dealer**;
  - a **"go at once"** flag;
  - a one-line **note**.
- Anything left blank is the AI's choice. An empty route is today's behaviour.
- Per-pull orders such as "kill this one first" or "save cooldowns" are left out for now. The saved format must let them be added to a pull later without breaking old routes.

### Count

- Each enemy is worth points; bigger ones are worth more.
- A dungeon needs a set total, and holds about 130% of it, so the player chooses what to leave alive.
- A run is complete when **every boss is dead and the count is met**.
- The Abbey is a straight hall where nobody can walk past a pack, so it needs every pack and its count reads 100%. It tests order, big pulls and spots. Skipping is tested in the new dungeon.

### How the AI follows a route

- **Gathering.** The tank wakes the packs of a pull in the order they were added and drags them to the tank spot. The rest of the party waits at their spots instead of following.
- **Spots.** A ranged hero stands on their spot. A melee hero uses theirs only as the side to attack from. Everyone still leaves a spot to dodge danger, then returns.
- **Waiting.** The tank still waits for the party to be ready before each pull (today: everyone alive, above 80% health, healer above 60% mana). A pull marked "go at once" skips the wait, to chain into it.
- **Walking past packs.** Between pulls the tank and the party path around the wake range of packs that are not in the current pull.
- **When the plan breaks.** After a wipe or an accidental extra pack, the tank finishes the fight and picks up at the next unfinished pull. Packs already dead are skipped.
- **When the plan runs out.** The tank carries on with the nearest packs until the dungeon is done. A half-plan ("just my opening pulls") is therefore useful.
- **When you play the tank.** The route cannot steer you, so it is guidance: numbered markers on the map and on the ground for the next pull and its tank spot. The AI damage dealers and healer still go to their planned spots.

### The default route

- Each dungeon ships with a safe route written by hand.
- The AI follows it if the player never opens the map.
- It is what the map shows the first time, ready to edit. "Reset to default" brings it back.

### Saving and sharing

- Routes are saved per dungeon in **three named slots**. The last one used loads by default.
- A route can be copied and pasted as a **text code**.
- Routes are separate from teams: any team can run any route.

### The map

A flat top-down plan drawn from the level's own data (rooms, walls, doors, packs), not a camera view of the 3D scene. The whole dungeon is visible from the first visit; there is no fog.

It copies the shape that Mythic Dungeon Tools and Keystone.guru (Raider.IO's planner) share, so players of those tools already know it. Section 7 has the research.

- **Layout.** The map on the left. On the right, the list of pulls with the count bar above it.
- **A pull's row.** Its number and colour, its enemies as small portraits ("3×"), its count and the running total.
- **Clicks.**
  - Click a pack: add it to the current pull. Click it again: remove it.
  - Shift-click a pack, or press "Add pull": start a new pull.
  - Click a row: make that pull the current one.
  - Drag a row: reorder. Right-click a row: insert, merge or delete.
- **Pulls on the map.** Each pull has its own colour, an outline round its packs and a numbered label, and a line joins the pulls in order. Packs in no pull are faded. A green mark shows the pull that reaches 100%.
- **Spots.** Selecting a pull shows its draggable markers: tank, healer, each damage dealer. No WoW tool places players; this part is Fourfold's own.
- **Details.** Hovering a pack lists its enemies, count, health and abilities, and shows a patrol's path.
- **Warnings.** The map warns when the route misses the count or a boss, and when a pull cannot be reached without waking another pack ("pull 4 will also wake the Cantors"). It still lets the run start.
- **Left out.** Free drawing and arrows.

### Opening the map

- Before a run: a "Plan route" button (on the party screen in milestone 10; the route panel of the start screen from milestone 12).
- During a run: the M key. The game pauses while the map is open, and it cannot be opened mid-fight. Only pulls not yet made can be edited.

Note: M used to mute the sound. The owner gave M to the map; sound is turned off from the menu.

### During the run

The screen shows a count bar, the number of the next pull, and ground markers for the tank spot and the player's own spot. An option hides the ground markers.

## 3. The big dungeon

- **Size.** About 22 trash packs and 4 bosses on a 25-minute timer. (The Abbey: 6 packs, 3 bosses, 14 minutes.)
- **Shape.** An entrance area, then three wings that can be taken in any order, each ending in a boss. A couple of side passages link the wings as shortcuts. The last boss opens once the other three are dead.
- **Count.** The wings hold more trash than the count needs, so it can be met in more than one way.
- **Skips.** Rooms are wide enough that most packs can be walked past, and some skips are tight.
- **Patrols.** Two or three packs that walk a fixed path, shown on the map.
- **After a wipe.** The party returns to the last sanctuary lamp it lit: one at the entrance and one after each boss.
- **Setting.** The same drowned world and art kit as the Abbey, as a place of its own. Suggested: the harbour town below the Abbey. The existing cast plus three or four new kinds of enemy.
- **How levels are built.** Levels stay as data in code, reworked from "one hall" into rooms joined by doors. The level, the map and the tests all read that one description.
- **The Abbey** stays as the short introductory dungeon.

**To be proposed to the owner before building:** the name, a sketch of the layout, the new enemies, the four bosses and the default route.

## 4. Dungeon levels

Levels exist today: each one adds 8% enemy health and damage, compounding and without a cap, with new enemy abilities at levels 3, 6 and 9. That stays. What changes:

- Levels are **tracked per dungeon**. The Abbey keeps its levels. (Built with Tollhaven.)
- Timing a run opens the next level. Beating the timer by **20% opens two levels up, by 40% three**.
- Failing costs nothing; retry as often as you like.
- **Records**, per dungeon: the highest level timed and the best time at each level, with the team that did it. This is what a later profile page would show.
- Dungeon level 1 with empty gear slots is today's difficulty. The current balance is the baseline.

## 5. Gear

### Items

| Slot | What it does |
|---|---|
| Weapon | Raises damage and healing. |
| Armour | Raises health. |
| Trinket | No stat. A unique ability. |

- Weapons and armour carry one number, **item level**. There are no secondary stats.
- Any hero can use any weapon or armour. Only an item whose effect makes no sense elsewhere carries a role tag, such as "healer only".

### Rarity

| Rarity | Colour | What it adds |
|---|---|---|
| Common | white | The stat for its item level. |
| Uncommon | green | About 5% more of the stat. |
| Rare | blue | About 10% more. |
| Epic | purple | About 15% more. A weapon or armour also carries an **ability**, pressed or automatic. |
| Set | orange | Epic quality and stats. A **set bonus** when one hero wears all three items of the set (weapon, armour and trinket). |
| Legendary | gold | An extremely powerful buff or ability. |

- **Trinkets** start at rare, because they have no stat. Their effect grows with item level. An effect is one of two kinds: one you press, on a long cooldown, or one that triggers by itself.
- **Legendaries** are very rare. Only **one per party**. A legendary has no item level of its own: it counts as the highest item level in the inventory, plus 2.
- **Unique** is a flag an item may carry: only one of it can be worn across the party. It exists to stop effects being stacked until the game breaks.

### Where items come from

- **The end chest** of a finished run: two items, three if the run was timed, drawn from that dungeon's list. Each boss adds its own trinkets to its dungeon's list.
- **Item level of a drop.** Slightly above the player's current item level, measured across the inventory, but each dungeon level has a **ceiling**. Farming a low level stops helping; the player must push to keep climbing.
- **Rarity has hard boundaries by dungeon level.** As a starting point to tune:

  | From dungeon level | Can drop |
  |---|---|
  | 1 | Common, uncommon |
  | 3 | Rare |
  | 7 | Epic, set |
  | 12 | Legendary |

- **Legendaries** come only from the end chest, at about 2%, with the chance creeping up each run that gives none. Never from the gamble.
- **How items are made.** Common to rare weapons and armour are generated: a name and an item level. Trinkets, epics, sets and legendaries are hand-made, named items. To start: 10 trinkets, 6 epic abilities, 3 sets, 3 legendaries.

**To be proposed to the owner before building:** the list of named items and their effects.

### Inventory and shop

- Gear belongs to **the player**, in one shared inventory (60 spaces to start), which the player manages.
- Items are things: wearing the same item on two heroes needs two copies.
- **Coin** is earned by finishing a run and by selling items.
- **The shop** buys unwanted items, and sells a **gamble**: a random item for a slot the player chooses, with rarity odds set by their highest timed level. It is the protection against bad luck.

### Teams (loadouts)

Gear is chosen before the run, as routes are. Once a run starts it cannot be changed without leaving the run.

- A team holds: a name, the four heroes, which one the player plays, and each hero's three items.
- The player can keep **any number of teams**. Each can use the whole inventory; using an item in one team does not take it from another.
- **Rules, checked when an item is equipped:** two heroes wearing the same item need two copies; a unique item once per party; one legendary per party.
- A team that breaks a rule later (an item was sold) shows the empty slot and still runs.
- Selling an item that a team uses warns first and names those teams.
- **The default team** is always there and cannot be edited: the default party wearing the best gear owned, refreshed automatically. "Copy" turns it into a team of the player's own. A new player never has to open the screen.

### Gear in a run

- Up to three gear abilities you press: **one key per slot** (weapon, armour, trinket), shown as three small buttons beside the action bar. A slot whose effect is automatic has no button.
- AI teammates wear the gear their team gives them and use pressed abilities by themselves.

### The start screen

One screen, replacing today's party screen, with three choices side by side:

1. **Dungeon and level.**
2. **Team.**
3. **Route.**

Each opens its own editor. Start is always available with the defaults. Inventory and shop sit behind a "Gear" button, here and on the main menu.

### Protecting progress

Until logins exist the save lives in the browser and is lost if site data is cleared. Settings gets "export save" and "import save", as a text file.

## 6. Milestones

Each ends at a point where the owner plays and reviews. Stop there.

**9. Rooms and count.** (Built; its rules are in `DESIGN.md` sections 2, 4, 6 and 7.) Rework the rules from one hall to rooms joined by doors. Add enemy count; a run ends on bosses plus count. Sanctuary lamps become the points a wipe returns to. The Abbey must play as it does today, and the all-AI times must not move.

**10. Routes on the Abbey.** (Built; its rules are in `DESIGN.md` sections 2, 3, 6 and 8. Left for milestone 11, where the dungeon needs them: walking round packs that are not in the pull, the warning that a pull will wake another pack, and patrol paths on the map.) The route as data, saved in three slots, with the text code. The map planner. The AI following a route: order, several packs in a pull, the tank spot, party spots, "go at once", recovering after a wipe, carrying on when the plan ends. The Abbey's default route. In the run: the count bar, the next pull's number, ground markers, M for the map.

**11. The big dungeon.** (Built: Tollhaven. The owner approved [`tollhaven-proposal.md`](tollhaven-proposal.md) as proposed, and asked for levels to be kept for each dungeon from the start, so that part of milestone 12 came in with it. Its rules are in `DESIGN.md` sections 4, 6, 7b and 8.) The owner approves the name, layout sketch, enemies and bosses first. Then: three wings, about 22 packs, four bosses, patrols, new enemies, pathing around packs, the map's warnings, its default route, the 25-minute timer.

**12. Levels and basic gear.** (Built. The owner approved [`gear-proposal.md`](gear-proposal.md) as proposed. Its rules are in `DESIGN.md` sections 2, 3, 7c and 8.) Levels per dungeon (done in milestone 11: each dungeon's unlocked level, chosen level and bests are kept apart), fast clears and records. The end chest. Generated weapons and armour, and trinkets. Item level and its ceiling. The inventory, teams, the default team, the new start screen, the three gear keys. Save export and import.

**13. Rare gear and the shop.** Epic abilities, sets, legendaries, the unique flag. Coin, selling and the gamble.

Milestone 9 carries the most risk, because it changes assumptions that run through the rules and the AI. It goes first, on the dungeon that already has tests and known times.

## 7. Research: the route tools players know

Gathered on 15 November 2026. Raider.IO has no planner of its own: it bought Keystone.guru in 2023, and its weekly routes are Keystone.guru routes. The in-game addon is Mythic Dungeon Tools (MDT).

- **Layout.** Both put a large map beside a list of pulls. MDT shows a forces bar above the list.
- **A pull's row.** Number, a tint in the pull's colour, enemy portraits with a multiplier, the pull's forces and the running total.
- **Building.** In MDT, clicking an enemy adds its whole pack to the current pull, clicking again removes it, shift-click or "+ Add pull" starts a new pull, and ctrl-click takes a single enemy. Rows drag to reorder; a right-click menu has insert, merge, move, clear and delete.
- **On the map.** MDT gives each pull a colour (with a colour-blind palette), an outline round its enemies and a numbered label, and dims the pulls that are not selected. Keystone.guru can also draw a line between pulls and fade enemies that are in no pull.
- **Count.** MDT: "Forces: 70 (9.48%) / 596 (80.76%)", and a green line on the row that completes 100%. Keystone.guru warns about too much, not enough, and required enemies not killed.
- **Enemy details.** Hover for health and forces; a detail window for spells; patrols marked, with their path on hover.
- **Player positions.** Neither tool places players. Method's planner for Fellowship has a "stand here" marker, which is the nearest thing.
- **Sharing.** Named routes per dungeon, and export and import as a text string.
- **The main complaint about MDT** is that it does not help during the run, so players keep reopening it; a companion addon adds a compact view. The in-run count bar, next-pull number and ground markers answer this.

Sources: the MDT author's guide on Wowhead (`wowhead.com/guide/how-to-use-mythic-dungeon-tools-addon-guide`), the MDT source (`github.com/Nnoggie/MythicDungeonTools`), the Keystone.guru source and a public route page (`github.com/RaiderIO/keystone.guru`, `keystone.guru`), Raider.IO's Auto Route Creator announcement, and Method's Fellowship route planner (`method.gg/fellowship`). Keystone.guru's editing gestures were read from its interface text, not seen in use.

## 8. Details still open

These were not decided. Settle each with the owner, or propose a value and tune it in play, in the milestone that needs it.

- **Count values** per enemy and the total each dungeon needs. Milestone 9 proposed values, to be tuned in play: 3 for the casters and archers, 4 for the two melee kinds, 8 for the Prior, nothing for bosses and what they call up. The Abbey holds 92 and asks for all of it. Tollhaven holds 300 and asks for 231, with 1 for a Deckhand, 4 for a Tide Crier and 5 for a Shipwright's Mate or a Dredger: proposed values, to be tuned in play.
- **Which key** keeps M: settled. M opens the map; turning sound off is a box in the game's menu and on the setup screen.
- **The player's "current item level"** that drops are measured against, and how far above it a drop lands: settled. It is the average of the best weapon and the best armour owned, and a drop lands 1 to 3 above it.
- **The item-level ceiling** for each dungeon level: settled, 2 + 3 × the level.
- **How much** a point of item level adds to damage, healing and health: settled, 1%, with 5% more of that on an uncommon item and 10% more on a rare one.
- **Coin**: what a run pays, what items sell for, what the gamble costs and its odds. (Milestone 13)
- **Whether "one legendary per party" also limits how many can be owned.** As agreed it limits only what is worn. (Milestone 13)
