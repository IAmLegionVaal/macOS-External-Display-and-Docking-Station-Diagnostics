# macOS External Display and Docking Station Diagnostics

A macOS support toolkit for diagnosing and repairing common external-display, USB-C, Thunderbolt and docking-station problems.

## Diagnostic script

```bash
chmod +x src/display_dock_diagnostics.sh
./src/display_dock_diagnostics.sh --hours 24
```

The diagnostic script collects display, graphics, Thunderbolt, USB, power and recent WindowServer evidence.

## Repair script

Preview the repair:

```bash
chmod +x src/display_dock_repair.sh
./src/display_dock_repair.sh --repair --dry-run
```

Apply the standard repair:

```bash
./src/display_dock_repair.sh --repair
```

Restart display and USB services:

```bash
./src/display_dock_repair.sh --repair --restart-usb
```

Back up and reset saved display-layout preferences:

```bash
./src/display_dock_repair.sh --reset-layout
```

## What the repair does

- Restarts Dock, SystemUIServer, corebrightnessd and the display-policy service.
- Can restart the USB service to recover docking peripherals.
- Can back up and reset saved WindowServer display-layout preferences.
- Produces repair logs and a post-repair hardware verification report.
- Supports dry-run, confirmations and clear exit codes.

## Safety and limitations

Screens may flicker while services restart. Restarting USB may temporarily disconnect attached devices. Resetting the saved layout can require sign-out or restart before the change is fully applied. The tool does not change resolution, refresh rate or colour profiles automatically. Hardware, cable, adapter and power-delivery faults may still require physical testing.

## Author

Dewald Pretorius — L2 IT Support Engineer
