# CombatCues (WoW Forever)

Small personal addon with two features:

- **Combat text**: text that fades in and out when you enter or leave combat.
- **Party death alert**: text, plus an optional sound, when a member of your 5-player group dies. Raids are ignored.

Each feature can be turned on or off on its own, with its own font, outline, font size, display time and position.

## Install

1. Download `CombatCues-<version>.zip` from the **Releases** page. Don't use the green "Code → Download ZIP" button:
   that zip has the wrong folder layout and the game won't load the addon from it.
2. Unzip it into the game's AddOns folder, so that you end up with:

```
World of Warcraft/<forever client folder>/Interface/AddOns/CombatCues/CombatCues.toc
```

To update, delete the old `CombatCues` folder and unzip the new release in its place.

## Releasing a new version

Push a tag that starts with `v`. GitHub Actions packages the addon, writes the version into the `.toc`,
and publishes a release with the zip attached:

```bash
git tag v1.0.1
git push origin main v1.0.1
```

To build the zip locally without a release, run `scripts/package.sh 1.0.1`. The zip ends up in `dist/`.

## Usage

- `/ccues`: opens the options panel (also under Options → AddOns → CombatCues)
- `/ccues unlock` / `/ccues lock`: show the frames so you can drag them
- `/ccues test combat` / `/ccues test death`: preview the alerts
- `/ccues reset`: reset positions

Fonts and sounds from LibSharedMedia appear in the lists automatically when another addon provides them.

## Notes

The Forever client uses the Midnight-era addon API, which blocks addons from reading the combat log. So the
addon checks each party member's dead/alive state (on health and flag events, plus a check every 0.5s)
and alerts when someone goes from alive to dead. Feign Death is ignored.
