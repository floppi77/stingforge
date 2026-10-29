# Stingforge – Quick Guide

[Deutsch](HANDBUCH.md) · *English*

A modern horizontal shoot ’em up. You fly Yuri, a field bee, through ten realms
against steel, spores and machines. Everything you need to play is on this page.

---

## 1. Getting started

**Windows:** double-click `Stingforge.exe`. No installation needed.
**Linux:** run `Stingforge.x86_64` as a program (if necessary, first
`chmod +x Stingforge.x86_64`). No installation either.
**macOS:** unzip `Stingforge-macOS.zip` and drag `Stingforge.app` into “Applications”.
The app is not notarised by Apple: on first launch, right-click it in the Finder › “Open”.

The programs contain all data (graphics, music, levels) in a single file.
On first launch the game creates a save folder:

* Windows: `%APPDATA%\Godot\app_userdata\Stingforge\`
* Linux: `~/.local/share/godot/app_userdata/Stingforge/`
* macOS: `~/Library/Application Support/Godot/app_userdata/Stingforge/`

It contains the subfolder `saves` with `settings.save`, `profile.save` and
`campaign.save` plus their `.bak` backups. On first launch, existing files from
the earlier folder **Apidya Reimagined** are imported without overwriting old
originals or Stingforge files that already exist.

---

## 1a. The main menu

The golden title sits on the left in front of the bee-and-ruins artwork. Below it:
*Continue* (with your current level), *New Run*, *Tutorial*, *Boss Rush*,
*Highscores*, *Fusions*, *Settings*, *Credits* and *Quit Game*. Below the menu you
choose the language with the flags (German or English).

- **Tutorial:** a short training flight in the first world.
  - At every new step the game pauses and a small picture window explains it:
    flying, firing, collecting pollen, the weapon bar with LB/RB or Q/E and its costs,
    buying and levels, return fire, shield and bomb, the conversion at the end of a
    level, the workshop and the highscore.
  - It is offered the first time you start a run. Your save is not touched.
- **Fusions:** shows every pair of evolutions that grow stronger together.
  Pairs you have not discovered yet are greyed out.
- **Workshop:** it only opens between levels.
Only the selected row glows gold. Locked entries show a padlock;
without a save, *New Run* is preselected.

The transparent card at the bottom right shows your current level and the
difficulty of the saved run, unlocked evolutions, available workshop points and
the best score from your profile. Keyboard and Xbox hints sit together at the
bottom left. At the default font size every entry fits without scrolling; with a
larger font, the list scrolls to the selected entry.

## 2. Controls

### Keyboard

| Action | Key |
|---|---|
| Fly | `W` `A` `S` `D` or arrow keys |
| Fire (hold = continuous fire) | `Space` |
| Autofire on/off | `R` |
| Weapon bar left / right | `Q` / `E` |
| Buy or activate the selected entry | `F` |
| Precision flight (slow, fine dodging) | `Left Shift` |
| Pause in game / back | `Esc` |
| Confirm in menus | `Space` or `Enter` |

### Mouse

Every menu can also be used with the mouse: moving the pointer over an entry
highlights it, a **left click** triggers it (toggles and sliders step on), the
**mouse wheel** moves the selection. The mouse is not needed during play.

### Controller (Xbox layout, other layouts are recognised)

| Action | Button |
|---|---|
| Fly | Left stick or D-pad |
| Fire (hold = continuous fire) | `A` |
| Autofire on/off | `X` |
| Weapon bar left / right | `LB` / `RB` |
| Buy / activate | `RT` |
| Precision flight | `LT` |
| Pause / back | `Start` or `B` |

Holding fire is **always continuous fire** – there is no charge shot.
`RT` triggers exactly one purchase per press (hysteresis: fires above 60 %, re-arms
only below 30 %), so a fully pressed trigger never buys several entries. After every
change of context (menu → game, pause → game) the confirming button must be released
first; it does not carry over into the new context.

Every key and controller button can be rebound under **Controls** in the settings;
dead zone, sensitivity and vibration are adjustable there too.

**Keyboard and Xbox are always shown together**, even without a controller
connected. In the binding overview they appear in separate columns. Keyboard keys
are square plates, the Xbox buttons A/B/X/Y coloured circles; LB/RB and LT/RT are
capsules. When you browse the weapon bar with LB/RB (or `Q`/`E`) the selected upgrade
is announced, e.g. “Lightning”. This can be turned off under Settings › Audio. The
hints always show your current bindings, not just the defaults. `D` stands for the
D-pad and `LS` for the left stick. A larger font wraps the footer and stacks the two
device types in the binding overview.

---

## 3. The screen

* **Top:** a separate, opaque instrument band (40 of 540 rows) with gauges for
  **vitality**, **shield**, **pollen** and **points**; label and value sit side by
  side. The flyable area starts below it; enemy bodies and your bee always stay
  outside the HUD. Filled and empty shield icons show charges, a bar shows the
  recharge time. Points use thousands separators.
* **Top right:** compact hints for autofire and pause, each with the current
  keyboard and Xbox binding.
* **Bottom:** the tactical weapon bar with nine entries on its own dark strip.
  **This area is not part of the playfield** – the bee, enemies and projectiles end
  at its top edge (row 496 of 540), so nothing invisible happens underneath. The
  highlighted entry is bought with `RT`/`F`. The line above it names cost and effect.
* **Progress bar:** in the thin line below the gauges, a bar shows how far the level
  has progressed towards the boss. Diamonds mark the checkpoints (filled = reached),
  a red triangle the miniboss, the golden diamond at the end the boss. Next to it is
  the estimated remaining time (“Boss in 1:24”), later “Boss approaching” or “Boss
  Fight”. Only played seconds count – pause, death and grace periods stop it. In the
  Boss Rush the bar shows “Boss 3 / 10” instead.
* **Ultrawide:** on 21:9 and 32:9 the playfield stays 16:9; the level scenery
  continues dimmed on the left and right. The HUD bands span the full width.
* **Minibosses** stay on the field until they are defeated and lunge to the left at
  regular, announced intervals.
* **Boss fight:** name, health bar, phase and armour state are shown in the thin
  line of the top instrument band, not over the active field.
* **Boss contact:** the visible body and living modules hurt on contact. You may fly
  through transparent sprite corners; weak phases and armour still affect the damage
  your weapons deal.
* **Enemy fire:** on Relaxed 60 %, on Normal 80 % and on Expert all projectiles get
  through (see section 7). Bright, white-hot projectiles with a dark rim and a soft
  halo – their shape stays still (nothing flashes), so they stand out immediately even
  on colourful backgrounds.
* **Pause:** `Esc` or `Start` opens the pause menu at any time (Continue, Restart at
  Checkpoint, Settings, Build Overview, Main Menu, Quit Game). The game world stops
  completely – also when the window loses focus or the controller disconnects. The
  paused scene stays visible behind a translucent veil; a status column on the right
  shows level, progress bar, vitality, pollen, points and play time. After continuing
  you get a short grace period.

---

## 3a. Depth: parallax and lighting

The background consists of **five layers** that scroll at different speeds – from
almost static haze in the distance to dark blades of grass right in front of the
playfield. This makes it feel like you are really flying rather than fighting on the
spot. The layers tile seamlessly and take on the colours of each level.

On top lies **subtle lighting**: soft light falling from above and a slight darkening
of the edges (vignette). Pickups have a soft glow so that pollen and hearts catch your
eye immediately. All of this stays subtle and can be turned off under
**Settings → Graphics → Lighting & Shadows**.

**Your own shots are cool-coloured** (white with an ice-blue rim), pollen and nectar
blossoms are warm gold and glow. That way it is clear at a glance what belongs to you
and what you can collect – even when the screen is busy.

## 4. Weapon bar (tactical, paid with pollen)

Enemies drop pollen and it also lies in blossoms. It stays with you across
checkpoints – **until the end of the level**: there the rest is converted into points
in the middle of the screen (**10 points per drop**), with a counter and sound. The
next level starts with 0 pollen; the points remain.

| Entry | Effect | Levels |
|---|---|---|
| Basic Shot | two precise stinger shots, always available | 1 |
| Spread Shot | 4/5/6 stingers, largest hit area; with Orbit staggered rings, with Wave a broad wave band | 3 |
| Lightning Gun | fast orbs (level 1/2/3: two, three, four); a hit jumps to the nearest enemy (66 % damage) and from there to the next (33 %) | 3 |
| Plasma Gun | slow, high damage, little spread (about a quarter of the Spread), area effect | 3 |
| Companions | automatically firing drones | 3 |
| Bombs | trigger **by themselves** every few seconds, releasing a shockwave around the bee that erases projectiles and hits enemies (higher level = more often) | 3 |
| Shield | absorbs hits and recharges | 3 |
| Flight Speed | higher speed; buying it again lowers it | 3 |
| — | *Wind and currents* push with at most 62 % of your flight speed; **steering against them always still gets you forward** | — |
| Repair | one life back; free at full health | 1 |

The bar shows **short names** (Basic, Spread, Lightning, Plasma, Drone, Bomb, Shield,
Speed, Repair). Entries you **cannot afford right now stay grey** – readable, but
without glow. As soon as you have enough pollen, frame, name and price turn gold; then
pressing `RT`/`F` pays off. Trying to buy an entry that is already at its highest
level is answered with “Maxed out!”.

**Shield:** buy it tactically first. Level 0 has no shield at all; levels 1/2/3 have
exactly 1/2/3 charges. A hit uses up a charge, not the purchased level. A missing
charge grows back after about twelve seconds; the workshop and Bastion speed this up
(and the difficulty changes it, see section 7). The workshop alone does not unlock a
shield or raise its capacity. One to three counter-rotating honeycomb rings around
the bee show the current charges.

You switch between purchased weapons by activating the entry with `RT`/`F` – buying
and activating use the same button, and the level is **not** raised.

**Every new level starts without tactical extras.** All eight purchased extras drop
back to 0; only the free basic weapon stays at level 1. Pollen is still converted into
points, not destroyed by the reset. Workshop upgrades and evolutions stay; you rebuild
the tactical bar for each level.

**A Game Over also resets the bar** – Basic at level 1, all other tactical purchases
and pollen at 0. What you bought in the workshop and which evolutions you own is not
affected (see section 6b).

---

## 4a. Choosing an evolution at the end of a level

After every level (including the tenth) **three cards appear side by side**, without
scrolling:

* **A/D**, **arrow left/right** or **stick left/right** choose between the three cards.
* **S** or **arrow down** moves to the *Reroll offers* row – you may reroll once per
  level.
* **Space** or **A** confirms the highlighted card, **Esc/B** goes back. The mouse
  works directly as well.

Right before that, the game converts your remaining pollen into points.

## 5. Evolutions (permanent)

After **every** level – including the tenth – you choose **exactly one** evolution
from **three** offers. There are 36 of them in six families (Stinger, Swarm, Pollen,
Chitin, Resonance, Nectar). Once per level completion you may **reroll** the three
offers; the decision itself cannot be skipped.

* Every new run offers **three randomly drawn starting talents** from a pool of 20,
  ideally from three different families.
* Further talents are **profile unlocks**: they appear in the pool but only take
  effect in a running run.
* Evolutions that need a particular weapon are marked in the offer and stay
  **inactive** until you have bought that weapon – they come back to life as soon as
  you own it.
* Rewards are never given twice: levels that were already rewarded do not give a
  second evolution when replayed.
* Matching evolutions **fuse** and both grow stronger; the main menu lists every
  fusion you have discovered.

---

## 5a. Workshop (points, permanent)

After choosing an evolution and the level summary, the **workshop** opens. There you
spend **points** – not pollen – on permanent upgrades. They last for the whole run and
stack with everything else. Points you spend are deducted from your highscore.

* **32 upgrades in five groups**: Shot Pattern, Impact, Speed, Protection, Yield.
* **Every upgrade has three levels.** Levels 2 and 3 are not just percentages but
  change how you play: with *Orbit* the shots circle the bee first at a medium, then
  at a large radius and finally faster; with *Wave Shot* they fly in a wave that the
  extra upgrades *Wide Waves* and *Fast Waves* shape further.
* **Homing** only works at close range (about a quarter of the screen width) and
  corrects the path only slightly. *Strong Homing* can only be bought once *Homing*
  is at level 3.
* **Richer Loot** gives each enemy a 15/20/30 % chance of dropping one more pollen.
* **Chains**: some upgrades only unlock once their predecessor is bought – *Fast
  Waves* and *Wide Waves* need *Wave Shot*, *Armour Breaker* needs *Heavy Rounds*,
  *Strong Homing* needs *Homing* level 3. Locked entries are grey and name their
  requirement.
* **Combinable flight patterns**: *Orbit*, *Wave Shot* and *Homing* can be bought
  together. Orbiting shots stay spatially separate; waves modulate their path and
  homing still works. *Spiral Shot* stays effective too.
* **Shared weapon profile**: extra shots take on the active weapon: Plasma keeps its
  area damage and punch, Lightning its chain effect. Limited counts and salvo spacing
  still prevent a new flood of bullets.
* **Three columns:** on the left the **categories**, in the middle the **upgrades** of
  the selected category, on the right the **description with a small animated scene**
  showing what the effect does in the game – the shot path, shield or loot at the
  strength of the next level. Below it are the price, the effect of the next level
  and what you already have.
* **Prices**: first levels 2,500–6,000 points, second 5,500–13,000, third
  10,000–24,000. Depending on how carefully you play, a level earns about
  15,000–35,000 points – so a first level is affordable after *one* level, the third
  needs saving up. Buying everything at once is deliberately impossible.
* **Controls**:
  * `W`/`S` or the stick choose the category, and the middle column immediately shows
    its upgrades.
  * **Space/A** or `→` jumps into the list. There **Space/A** buys, `←` or `Esc/B`
    returns to the categories.
  * **Continue** sits at the bottom of the category column. `Esc/B` in the categories
    also leaves the workshop.
  * With the mouse, hovering shows the category or upgrade, a click buys.

<details>
<summary>All 32 workshop upgrades at a glance</summary>

**Shot Pattern** – Orbit, Wave Shot, Fast Waves, Wide Waves, Rear Stinger, Side
Stingers, Twin Barrels, Spiral Shot, Homing, Strong Homing

*Rear Stinger*, *Side Stingers* and *Twin Barrels* give **a limited number of extra
shots** (two backwards, two to the sides, one extra barrel). Their last levels
therefore do not raise the bullet count but the **power** of these shots. The screen
stays readable and the purchase still pays off.

**Impact** – Piercing, Splinter Cloud, Chain Lightning, Heavy Rounds, Critical Hit,
Splinter Core, Armour Breaker

**Speed** – Rapid Fire, High Velocity, Salvo

**Protection** – Shield Recharge, Shield Stability, Extra Life, Afterburner, Bomb
Radius, Bomb Depot

**Yield** – Pollen Magnet, Richer Loot, Graze, Streak, Better Exchange, Fresh Nectar

</details>

---

## 5b. Boss announcement

Shortly before a level boss appears, the screen shakes, flashes white, a large
**BOSS** appears above the action and a warning sound plays. In that second the field
is already cleared (no enemy bullets, no waves) – the boss itself only arrives
afterwards. Minibosses still only show their name in the middle of the screen.

**Phase changes with a grand entrance**:
* **Before the banner:** when a boss reaches its next phase, the game pauses briefly
  (less than a second). The boss glows and pulses, shockwave rings run across the
  field and the flying enemy bullets burst. The screen flashes red, shakes hard and a
  roar sounds.
* **Banner:** a large band **PHASE II** (or III) with a line about the boss runs
  across the screen – and what it announces really happens.
* **Afterwards:** the boss glides from its position into the new movement pattern and
  stays visibly angrier in colour.

---

## 6. Game modes

* **New Run** – ten levels with cutscenes, minibosses and a final battle. Takes about
  60–90 minutes. There is a checkpoint before every boss.
* **Continue** – resumes from the last checkpoint of the saved run.
* **Boss Rush** – every boss you have already beaten in the current run, one after
  another, with a copy of your current build. The run itself stays unchanged; without
  a running run, or before your first boss victory, the entry is locked.
* **Settings**, **Credits**, **Quit Game**.

In the main menu `Esc` does **not** quit the game – use the *Quit Game* entry, which
asks for confirmation. In the pause menu both quit entries really quit and save first.

**Pause menu:** Continue, Restart at Checkpoint, Settings, Build Overview, Back to Main
Menu, Quit Game. `Esc`/`Start` resumes the game – also from within the settings.

---

## 6a. The ten bosses

Every boss has its own music (it only starts when the boss appears), its own movement
pattern and its own attacks:

| Level | Boss | Movement | Special |
|---|---|---|---|
| 1 | Armoured Rose Chafer | pendulum path | the shell folds open, then the back is vulnerable |
| 2 | Burrowing Giant Larva | burrows in and breaks through elsewhere | head unprotected after breaking through. Pillars of earth while tunnelling, cave-in with a free gap, larva brood; three phases |
| 3 | Reed Pike | dashes along a lane | lunge, then a short recovery |
| 4 | Parasitic Fungal Mind | drifts in a wide circle | releases spore clouds that fog your view |
| 5 | Mantis Pair | two bodies, quick switches | both halves must fall |
| 6 | Mechanical Pollinator | circles an anchor point | armour phases alternate with mirror volleys |
| 7 | Mutant Pond Skater | glides along a lane | water mechanic: the current pushes you along |
| 8 | Insectoid Harvester | dashes back and forth | scan line, then a barrage |
| 9 | Swarm Queen | figure-eight | summons guards, spiral fire |
| 10 | Core Organism | first form, then rebirth with three phases of its own | new shape, 175 % of the first form's max HP, shorter attack pauses |

**Behaviour and health rise with every level.** On top of each boss's own base values
there is an independent boss HP factor that grows to about 2.53 on level 10. The
sub-linear weapon adjustment never takes the gain of your upgrades away completely.
The threat tier also rises (1 to 5):

| Tier | Levels | What gets added |
|---|---|---|
| 1 | 1–2 | basic behaviour, one movement pattern |
| 2 | 3–4 | shorter pauses between attacks |
| 3 | 5–6 | an extra final phase with the toughest pattern |
| 4 | 7–8 | every phase gets a second pattern, the boss changes movement every 7.5 s |
| 5 | 9–10 | two extra patterns in the final phase, a denser rhythm, faster bullets |

In addition, the attack rhythm shortens with the level by up to 38 %, enemy bullets
get up to 31 % faster, and the boss music rises from 150 to 196 BPM.

## 6b. Game Over and continuing

When you die, the death display runs for two seconds, then the **Game Over screen**
appears. It offers two paths:

| Entry | Effect |
|---|---|
| **Continue at Checkpoint** | The run continues at the last checkpoint. **The tactical upgrades on the bottom bar start over** (purchased extras 0, free Basic 1, pollen 0). Workshop purchases and evolutions remain. |
| **End Run** | The run is over and deleted, and you return to the main menu. Everything in your profile (evolutions, best scores, unlocked levels) stays. The menu then shows “Run ended – the evolutions in your profile are kept.” and **Continue is locked**. |

**Three attempts per run.** The screen shows “Game Over 1 of 3”. After the third Game
Over there is **no continue** – only “To Main Menu” remains and the run is over. The
counter applies to the whole run and resets with a new run.

Why the reset: the bar is the *tactical* layer – a build-up that grows and fades within
a level. The workshop is the *permanent* layer you pay for with points across the whole
run. A continue that kept both would turn death into a mere time penalty; a continue
that erased both would burn points you paid for. Kept apart, both make sense.

---

## 7. Difficulty

The three levels differ in much more than lives:

| | Relaxed | Normal | Expert |
|---|---|---|---|
| Lives | 4 | 3 | 3 |
| Enemy projectiles that get through | 60 % | 80 % | 100 % |
| Projectile speed (bosses too) | 0.85× | 1.0× | 1.18× |
| Fire rate of regular enemies | 0.75× | 1.0× | 1.35× |
| Number of enemies | 0.8× | 1.0× | 1.25× |
| Pauses between boss attacks | 25 % longer | normal | 18 % shorter |
| Boss health | 0.8× | 1.0× | 1.15× |
| Hit damage | every fifth hit is forgiven | 1 per hit | about every third hit costs 2 |
| Invulnerability after a hit | 1.9 s | 1.3 s | 0.95 s |
| Shield recharge | 35 % faster | normal | 30 % slower |
| Score multiplier | 0.7× | 1.0× | 1.4× |

All ten levels and the ending can be played on every difficulty.

---

## 7a. Why the enemies keep up

Stronger weapons lead to a **sub-linear**, never complete adjustment of the enemies.
More damage is allowed to shorten kill times within the same level. Evolutions are not
neutralised by flat health increases. Wider salvos, piercing, chain lightning and area
damage help additionally against whole waves.

Independently of this, the **level pressure** grows: on level 10 up to 1.90× enemy
health, 2.53× boss health, 1.45× spawn rate and 1.36× fire rate. That is the additional
level factor, not the absolute health of each individual boss.

Bullet counts and cascades stay limited so that upgrades remain combinable without
covering the playfield.

## 7b. Highscores

**Highscores** in the main menu shows local leaderboards: Run and Boss Rush separately,
filterable by difficulty, as Top 10 or Top 20. What counts are the total points earned
**minus workshop spending**: anyone who invests points in permanent upgrades grows
stronger but lowers their highscore. The conversion bonus for pollen counts exactly once.

Entries are created at the final Game Over, when you explicitly end a run, or on
victory. Continues remain the same run. Old level bests are never added up into
invented run totals. Estimates from a continued old run carry an asterisk.

---

## 8. Settings

Six categories, reachable with `LB`/`RB` or `Q`/`E`:

* **Display** – monitor, resolution, window/borderless/fullscreen, V-Sync, frame rate
  limit, scaling, UI size.

  **How to change the resolution:** cycle monitor, resolution and window mode with
  **left/right** (A/D, arrow keys, stick). The new value appears in the row right away
  with a **•** after it – it is not applied yet. Press **Space or A** on one of these
  rows (or on *Apply Display* right below) to apply the change. The game then asks for
  15 seconds *“Keep display settings?”*: **A/Space** keeps them, **B/Esc** restores the
  previous display, and without an answer it reverts automatically.

  Only resolutions that fit the connected monitor are offered – so the list may be
  shorter depending on your screen. The resolution applies in windowed mode;
  borderless and fullscreen follow the monitor. V-Sync, frame rate limit, scaling and
  UI size apply immediately.
* **Graphics** – effects, particles, screen shake, flashes, post-processing
  (vignette), **Lighting & Shadows** (light from above), optional CRT filter (tube
  look with scanlines and shadow mask over the game and the menus).
* **Audio** – master, music, effects and UI separately; mute when the window loses
  focus; voice announcements.
* **Controls** – key bindings for keyboard and controller, dead zone, sensitivity,
  vibration (hits, bombs, boss phases) and its strength.
* **Game** – language (German/English, also via the flags in the main menu), autofire
  by default, tutorial hints (controls in the first level, the training-flight offer),
  hitbox display. The difficulty is chosen only when starting a run or the Boss Rush
  and stays fixed for the whole run.
* **Accessibility** – font size, reduced effects, high-contrast marking of dangerous
  objects.

Every category has **Restore Defaults**. Audio and game changes are applied when you
leave the category, display changes only with **Apply Display** (or when you leave the
settings with Esc).

---

## 8a. Fonts

The game ships its own fonts and does not rely on system fonts:
**Jersey 10** for headings and large numbers, **Silkscreen** for small-caps labels,
**Pixelify Sans**, **Nunito** and **Oxanium** for body text and descriptions.

All are licensed under the SIL Open Font License (the licence texts are in the folder
`assets/ui/fonts/`). The font size can be changed in steps under **Settings →
Accessibility → Font Size**; every screen scales along.

---

## 9. Troubleshooting

* **Black screen after changing the display:** wait 15 seconds – the change is reverted
  automatically.
* **No sound:** check under Audio whether one of the four groups is set to 0. The game
  mutes itself when the window loses focus (configurable).
* **Controller not recognised:** connect the controller and restart the game; the
  Controls section shows the detected device.
* **Reset your save:** delete `settings.save`, `profile.save` and `campaign.save` (with
  their `.bak` files) in the `saves` subfolder of the folder named above.

Good luck – the core is waiting.
