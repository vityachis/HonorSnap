# HonorSnap

![HonorSnap](Media/logo.png)

**Never lose a world PvP highlight again.** HonorSnap takes a screenshot every time you get an **honorable kill in the open world**: ganks at the Crossroads, Tarren Mill vs Southshore, or someone who tried to stop you in Stranglethorn.

## What it does

- 📸 **Automatic screenshot** on every honorable kill.
- 🟢 **Honorable kills only.** The game only gives honor for enemies that are *not gray* to you (green, yellow, orange or red level), so killing low-level players gives no screenshot.
- ⚔️ **Real kills only.** A screenshot needs actual honorable-kill credit from the game, so duels never count. HonorSnap also stays silent during a duel and for a few seconds after it ends.
- 🌍 **Open world only.** Battlegrounds, arenas, world battlefields during an active battle (Wintergrasp, Tol Barad), dungeons, raids and scenarios are ignored, so your Warsong Gulch games won't fill up the Screenshots folder.
- 🗡️ **"Only my killing blows" option**, on by default: a screenshot is taken only when you or your pet landed the killing blow. Turn it off to count any honorable kill, including group kills.
- ⏱️ **Adjustable delay** (0 to 3 seconds) so the corpse hits the ground before the picture is taken.
- 🔊 **Optional camera shutter sound**, off by default. Turn it on in the options or with `/hsnap sound`.
- 💬 **Chat message** with the victim's name and screenshot number (off by default, so the addon stays silent in chat).
- ♻️ **Reset buttons** in the options: clear the screenshot counter or restore all settings to defaults (asks for confirmation first, saved screenshots are never deleted).
- ⚙️ **Easy on/off**: a checkbox in the options, a slash command, or a click in the retail Addon Compartment (minimap addon menu).
- 🌐 **English, Ukrainian and Russian interface**. By default the language follows your game client (Russian on Russian clients, English everywhere else) and can be switched in the options. Kill detection doesn't depend on the client language.

## Supported game versions

One download works in every current client:

| Game | Interface |
|---|---|
| Retail (Midnight) | 12.x |
| WoW Forever | 1.60.x |
| Classic Era, Season of Discovery, Hardcore | 1.15.x |
| Burning Crusade Classic (Anniversary) | 2.5.x |
| Titan Reforged (Wrath) | 3.80.x |
| Mists of Pandaria Classic | 5.5.x |

> On Retail and WoW Forever the combat log isn't available to addons, so the "only my killing blows" option uses Blizzard's `PARTY_KILL` event. On Classic clients it uses the combat log.

## Usage

Install it and play. The addon is **enabled by default**.

Settings: **Esc → Options → AddOns → HonorSnap**, or type `/hsnap`.

| Command | Action |
|---|---|
| `/hsnap` | Open settings |
| `/hsnap on` / `off` / `toggle` | Enable, disable or toggle the addon |
| `/hsnap kb` | Toggle "only my killing blows" |
| `/hsnap delay 1.5` | Set the delay before the screenshot (0–3 sec) |
| `/hsnap sound` | Toggle the shutter sound |
| `/hsnap chat` | Toggle the chat message |
| `/hsnap lang auto` / `en` / `ru` / `uk` | Change the addon's language |
| `/hsnap status` | Print current settings |

`/honorsnap` works as well.

Screenshots are saved by the game to the `Screenshots` folder in your WoW installation (for example `World of Warcraft\_retail_\Screenshots` or `World of Warcraft\_classic_era_\Screenshots`). The file format and quality are the game's own screenshot settings.

## How it works

HonorSnap doesn't guess player levels. It listens for the game's own honorable kill credit (`PLAYER_PVP_KILLS_CHANGED`, with `CHAT_MSG_COMBAT_HONOR_GAIN` and the session honorable-kill counter as a backup), checks that you are in the open world (not in an instance, battleground, arena, active world battlefield or duel), and calls `Screenshot()`. Several signals for the same kill result in just one screenshot.

## FAQ

**I killed a player and nothing happened.**
The kill probably wasn't honorable: the target was gray to you, was killed too many times recently (diminishing returns in Classic), or you weren't in the open world. On Retail, world PvP honor needs War Mode. If "only my killing blows" is on, someone else may have landed the final hit.

**Can it hide the UI in screenshots?**
No. Hiding the interface during combat would be blocked by the game. Press `Alt+Z` yourself if you want clean shots.

## Feedback

Bugs and suggestions: [GitHub issues](https://github.com/vityachis/HonorSnap/issues).

## License

[Apache License 2.0](LICENSE) © Viktor Chystiakov
