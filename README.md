<img src="assets/icon.svg" width="64" height="64" alt="">

# Forever Touch

Touch screen controls for **World of Warcraft: Forever**. Built for playing through DroidDeck on a Galaxy Z Fold 8, but it works on any touch device that sends taps to the game as mouse clicks.

```
 ┌──────────────────────────────────────────────────────────────┐
 │                                                       (≡)    │  ← menu: bags, spellbook, map…
 │                                                       (+)    │
 │                                                       (-)    │  ← camera zoom (hold to repeat)
 │                                          (11)   (6)          │
 │                                              (7)  (2)        │
 │   ╭─────╮                                  (8)  (3)  ²       │  ← tap the small number to
 │   │stick│  ← DroidDeck on-screen stick     (9) (4)           │     flip spell pages
 │   ╰─────╯     (run + A to jump)         (12) (10)(5) ( 1 )   │  ← big thumb button
 │              (Target) (Assist) (Clear)                       │
 └──────────────────────────────────────────────────────────────┘
```

## What you get

- **Spell wheel**: one big button plus 11 around it, sized for a thumb. It shows cooldown sweeps with numbers, range (red), out-of-mana (blue), stack counts, an auto-attack glow and proc glows.
- **Pages**: page 1 follows your main bar, so warrior stances, druid forms and rogue stealth swap automatically. Pages 2 and 3 can show any other action bar. Tap the small number on the wheel to flip pages, even mid-fight.
- **Tap to assign**: tap an empty **+** button and pick a spell, item or macro from a big grid. You don't need to drag from the tiny spellbook (though that works too). Classic rank spam is hidden by default, so you see the best rank only.
- **Menu**: a round button opens a tile grid for Character, Bags, Spellbook, Talents, Quests, Map, Social, Chat, Close windows, Edit layout, Touch settings and Game menu. It works in combat.
- **Target row**: Target nearest enemy, Assist and Clear, plus Pet attack for hunters and warlocks.
- **Edit layout**: drag the pink handles to move things, use + / − to resize, and change opacity. Tap any spell button to change it, or drag one button onto another to swap them.
- **Fold aware**: the folded (cover) screen and the unfolded (inner) screen each keep their own layout, and the addon switches between them when you open or close the phone.
- **Left-handed mode** mirrors everything.
- **Guided setup** on first login.

## Running and jumping: how movement works

Blizzard does not let any addon move or jump your character. That rule stops bots, and it applies to every addon. Forever Touch uses WoW's own controller support instead:

1. The setup guide turns on WoW's controller support (`GamePadEnable`) and binds **A = Jump**.
2. In DroidDeck, turn on the on-screen controls and keep the **left stick** and the **A** button.
3. In **Edit layout** (or setup step 2), a pink circle shows where to put the stick so it doesn't overlap the spell wheel.

This gives smooth analog running, not a click-to-move workaround. If the stick moves the mouse instead of your character, set the game's Steam Input layout to **Gamepad**.

**Camera:** drag one finger across empty ground. **Zoom:** pinch (if DroidDeck maps it to the mouse wheel) or use the + / − buttons.

Optional **tap-to-move** (WoW's click-to-move) is in setup step 2. It needs a right-click, so map DroidDeck's long-press to right click.

## Install

1. Download or build `ForeverTouch-<version>.zip` (`python3 tools/build.py` writes it to `dist/`).
2. Copy the `ForeverTouch` folder into the game's AddOns folder: `World of Warcraft/<forever game folder>/Interface/AddOns/`. Under DroidDeck, this is inside the Windows drive of the prefix where you installed Battle.net.
3. On the character screen, open **AddOns** and make sure Forever Touch is ticked.
4. Log in. The setup guide opens after a couple of seconds.

### If it says "Out of date"

The TOC lists Interface `16001, 16000, 11508`, which is a best guess for WoW: Forever 1.60.x. If the addon shows as out of date, either tick **Load out of date AddOns**, or find your client's number in game with:

```
/dump (select(4, GetBuildInfo()))
```

then run `tools/set-interface.sh <number>`.

## Commands

| Command | What it does |
|---|---|
| `/ft` | Touch settings |
| `/ft edit` | Edit layout (move, resize, assign spells) |
| `/ft setup` | Run the setup guide again |
| `/ft reset` | Reset the current screen's layout |

The settings are also under **Options → AddOns → Forever Touch**.

## Recommended settings (offered in setup)

- **Tap to interact**: one tap talks to NPCs, loots and opens objects.
- **Auto loot**
- **Cast the moment you touch**: casts on finger-down instead of on release.
- **Cooldown numbers**
- **Hide default action bars**: Forever Touch replaces them. The XP and pet bars stay. Turning this off again needs `/reload`.

Each one is shown only if your client has the setting.

## Limits worth knowing

- **One finger at a time?** That depends on DroidDeck. Touches on its on-screen stick are handled separately, so you can run with one thumb and cast with the other. Two taps on WoW buttons at the same moment arrive as a single mouse, though.
- Buttons can't be rearranged or reassigned **during combat**. Blizzard locks secure buttons then. Casting, page flips and the menu all work in combat, and edit mode closes automatically when a fight starts.
- Folded/unfolded auto-switching reads the game's screen size. If DroidDeck runs the game at a fixed resolution, choose **Folded** or **Unfolded** in settings yourself.

## Development

```
sh tests/run_all.sh        # syntax check + mock-client test suite (Lua 5.1)
python3 tools/build.py     # package dist/ForeverTouch-<version>.zip
python3 tools/make_textures.py   # regenerate media/*.tga
```

`tests/mock_wow.lua` is a small fake WoW client. It models frames, secure snippets, state drivers (stance paging), wrapped clicks and **combat lockdown**: any insecure change to a protected frame during combat fails the run with `ADDON_ACTION_BLOCKED`. The suite runs in all three click modes: cast on press, cast on release, and legacy clients.

| File | Purpose |
|---|---|
| `Core.lua` | Saved settings, events, combat-safe queue, Fold screen profiles |
| `Widgets.lua` | Round buttons with press/ripple feedback, panels, toggles, steppers |
| `ActionCluster.lua` | Secure spell wheel, paging, cooldown/range/proc visuals |
| `Utility.lua` | Target row and camera zoom |
| `Menu.lua` | Secure tile menu |
| `SpellPicker.lua` | Tap-to-assign grid for spells, items and macros |
| `EditMode.lua` | Move/resize/assign mode and the stick placement guide |
| `Setup.lua` | First-run guide, controller movement, recommended settings |
| `Settings.lua` | Settings panel, options entry, slash commands |
