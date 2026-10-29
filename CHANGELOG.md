# Changelog

## v1.1.0

- New option: hide the interface on screenshots (off by default). The interface disappears for a split second; nameplates and names above heads stay visible.
- New option: emote after a kill. Pick one of 21 emotes; your character performs it at the victim right away, so the enemy sees it before releasing their spirit. At most one emote every 3 seconds. The shutter sound is off while an emote is selected.
- New chat messages, each off by default: your kills (including kills that gave no honor, and your pet's name if it landed the blow), kills made by your group members, and who killed you. Player names are shown in their class color.
- On Retail and WoW Forever the "who killed you" message depends on what Blizzard's death recap tells addons, so it may not appear there.
- The screenshot counter now remembers when it started counting. Counters from 1.0.0 show "start date unknown" until you reset them.
- The chat message with the screenshot number has been removed (the "Chat message" option and `/hsnap chat` are replaced by the new messages).
- Clicking the Addon Compartment button no longer prints to chat.
- New commands: `/hsnap hideui`, `/hsnap emote`, `/hsnap kills`, `/hsnap group`, `/hsnap deaths`, `/hsnap test`, `/hsnap debug`.
- New debug mode (checkbox at the bottom of the settings or `/hsnap debug`) for testing the addon: screenshots of any kill, technical details in chat, nothing is counted.
- Settings panel reorganized into two columns.
- README: a note at the top about when screenshots are taken, and a reworked FAQ.

## v1.0.0

- First release.
- Screenshot on honorable kills in the open world (battlegrounds, arenas and instances are ignored).
- Duels and active world battlefields are ignored.
- "Only my killing blows" option (on by default), adjustable delay, optional shutter sound and chat message (both off by default).
- English, Ukrainian and Russian localization with a language switch in the options.
- Options panel with buttons to reset the screenshot counter or all settings, `/hsnap` slash commands and Addon Compartment button.
- Supports Retail, WoW Forever, Classic Era / SoD / Hardcore, TBC Anniversary, Titan Reforged, MoP Classic.
