# Proposal: rare gear and the shop

Status: **approved by the owner as proposed, on 16 November 2026, and built.** [`DESIGN.md`](../DESIGN.md) section 7c is the record of what was built, with the few things this left open. It was the first step of milestone 13 in [`routing-and-gear-plan.md`](routing-and-gear-plan.md), which says the owner approves the named items and the open numbers before any of it is made. What was already agreed there is not asked again; this fills in what was left open. What is built so far is in [`DESIGN.md`](../DESIGN.md) section 7c.

Milestone 13 is the last of the five: epic items, sets, legendaries, the unique flag, coin, selling and the gamble.

## 1. Epic items

- An epic (purple) is a generated weapon or armour, as now, with **15% more** of its stat and **one ability**. There are six abilities, three that weapons can carry and three that armour can.
- An ability is a share, not a number, so it does not outgrow the weapon beside it. It does not change with item level.
- A pressed one uses the slot's key: **Z** for the weapon, **X** for the armour. It does not wait for other abilities.
- The item is named for its ability: "Stormcalling Gaff", "Barnacled Hauberk".

| Ability | On | Kind | What it does |
|---|---|---|---|
| **Stormcalling** | Weapon | Pressed, 60 s | You hit and heal 25% harder for 10 s. |
| **Reaving** | Weapon | By itself | Your hits on an enemy below 30% health are 25% harder, and your heals on an ally below 30% are 25% stronger. |
| **Forked** | Weapon | By itself | Each hit of yours strikes one other enemy within 6 m for 20% of it; each heal of yours gives 20% of it to the most hurt other ally. |
| **Bulwarked** | Armour | Pressed, 90 s | A shield that soaks 30% of your health, for 10 s. |
| **Barnacled** | Armour | By itself | An enemy that hits you takes 20% of the blow itself. |
| **Lifelined** | Armour | By itself, once every 3 minutes | A blow that would kill you leaves you at 1 health instead, with a shield of 20% of your health for 5 s. **Unique.** |

AI teammates press Stormcalling on a boss or a pull of four or more, and Bulwarked below half health.

## 2. Sets

- A set (orange) is three named items: a weapon, armour and a trinket. The weapon and armour have an epic's stats and no ability. The trinket does nothing by itself.
- When **one hero wears all three**, the set's bonus is on. So a set costs a hero their trinket and both abilities, and has to be worth that.
- Any hero may wear any set; each is made with one role in mind.

| Set | Its three pieces | Bonus with all three |
|---|---|---|
| **Breakwater** (for a tank) | Breakwater Maul, Breakwater Plate, Breakwater Charm | You take 5% less damage for each enemy attacking you beyond the second, to 25% at most. |
| **Lamplighter's Vigil** (for a healer) | Vigil Crook, Vigil Habit, Vigil Lantern | An ally you heal hits 8% harder for 6 s. |
| **Wrecker's Due** (for a damage dealer) | Wrecker's Hook, Wrecker's Coat, Wrecker's Tally | When an enemy you have hit dies, you hit 6% harder for 15 s. It stacks five times, to 30%. |

All three reward pulling more at once, which is what a route is for.

## 3. Legendaries

- Three, in gold. Each is one named item for one slot. Its effect helps the whole party.
- As agreed: only one may be worn in a party, and a legendary has no item level of its own: it counts as the highest item level you own, plus 2. A legendary weapon or armour has 20% more of its stat.
- Proposed: you may **own all three**, and choose which the party wears. One you already own does not drop again.

| Legendary | Slot | Kind | What it does |
|---|---|---|---|
| **The Last Vesper Bell** | Trinket | Pressed, 3 minutes | Silences every cast in the fight, whoever is casting, and every enemy in the fight takes 25% more damage for 10 s. A cast that cannot be silenced is not. |
| **Tidecaller's Mantle** | Armour | By itself, once a fight | The first of the party to fall stands up again 3 seconds later, with half their health. |
| **The Undertow** | Weapon | By itself | For each pack in the fight beyond the first, the whole party hits and heals 6% harder, to 18% at most. |

## 4. What drops, and how often

Rarity keeps its hard edges by dungeon level, as agreed: epics and sets from level 7, legendaries from level 12.

- **A weapon or armour** from level 7: 35% common, 30% uncommon, 20% rare, 10% epic, 5% a set piece.
- **A trinket** from level 7: 5% a set trinket, otherwise one of the dungeon's five as now.
- **A set piece** is one you do not own yet, until you own all nine. Both dungeons give all three sets.
- **A legendary**: from level 12, each chest has a 2% chance to hold one in place of one of its items, and the chance rises by 1% with each chest that holds none. It goes back to 2% when one drops. Once you own all three, no more drop.
- **Unique** is on Lifelined armour only (and legendaries are one to a party by their own rule). The team editor refuses a second, saying why.

## 5. Coin and the shop

- **A run pays** 10 coin a dungeon level in the Abbey and 20 in Tollhaven, and half as much again if it was timed. Level 10 of the Abbey, timed, pays 150.
- **Selling**: an item sells for its item level, times 1 for common, 2 for uncommon, 4 for rare (so every trinket), 10 for epic and 15 for a set piece. A legendary cannot be sold. "Throw out" in the inventory becomes "Sell", and so does "Leave" in the chest.
- **The gamble**: you choose a slot and pay; you get one random item for it. Its item level is as a drop's (1 to 3 above your gear level), up to the ceiling of the highest level you have timed in either dungeon; its rarity has a chest's odds at that level. Never a legendary. A trinket may be any of the ten.
- **The gamble costs** 50 coin for each level of your highest timed level. At level 10 that is 500: about one gamble for every two runs, if you sell what you do not want.
- The shop is a panel on the Gear screen: your coin, and the three gambles.

## 6. Two trinkets that grow too fast

Measured in milestone 12: Garrow's Pitch Pot and Hask's Gutting Knife grow by a tenth of themselves each item level, while a weapon grows by a hundredth. At item level 23 a Ranger with the Pitch Pot dealt 160 damage a second against 121 without.

Proposed: halve what each item level adds to those two. The Pitch Pot goes from +4 to +2 a level, the Gutting Knife from +6 to +3. At item level 1 they are as they are now.

## 7. What is asked

1. The six epic abilities (section 1).
2. The three sets (section 2).
3. The three legendaries, and that you may own all three (section 3).
4. The odds, and that set pieces and legendaries do not drop twice (section 4).
5. Coin: what a run pays, what items sell for and what the gamble costs (section 5).
6. Unique on Lifelined armour only (section 4).
7. Slowing the Pitch Pot and the Gutting Knife (section 6).
