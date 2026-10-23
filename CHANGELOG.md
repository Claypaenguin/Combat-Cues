# Changelog

Each release's notes on GitHub come from its section here. Add a section for a version
before tagging it, or the release build stops with an error.

## [1.1.0] - 2026-10-23

### Added
- **Healer low mana indicator**: shows "Healy low on mana!" (with the healer's name) while your group's healer is at or below
  a mana threshold you choose (20% by default), and hides it again once they're above it.
  - On/off toggle, adjustable threshold, and an "Only inside dungeons" option.
  - Its own font, outline, size and position, like the other alerts.
  - Uses group roles, so the healer needs the Healer role (automatic with the Dungeon Finder).
  - No sound: WoW Forever hides mana values from addons, so the game itself decides when the text is
    visible, and the addon can't react to it with a sound.
- **Solo test mode** for the healer indicator: treats you as the healer while you're not in a group.
- `/ccues test healer` to preview the healer indicator.
- `/ccues debug` and `/ccues readout` to troubleshoot the healer indicator.

### Changed
- The settings window now scrolls, to make room for the healer section.

## [1.0.0] - 2026-10-21

### Added
- **Combat text**: "+ Combat" / "- Combat" fades in and out when you enter or leave combat.
  The texts are editable.
- **Party death alert**: "Tanky died!" (name in their class color) when someone in your 5-player group dies,
  with an optional alarm sound. Options to include yourself and to only alert inside dungeons.
- Settings window under Options → AddOns → CombatCues (or `/ccues`):
  - On/off toggle, font, outline, font size, display time and position for each alert.
  - Dropdown menus for font, outline and sound; sliders with number boxes you can type into.
  - Unlock mode to drag the alerts into place, and a button to reset positions.
  - Test buttons for each alert.
- Fonts and sounds from LibSharedMedia show up automatically when another addon provides them.
