# Menu Magnet

**Make every menu feel tactile.**

Menu Magnet is a macOS trackpad interaction experiment that transforms ordinary scrolling within supported native menus into discrete magnetic steps, with optional haptic feedback and velocity-sensitive navigation. It runs locally with [Hammerspoon](https://www.hammerspoon.org/).

**Website:** Enable GitHub Pages using the `/docs` folder to publish the interactive showcase in `docs/index.html`.

## What it does

- **Row snapping:** turns small scroll movements into consistent steps between enabled, accessible menu rows.
- **Velocity-sensitive flicks:** fast scroll gestures can cross more than one row, bounded by a configurable jump limit.
- **Haptic detents:** optionally uses the [`mactic`](https://github.com/MatMercer/mactic) CLI for Force Touch click waveforms, with a quiet macOS sound fallback.
- **Menu-bar and context menu support:** works with the standard macOS menu-bar dropdowns and accessible right-click menus.
- **Submenu recovery:** follows submenus opened by native primary clicks or guarded secondary clicks; edge escape can return to the root menu.
- **Configurability:** scroll threshold, direction, smoothing, sensitivity, feedback and keyboard shortcuts live in one Lua `CONFIG` block.

> **Scope:** The included engine is the Menu Magnet portion of the supplied `init(1).lua`. Other personal Hammerspoon automations (BetterDisplay contrast HUD, RetroHUD and EdgeOrbit) are intentionally **not** distributed here. Menu Magnet's extracted logic and default values have not been changed.

## Prerequisites

| Requirement | What it's for |
| --- | --- |
| **macOS** and a Mac trackpad (recommended) | Access to macOS-native menus and two-finger scrolling |
| **[Hammerspoon](https://www.hammerspoon.org/go/)** | Hosts the Lua engine, event taps, and Accessibility UI inspection |
| **Hammerspoon Accessibility permission** | System Settings → Privacy & Security → Accessibility |
| **[mactic](https://github.com/MatMercer/mactic)** *(optional)* | Haptic clicks on supported Force Touch MacBook trackpads |

No Karabiner-Elements, BetterDisplay, RetroHUD or EdgeOrbit dependency is required for this standalone engine. The base experience does not require disabling any native macOS gestures.

### Optional haptics

`mactic` is a separate, third-party project using a private Apple API. To install using its published Homebrew tap:

```bash
brew install matmercer/tap/mactic
mactic -w 1
```

The script looks for `/opt/homebrew/bin/mactic` or `/usr/local/bin/mactic`. If neither is present and sound fallback is enabled, Menu Magnet uses a quiet system sound instead. Hardware feedback may not be available on other trackpads or newer macOS versions.

## Install

1. Install Hammerspoon and grant Accessibility permission.
2. Copy [`src/MenuMagnet.lua`](src/MenuMagnet.lua) to `~/.hammerspoon/MenuMagnet.lua`.
3. Append **one** loader line to your existing `~/.hammerspoon/init.lua`:

   ```lua
   dofile(hs.configdir .. "/MenuMagnet.lua")
   ```

4. Reload Hammerspoon. If Hammerspoon needs to regain Accessibility access, relaunch it.
5. Open a native right-click menu, release the click, and scroll with two fingers. Or click an application's File menu, then scroll vertically.

**Do not replace your existing `init.lua`.** This package ships a standalone module, not your entire macOS automation configuration. Remove any duplicate Menu Magnet loader lines first.

**Note:** The source calls `hs.menuIcon(false)`, which hides Hammerspoon's own menu bar icon. Comment it out if you want that icon visible.

## Native gesture map

| Gesture | Default behavior in this build | Native macOS conflict |
| --- | --- | --- |
| Secondary click (two fingers) | Open context menu, then **release** to navigate | Uses macOS's normal secondary click |
| Two-finger vertical scroll | Magnetic row selection while a supported menu is active | Normal scrolling passes through outside supported menus |
| Two-finger secondary click *inside an open menu* | Enter a known/visible submenu | Only on submenu items when default safety guard is enabled |
| Primary click | Select item / enter submenu as macOS ordinarily would | None |
| Separate scroll gesture at submenu edge | Escape to root and optionally advance | Only while submenu is active |
| Three-finger tap | Experimental submenu-back feature — **off by default** | May overlap native Look Up or three-finger drag if enabled |
| Three-/four-finger swipes | **Not mapped by this build** | Native Mission Control, App Exposé and Spaces controls remain independent |

**Do not disable macOS-wide three- or four-finger gestures to use Menu Magnet's default configuration.** See the [complete native gesture guide](docs/guide.html#native).

## Shortcuts

| Shortcut | Action |
| --- | --- |
| `Control + Option + Command + P` | Open Menu Magnet Lua source in the text editor |
| `Control + Option + Command + M` | Toggle Menu Magnet on/off |
| `Control + Option + Command + R` | Reload Hammerspoon |

Edit these keys in `CONFIG` if another tool already uses them.

## Customization

Open [`src/MenuMagnet.lua`](src/MenuMagnet.lua) and edit the `CONFIG` block near the beginning:

```lua
scrollThreshold        = 15,  -- Lower = more sensitive
velocityScrolling      = true,
velocitySensitivity    = 45,  -- 0–100; higher = more responsive
maxJump                = 3,   -- Upper bound on fast-flick movement
stepIntervalMs         = 44,  -- Delay between queued row steps
invertScroll           = true,
verticalSmoothingFrames = 0,  -- 0 = instant snap

holdSecondaryClick     = false, -- Default: release then scroll
edgeEscapeToRoot       = true,
threeFingerBack        = false, -- Experimental; off by default

hapticEnabled          = true,
hapticWaveform         = 1,     -- mactic waveform 1–6
soundFallbackEnabled   = true,
soundName              = "Tink",
soundVolume            = 7,
```

These values are documented for reference; **paste changes inside the existing configuration table rather than creating a second one.** See [the full settings reference](docs/guide.html#customize).

## Website

[Open the interactive Gesture Studio](docs/index.html) · [Installation, native mappings and customisation](docs/guide.html) · [Publishing instructions](PUBLISHING.md)

## Repository layout

```text
menu-magnet/
├── README.md
├── PUBLISHING.md                  # GitHub Pages instructions
├── .gitignore
├── src/
│   └── MenuMagnet.lua             # Extracted standalone engine
└── docs/
    ├── index.html                 # Your full Gesture Studio + project homepage
    ├── guide.html                 # Prereqs, gestures, install and customization
    ├── download/MenuMagnet.lua    # Direct download offered on GitHub Pages
    ├── styles.css
        ├── favicon.svg
    └── .nojekyll
```

The homepage is based on the original **Menu Magnet macOS Gesture Studio (Original Sound)** supplied by the project creator. It preserves its six animation profiles, original synthesized detent sound, audio toggle, and built-in MP4 export (only available where the browser supports MP4 MediaRecorder). It runs entirely in the browser and **does not control your Mac** or trigger real trackpad haptics.

The demonstration intentionally visualises a long momentum glide; it is **not** a literal capture of the bundled script. In the Lua implementation, `maxJump = 3` by default and the engine ignores scroll-wheel momentum events to avoid overshoot.

## Troubleshooting and limitations

- If nothing happens, check Hammerspoon's Accessibility permission and Console; try a standard Finder menu.
- If the scroll direction is unexpected, flip `invertScroll` instead of changing macOS gesture mappings.
- If haptics are missing, try `mactic -w 1` from Terminal and confirm its path. Keep the sound fallback enabled if needed.
- Menu Magnet relies on macOS Accessibility objects (`AXMenu`, `AXMenuItem`); custom-drawn menus may not be supported.
- Avoid loading multiple Menu Magnet event taps simultaneously or combining conflicting scroll-event handlers.
- Optional experimental three-finger gesture support is disabled by default.
- The supplied code has not been tested on this machine; review it before loading any automation with system-level permissions.

Read the detailed [documentation](docs/guide.html#troubleshooting).

## Publishing the website

See [PUBLISHING.md](PUBLISHING.md) for the exact GitHub setup steps. Use **Settings → Pages → Deploy from a branch → `main` → `/docs`**.

## Licence

A software licence has **not** been selected or included. Public visibility on GitHub does not automatically grant permission for reuse or redistribution. Add a licence of your choice if you intend others to reuse or contribute to the project.

## References

- [Hammerspoon](https://www.hammerspoon.org/go/)
- [Hammerspoon Accessibility API](https://www.hammerspoon.org/docs/hs.axuielement.html)
- [Apple trackpad gestures](https://support.apple.com/en-au/102482)
- [mactic CLI](https://github.com/MatMercer/mactic)
