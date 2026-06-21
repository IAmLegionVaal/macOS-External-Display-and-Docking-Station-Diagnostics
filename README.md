# macOS External Display and Docking Station Diagnostics

A read-only Bash toolkit for collecting display, graphics, USB-C, Thunderbolt, dock, power-delivery, and recent display-event evidence.

## Usage

```bash
chmod +x src/display_dock_diagnostics.sh
./src/display_dock_diagnostics.sh --hours 24
```

## Checks performed

- Connected displays, resolutions, refresh rates, and graphics adapters
- Thunderbolt, USB, USB-C, and docking-station inventory
- Power adapter, charging, and battery indicators
- Display-related processes and recent WindowServer events
- Text, CSV, and JSON reports

## Safety

The script does not change resolution, refresh rate, arrangement, display profiles, power settings, or connected-device configuration.

## Author

Dewald Pretorius — L2 IT Support Engineer
