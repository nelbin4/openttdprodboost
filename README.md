# Production Booster (OpenTTD GameScript)

Production Booster dynamically adjusts **primary industry** production based on how much cargo you actually transport. Reward good networks, penalize neglected industries.

## Features

- 📈 Increase production when transported cargo meets the configured "increase" threshold.
- 📉 Decrease production when transported cargo falls below the configured "decrease" threshold.
- � Configurable step size and min/max production levels.
- 🛡️ Grace period for new industries before they can be penalized.
- ⚙️ Designed for primary industries only (e.g., coal mines, forests).

## Files

- `info.nut` – Metadata and configurable settings.
- `main.nut` – Core logic controlling industry behaviour.
- `version.nut` – Script version definition.

## Manual Installation

1. Copy the three script files into an OpenTTD GameScripts folder, e.g. `Documents/OpenTTD/game/Production_Booster`.
2. Launch OpenTTD.
3. Start a new game, click Game Script Settings button, click Select Game Script.

## Configuration

All knobs are exposed in the GameScript settings UI:

- `increase_threshold` (transport % to trigger an increase)
- `decrease_threshold` (transport % below which to decrease)
- `step_size` (production change per adjustment)
- `min_level` / `max_level` (bounds)
- `grace_period_months` (months before new industries can decrease)
- `log_level` (1=error … 4=debug)

Defaults match the values shown in `info.nut`. You no longer need to edit code to tweak thresholds.

## Compatibility

- Tested with OpenTTD 1.11.0+ and vanilla industries.

## Development

- The script is written in Squirrel (`.nut`).
- See `CHANGELOG.md` for recent fixes/features.

## License

[MIT License](LICENSE)

---

Created by [Nelbin4](https://github.com/nelbin4) for enhanced economic realism in OpenTTD.
