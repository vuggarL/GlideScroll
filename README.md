# GlideScroll

A smooth, responsive middle-mouse scrolling utility for Windows.

![AI Assisted](https://img.shields.io/badge/Built%20with-AI%20Assistance-purple)
![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2.0-green)
![Platform](https://img.shields.io/badge/Platform-Windows-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

- **Smooth Scrolling** - Hold middle mouse button and move to scroll
- **Horizontal Scroll** - Move left/right while holding middle button
- **Axis Locking** - Prevents diagonal drift when scrolling
- **Presets** - Fine, Normal, Fast, and Turbo speed presets
- **Click Detection** - Quick middle-click still works normally
- **High DPI Support** - Works correctly on high-resolution displays
- **Customizable** - Adjust sensitivity, deadzone, max speed, and more

## Installation

### Option 1: Download Executable
1. Download `GlideScroll.exe` from [Releases](../../releases)
2. Run `GlideScroll.exe`
3. (Optional) Enable "Autostart with Windows" from tray menu

### Option 2: Run Script
1. Install [AutoHotkey v2.0](https://www.autohotkey.com/)
2. Download `GlideScroll.ahk`
3. Double-click to run

## Usage

| Action | Result |
|--------|--------|
| **Middle Mouse (hold)** | Enter glide scroll mode |
| **Middle Mouse (click)** | Normal middle-click |
| **Win + Middle Mouse** | Toggle GlideScroll on/off |
| **Ctrl + Alt + R** | Emergency cursor restore |

## Settings

Right-click the tray icon to access:

### Presets
| Preset | Sensitivity | Max Speed | Best For |
|--------|-------------|-----------|----------|
| Fine | 30 | 80 | Precise work |
| Normal | 60 | 150 | General use |
| Fast | 100 | 250 | Quick navigation |
| Turbo | 160 | 400 | Large documents |

### Features
- **Horizontal Scroll** - Enable/disable left-right scrolling
- **Axis Locking** - Prevent diagonal drift
- **Invert Scroll** - Reverse scroll direction
- **Acceleration** - Speed increases with distance
- **Scroll Indicator** - Show anchor point

### Settings
- **Sensitivity** (1-200) - How fast scrolling responds
- **Deadzone** (0-20) - Minimum movement before scrolling
- **Max Speed** (20-500) - Maximum scroll speed
- **Click Threshold** (0.1-1.0s) - Time to distinguish click vs hold

## Configuration

Settings are saved to `GlideScroll.ini` in the same folder as the script.

## Building

To compile to `.exe`:

1. Install [AutoHotkey v2.0](https://www.autohotkey.com/)
2. Right-click `GlideScroll.ahk` → Compile Script
3. Or use Ahk2Exe with the included script

## Requirements

- Windows 10/11
- AutoHotkey v2.0+ (for script version)

## License

[MIT License](LICENSE)

## Contributing

Contributions welcome! Please open an issue or pull request.

## Acknowledgments

This project was built entirely with AI assistance (Claude by Anthropic, Gemini 3 Pro by Google, GLM 4.7 by z.ai). The human contributor provided direction, testing, feedback, and iterative refinement while the AI wrote the code and documentation.

Built with [AutoHotkey v2](https://www.autohotkey.com/)
