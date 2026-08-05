# Production Booster

Production Booster is an [OpenTTD](https://www.openttd.org/) GameScript that adjusts primary industry production based on transport efficiency. Well-served industries grow; neglected industries shrink.

Requires **OpenTTD 15.0 or later** and GameScript API v15.

## How It Works

The script tracks raw industries that produce freight cargo and processes them in round-robin batches.

- If last month's average transported percentage is at least `increase_threshold`, production increases by `step_size`.
- If it is below `decrease_threshold`, production decreases by `step_size` after the grace period.
- Production remains within `min_level` and `max_level`.
- Industries without nearby stations are skipped.
- Industries with no output for two or more consecutive economy years are skipped in calendar mode.
- New industries are registered immediately; closed industries are removed safely.

The script takes control of tracked industry production with `INDCTL_EXTERNAL_PROD_LEVEL` and suppresses the game's random production changes and closures.

## Settings

Settings can be changed in-game from the GameScript Parameters window.

| Setting | Default | Range | Description |
|---|---:|---:|---|
| `increase_threshold` | 80 | 50–100 | Transport percentage required to increase production |
| `decrease_threshold` | 60 | 0–95 | Transport percentage below which production decreases |
| `step_size` | 4 | 1–16 | Production level change per adjustment |
| `min_level` | 8 | 4–64 | Minimum production level |
| `max_level` | 128 | 4–128 | Maximum production level |
| `grace_period_months` | 3 | 0–12 | Time after opening before production may decrease |
| `batch_divisor` | 30 | 5–100 | Controls wake frequency; higher values reduce CPU overhead but slow reaction time |
| `log_level` | 3 | 1–4 | 1 = errors, 2 = warnings, 3 = info, 4 = debug |

If `increase_threshold` is less than or equal to `decrease_threshold`, production changes are suspended and a warning is logged.

## Compatibility

| | |
|---|---|
| OpenTTD | 15.0 or later |
| GameScript API | v15 |
| Industry sets | Vanilla and NewGRF |
| Timekeeping | Calendar and wallclock modes |
| Multiplayer | Supported |

In wallclock mode, dormancy and grace-period checks are disabled because construction dates and production years use calendar coordinates.

## Installation

### BaNaNaS

Search for **Production Booster** in the in-game Game Scripts content browser.

### Manual

1. Create `<OpenTTD data dir>/game/Production_Booster/`.
2. Copy `info.nut`, `main.nut`, and `version.nut` into that directory.
3. Start a game and select Production Booster in **GameScript Settings**.

Typical OpenTTD data directories:

| OS | Path |
|---|---|
| Windows | `Documents\OpenTTD\` |
| macOS | `~/Documents/OpenTTD/` |
| Linux | `~/.openttd/` |

## Files

| File | Purpose |
|---|---|
| `info.nut` | Metadata and in-game settings |
| `main.nut` | Runtime controller and industry processing |
| `version.nut` | Shared script version constant |

## Performance

Production Booster avoids a full-map industry scan in one tick.

At the default `batch_divisor` of 30, each wake processes approximately `tracked industries / 30`. The batch size is anchored to `REFERENCE_DIVISOR`, while `batch_divisor` scales the sleep interval. This keeps the per-wake batch size stable and changes how often the script wakes.

- Lower `batch_divisor`: more frequent processing and faster reaction, with more wake overhead.
- Higher `batch_divisor`: fewer wake-ups and lower overhead, with slower reaction.
- `GetOpsTillSuspend()` is checked every 10 industries and the script yields with `Sleep()` when the reserve is low.
- Freight cargo IDs are cached as plain integer arrays.
- Production commands run synchronously so their return values are meaningful.
- Startup control flags are applied in one asynchronous batch.
- New industries are appended to the current scan without restarting the round-robin pass.
- Duplicate pending scan entries are prevented with an O(1) pending-ID table.
- Stale-industry validation runs every four completed passes; normal open/close events handle routine tracking.

## Save and Load

The script saves plain values only: industry IDs, cached cargo-ID arrays, and production capability flags. Scan order and pending scan state are rebuilt after loading.

Older saved data may be migrated when OpenTTD provides it to the new script. If OpenTTD considers an older GameScript version incompatible, it may discard the old script state; v10 then rebuilds its industry tracking from the current map.

## Version

This release is **Production Booster v10**. The BaNaNaS-visible version is defined in `version.nut`.

## License

[GNU General Public License v2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)

Created by [nelbin4](https://github.com/nelbin4)
