# Proposal: levels and basic gear

Status: **a proposal for the owner to approve, written on 16 November 2026. Nothing here is built.** It is the first step of milestone 12 in [`routing-and-gear-plan.md`](routing-and-gear-plan.md), which says the owner approves the named items and the open numbers before any of it is made. What was already agreed there is not asked again; this fills in what was left open.

Milestone 12 is levels and basic gear: fast clears and records, the end chest, weapons, armour and trinkets up to rare, item level and its ceiling, the inventory, teams, the new start screen, the gear keys, and saving the save to a file. Epic abilities, sets, legendaries, coin and the shop are milestone 13 and are not proposed here.

## 1. What an item level is worth

- **Weapon**: +1% damage and healing for each item level.
- **Armour**: +1% health for each item level.
- **Rarity** adds a share of that, as agreed: uncommon 5% more, rare 10% more. A rare weapon of item level 20 gives +22%.
- An item says what it does in those words: "+22% damage and healing". No other numbers.

## 2. The ceiling, and how drops climb

- **Ceiling**: each dungeon level allows items up to item level 2 + 3 × the level. Level 1 drops up to 5, level 5 up to 17, level 10 up to 32.
- **Your gear level** is the average of the best weapon and the best armour you own. With nothing, it is 0.
- **A drop** is 1 to 3 item levels above your gear level, and never above the ceiling. At the ceiling, drops come at the ceiling: more copies for the rest of the party, but no higher.
- Both dungeons use the same ceiling for the same level.

What that does to difficulty, with every slot at the ceiling:

| Dungeon level | Enemies, against level 1 | Gear at the ceiling | It then feels like today's level |
|---|---|---|---|
| 1 | ×1.00 | +5% | 1 |
| 5 | ×1.36 | +17% | 3 |
| 10 | ×2.00 | +32% | 6 |
| 15 | ×2.94 | +47% | 10 |
| 20 | ×4.32 | +62% | 14 |

Enemies grow by a share each level and gear by a fixed step, so gear carries a party a few levels further and then the levels win again. Today the AI starts to lose at about level 9 or 10; with full gear that moves to about 15.

## 3. The end chest

- Two items for finishing, three for finishing in time, as agreed.
- **Slot**: 40% a weapon, 40% armour, 20% a trinket from that dungeon's five.
- **Rarity** of a weapon or armour: at dungeon levels 1 and 2, 70% common and 30% uncommon. From level 3, 50% common, 35% uncommon, 15% rare. Trinkets are always rare.
- The chest is a screen after the summary. Each item is taken or left. With no shop until milestone 13, an item that is left, or thrown out of the inventory, is gone; from milestone 13 it sells for coin instead.
- The inventory holds 60 items. A full inventory must have something thrown out before more is taken.
- A run the AI played for you (F9) gives no chest.

Generated names, so that two items can be told apart: the Abbey's weapons and armour are named from its world ("Sexton's Hook", "Choir Cassock") and Tollhaven's from its own ("Chandler's Maul", "Tarred Coat"). The name is for show; item level and rarity are all that count.

## 4. The ten trinkets

Five to a dungeon. Each boss has one, and each dungeon has others that are nobody's. A trinket either is pressed, on a long cooldown, or works by itself. The number in each grows with item level. No trinket needs a role, so none carries a tag.

**The Drowned Abbey**

| Trinket | Kind | What it does at item level 1 | Each item level adds |
|---|---|---|---|
| **Krogg's Great Key** | Pressed, 90 s | You take 30% less damage for 8 s. | +0.5%, to 50% at most |
| **Velisse's Thimble** | By itself, once a minute | When you fall below 35% health, you are healed for 20% of your health. | +0.5% |
| **Sulmar's Bell Rope** | Pressed, 120 s | Everyone in the party hits and heals 10% harder for 10 s. Two ropes do not add up. | +0.3% |
| **Brineling Shell** | By itself, every 20 s | A shield that soaks 150 damage. | +10 |
| **Cantor's Tuning Fork** | By itself | After you silence a cast, you hit and heal 15% harder for 8 s. | +0.5% |

**Tollhaven**

| Trinket | Kind | What it does at item level 1 | Each item level adds |
|---|---|---|---|
| **Hask's Gutting Knife** | By itself | Every sixth hit or heal of yours lands again for 60. | +6 |
| **Corrow's Seal** | Pressed, 45 s | Silences your target's cast. It gives a healer a silence. | 0.5 s off the cooldown, to 25 s at least |
| **Garrow's Pitch Pot** | Pressed, 60 s | Burning pitch on your target and every enemy within 5 m of it: 40 damage a second for 8 s. | +4 |
| **The Keeper's Lens** | Pressed, 90 s | Your next three hits or heals are half again as strong. | +1% |
| **Tide Glass** | Pressed, 120 s | Refills 30% of your mana, focus or whatever your hero spends. | +1%, to 60% at most |

AI teammates use a pressed trinket by themselves: the Key when badly hurt, the Bell Rope, the Pitch Pot and the Lens on a boss or a big pull, the Seal when a cast is theirs to stop, the Tide Glass when they run low.

## 5. Keys

- Three gear keys, one a slot: **Z** for the weapon, **X** for the armour, **C** for the trinket. They can be changed like any other key.
- Three small buttons beside the action bar show them. A slot with nothing to press has no button. In milestone 12 only trinkets are pressed; weapons and armour get abilities with epics, in milestone 13.

## 6. Teams

As agreed. Two things the plan left to be said:

- **The default team** gives the best items to the hero you play, then the tank, then the healer, then the other damage dealer.
- **Trinkets on the default team**: your hero wears your highest trinket, and the others wear what is left, highest first.

## 7. Fast clears and records

As agreed: finishing 20% inside the time opens two levels up, and 40% inside opens three. In the Abbey that is 11:12 and 8:24; in Tollhaven, 20:00 and 15:00.

- The dungeon panel of the start screen shows, for the level chosen, the best time and the team that set it.
- The records kept for each dungeon are the highest level timed and, for each level, the best time with its four heroes and which of them was played.

## 8. Keeping the save

In the settings: "Save to a file" downloads the save as a text file (in the browser) or writes it beside the game (on a desktop), and "Load from a file" takes one back, after asking, since it replaces everything.

## 9. What is asked

1. The worth of an item level (section 1).
2. The ceiling and how drops climb (section 2).
3. The chest: its odds, and that an item left is gone until the shop exists (section 3).
4. The ten trinkets (section 4).
5. The gear keys (section 5).
6. Who the default team gives its best to (section 6).
