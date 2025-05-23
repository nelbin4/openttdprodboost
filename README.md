# GameScript for OpenTTD

**Production Booster** is a custom GameScript for OpenTTD that dynamically adjusts primary industry production based on transportation efficiency.

## Features

- 📈 **Production Increase**: If 80% or more of a primary industry's cargo is transported, its production increases.
- 📉 **Production Decrease**: If less than 60% of a primary industry's cargo is transported, its production decreases.
- ⚙️ Designed exclusively for **primary industries** (e.g., coal mines, forests).
- 💡 Custom logic and thresholds defined in an easily modifiable `.nut` script.

## Files

- `info.nut` – GameScript metadata and configuration.
- `main.nut` – Core logic controlling industry behavior.
- `version.nut` – Version management for the script.

## Installation

1. Copy the 3 files script into a folder in your OpenTTD GameScripts directory: (i.e E:\Documents\OpenTTD\content_download\game\PB)
2. Launch OpenTTD.
3. In the main menu, go to **Game Scripts**, then select **Production Booster**.
4. Create a new map, use the gamescript in game scripts.
5. Enjoy

## Customization

The thresholds for production adjustment (80% and 60%) can be changed by editing the constants in `main.nut`. Look for the section labeled `-- CONFIGURABLE THRESHOLDS`.

## Compatibility

- Requires OpenTTD v1.11.0 or newer.
- Tested with vanilla industries and standard settings.

## License

[MIT License](LICENSE)

---

*Created by Nelbin4 github.com/nelbin4 for enhanced economic realism in OpenTTD.*
