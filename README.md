# Production Booster

An [OpenTTD](https://www.openttd.org/) GameScript that adjusts primary industry production levels based on how efficiently you transport their cargo. Industries served well grow; industries neglected shrink.

Requires **OpenTTD 15.0** or later (GameScript API v15).

---

## How it works

Once per economy month the script checks every tracked primary industry:

- If last month's average transport percentage is at or above `increase_threshold`, production level rises by `step_size` (up to `max_level`).
- If it is below `decrease_threshold` and the industry is past its grace period, production level falls by `step_size` (down to `min_level`).
- Otherwise nothing changes.

Only raw/primary industries that produce freight cargo are tracked. Industries with no stations nearby, industries that have had no output for two or more consecutive economy years, and industries still within their grace period are all skipped.

Production level is the OpenTTD multiplier in the range 4–128. Default game behaviour sits around level 16. The script takes full control of each tracked industry's production via `INDCTL_EXTERNAL_PROD_LEVEL` and suppresses the game's own random fluctuations and closures.

---

## Settings

All settings are adjustable in-game from the GameScript Parameters window without restarting.

| Setting | Default | Range | Description |
|---|---|---|---|
| `increase_threshold` | 80 | 50–100 | Transport % required to increase production |
| `decrease_threshold` | 60 | 0–95 | Transport % below which production decreases |
| `step_size` | 4 | 1–16 | Production level change per adjustment cycle |
| `min_level` | 8 | 4–64 | Minimum production level (API hard floor: 4) |
| `max_level` | 128 | 4–128 | Maximum production level (API hard ceiling: 128) |
| `grace_period_months` | 3 | 0–12 | Months after opening before an industry can be decreased |
| `log_level` | 3 | 1–4 | 1 = errors only, 2 = warnings, 3 = info, 4 = debug |

If `increase_threshold` is set lower than or equal to `decrease_threshold`, all production adjustments are suspended and a warning is logged until the conflict is resolved.

---

## Compatibility

| | |
|---|---|
| OpenTTD | 15.0 or later |
| GameScript API | v15 |
| Industry sets | Vanilla and NewGRF (respects `ProductionCanIncrease` per industry type) |
| Timekeeping | Calendar mode and wallclock mode both supported |
| Multiplayer | Supported |

In wallclock mode the dormancy check and grace period check are both disabled because construction dates and last-production years use incompatible time coordinate systems in that mode. All other logic runs normally.

---

## Installation

**From BaNaNaS (in-game content browser):**

Search for *Production Booster* in the Game Scripts category and download directly.

**Manual:**

1. Create the folder `<OpenTTD data dir>/game/Production_Booster/`.
2. Copy `info.nut`, `main.nut`, and `version.nut` into that folder.
3. Launch OpenTTD, start a new game, open **Game Script Settings**, and select Production Booster.

The OpenTTD data directory is typically:

| OS | Path |
|---|---|
| Windows | `Documents\OpenTTD\` |
| macOS | `~/Documents/OpenTTD/` |
| Linux | `~/.openttd/` |

---

## Files

| File | Purpose |
|---|---|
| `info.nut` | Script metadata and settings declarations |
| `main.nut` | All runtime logic |
| `version.nut` | Version constant shared by both files |

---

## Technical notes

The script runs once per economy month (`74 × 30 = 2220` ticks). Each cycle it reads current settings, drains the event queue for new or closed industries, then iterates all tracked industries. Ops budget is monitored via `GetOpsTillSuspend()` and the script yields with `Sleep(1)` before each industry if the reserve drops too low, preventing mid-iteration suspension.

New industries are picked up immediately via `ET_INDUSTRY_OPEN`. Closed industries are released via `ET_INDUSTRY_CLOSE` — flags are cleared while the industry is still valid, before the engine removes it. All control flags are applied in a single `GSAsyncMode` batch at startup to minimise command overhead.

Save/load state includes the full industry tracking tables. Saves from versions that predate the `id_can_inc` table are handled with a backward-compatible fallback that inserts a safe default for every loaded entry.

---

## License

[GNU General Public License v2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)

---

*Created by [nelbin4](https://github.com/nelbin4)*
