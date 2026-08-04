# Production Booster

An [OpenTTD](https://www.openttd.org/) GameScript that adjusts primary industry production levels based on how efficiently you transport their cargo. Industries served well grow; industries neglected shrink.

Requires **OpenTTD 15.0** or later (GameScript API v15).

---

## How it works

The script continuously sweeps every tracked primary industry in small batches (see [Performance](#performance) below), checking each roughly once per economy month:

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
| `batch_divisor` | 30 | 5–100 | Tracked industries processed per wake-up = tracked ÷ this value. Higher = lighter CPU load per tick, slower reaction to transport changes |
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

## Performance

Production Booster is built to stay light even on large maps with hundreds of primary industries.

Instead of processing every tracked industry in one pass, the script wakes up roughly once a day (74 ticks) and works through a round-robin slice of the tracked industries — `tracked ÷ batch_divisor` industries per wake-up. A full sweep across every tracked industry still completes roughly once a month, but the CPU cost of any single wake-up stays flat regardless of map size, avoiding the large periodic stalls a full-map pass in one tick would otherwise cause. `batch_divisor` (default 30) controls this trade-off directly — raise it for an even lighter per-tick load at the cost of slower reaction to changing transport percentages, or lower it to react faster at a higher per-tick cost.

Each industry's freight cargo types are looked up once, when the industry is first registered, and cached as a plain array of cargo IDs rather than re-derived from the game's cargo-list API on every pass. Production-changing commands are issued in an async command batch to avoid blocking on each individual result, and the remaining ops-budget check (`GetOpsTillSuspend()`) is polled periodically rather than before every single industry, with the script yielding via `Sleep()` whenever the reserve runs low to prevent mid-batch suspension.

New industries are picked up immediately via `ET_INDUSTRY_OPEN`. Closed industries are released via `ET_INDUSTRY_CLOSE` — flags are cleared while the industry is still valid, before the engine removes it. All control flags are applied in a single async batch at startup to minimise command overhead.

---

## Save/load

Save data is limited to plain values (industry IDs, cached cargo-ID arrays, and a couple of per-industry flags) — nothing that depends on non-persistable game-script objects. Saves from older versions of the script are handled with backward-compatible fallbacks: any industry missing a cached cargo-ID array has one re-derived the first time it's next processed, and any industry missing a `ProductionCanIncrease` entry gets a safe default. The round-robin scan order itself isn't saved — it's cheap to rebuild and simply starts fresh on load.

---

## License

[GNU General Public License v2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)

---

*Created by [nelbin4](https://github.com/nelbin4)*
