# Production Booster (OpenTTD GameScript)

Production Booster dynamically adjusts primary industry production based on how much cargo you
actually transport. Good networks are rewarded; neglected industries shrink.

## How It Works

Every economy month, each primary industry is checked against its last month's transport percentage:

- If transport is at or above `increase_threshold`, production goes up by `step_size`.
- If transport is below `decrease_threshold` and the industry is past its grace period, production goes down by `step_size`.
- Otherwise nothing changes.

Production is always kept within `[min_level, max_level]`. The API hard limits are 4 (minimum) and 128 (maximum).

## Settings

All settings are adjustable in-game from the GameScript Parameters window without restarting.

| Setting | Description | Default |
|---|---|---|
| `increase_threshold` | Transport % needed to increase production | 80 |
| `decrease_threshold` | Transport % below which production decreases | 60 |
| `step_size` | Production level change per adjustment | 4 |
| `min_level` | Minimum production level (API floor: 4) | 8 |
| `max_level` | Maximum production level (API ceiling: 128) | 128 |
| `grace_period_months` | Months before a new industry can be penalized | 3 |
| `log_level` | 1=error, 2=warning, 3=info, 4=debug | 3 |

## Files

| File | Purpose |
|---|---|
| `info.nut` | Script metadata and settings definitions |
| `main.nut` | Core logic |
| `version.nut` | Version constant |

## Installation

1. Copy `info.nut`, `main.nut`, and `version.nut` into an OpenTTD GameScripts folder, e.g. `Documents/OpenTTD/game/Production_Booster`.
2. Launch OpenTTD.
3. Start a new game, open Game Script Settings, and select Production Booster.

## Compatibility

- OpenTTD 14.0+ (uses API version 14).
- Compatible with calendar-based and wallclock-based economy timekeeping modes.
- Works with vanilla industries and NewGRF industry sets.

## Development

Written in Squirrel (`.nut`). See `CHANGELOG.md` for version history.

## License

[GNU General Public License v3](LICENSE) — created by [Nelbin4](https://github.com/nelbin4).
