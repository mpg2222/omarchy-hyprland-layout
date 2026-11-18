# Saved desktop layouts

![Saved desktop layouts — a hotkey restores your favorite desktop](preview.png)

Your ideal desktop shouldn't be a ritual of opening, dragging and resizing
every app by hand — every single time. Save your favorite arrangement once,
from a screenshot or your live desktop, then bring it back without touching
the mouse: bind a hotkey (or one click on the bar, if you like) and missing
apps launch on their own, every window lands exactly where you placed it, at
exactly the size you set. Keep a saved layout for each thing you do — work,
study, gaming — and switch your whole desktop with a keystroke, not ten
minutes.

The bundled CLI (`bin/omarchy-hyprland-layout`, also invocable as
`hyprland-layout`) works on **any Hyprland, on any distro** — Omarchy,
vanilla Hyprland, Fedora, Arch. It only needs
`hyprctl`, `jq` and `curl` (plus ImageMagick for `from-image`). Geometry is stored **relative** (percent of the
monitor), so a layout defined on one screen works at any resolution. Only the
bar widget is Omarchy-specific; the hotkey is everyone's.

If you rebuild your workspace by hand every day — open the apps, drag the
windows, resize everything — you need this. Try it in one command:

```bash
omarchy-hyprland-layout save my-desktop && omarchy-hyprland-layout restore-last
```

## How it works

```bash
# 1. Define a layout from a screenshot of an arrangement you like:
omarchy-hyprland-layout from-image screenshot.png my-setup
#    A vision model detects every window region; you tell it which app
#    belongs in each one (by name if it is running, or a launch command).

# 2. Restore it — assigned apps launch and land exactly where they belong:
omarchy-hyprland-layout restore my-setup

# Other commands:
omarchy-hyprland-layout save <name> [--all]   # snapshot active monitor's desktops
omarchy-hyprland-layout restore-last          # most recent layout
omarchy-hyprland-layout restore-last --workspace <id>  # one desktop only
omarchy-hyprland-layout workspaces-last       # desktops in the last layout
omarchy-hyprland-layout list | delete <name>
```

## Top bar size

The Omarchy top bar's height and icon sizes are configurable here too, and
travel with your layouts: `save` records them, and a full `restore` puts them
back (a single-desktop `restore --workspace` leaves the bar alone).

```bash
omarchy-hyprland-layout bar                      # show current values
omarchy-hyprland-layout bar scale 115            # bar + icons 15% over Omarchy's default
omarchy-hyprland-layout bar set size-horizontal 44
omarchy-hyprland-layout bar set icon-size 14
omarchy-hyprland-layout bar reset                # back to the theme's sizes
```

Keys: `size-horizontal` (bar height), `size-vertical` (side-bar width),
`icon-slot`, `icon-canvas`, `icon-font`, `icon-size`, `status-slot`, and
`scale-with-font` (`true`/`false`). Values are written to the `[bar]` section
of `~/.config/omarchy/shell.toml` (backed up first; other sections are kept),
which overrides the theme and survives theme changes. The shell reloads it
live. Bar text follows the shell-wide font size and is not changed here.

Layouts are stored in `~/.local/state/omarchy/hyprland-layouts/`.
Left-click the bar icon to restore the latest layout. Right-click it to save a
named layout, restore all desktops, or restore one workspace from the latest
layout.

Restore reports missing windows instead of claiming success when an app cannot
be matched or launched; successfully restored windows are moved and unpinned
after launches complete.

## Vision backend

`from-image` uses any OpenAI-compatible vision endpoint:

- `OMARCHY_LAYOUT_VISION_URL` — default `http://127.0.0.1:1234/v1` (LM Studio)
- `OMARCHY_LAYOUT_VISION_MODEL` — default: the first model the endpoint serves

`save` / `restore` need no model at all.

## Install

```bash
omarchy plugin add https://github.com/aishag80g-stack/omarchy-hyprland-layout --enable
```

Then add the widget to your bar (Omarchy menu → Bar → Widgets →
"Saved desktop layout"), or bind the CLI to a key directly, e.g. in
`~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER, T", "exec", "~/.config/omarchy/plugins/io.github.aishag80g-stack.hyprland-layout/bin/omarchy-hyprland-layout restore-last")
```

On vanilla Hyprland, the same binding in `hyprland.conf`:

```
bind = SUPER, T, exec, /path/to/bin/hyprland-layout restore-last
```

## Troubleshooting

- `from-image` fails with "no vision model available" → the endpoint at
  `OMARCHY_LAYOUT_VISION_URL` is not answering. Start LM Studio (or point the
  variable at any OpenAI-compatible vision endpoint). `save` / `restore` never
  need a model.
- A restored window lands slightly off → some apps clamp their minimum size
  (Chrome floors at 500px, for example); that is the app, not the layout.
- Nothing moves when you press the hotkey → the script path in your binding
  must be absolute; Hyprland does not expand `~` in exec arguments.

## Remove

```bash
omarchy plugin remove io.github.aishag80g-stack.hyprland-layout
```

Removal only deletes the plugin folder; your saved layouts stay in
`~/.local/state/omarchy/hyprland-layouts/` and are never touched.

## Dependencies

`bash`, `jq`, `curl`, `hyprctl` (Hyprland ≥ 0.56 Lua API), ImageMagick
(optional, downscales large screenshots), and an OpenAI-compatible vision
endpoint for `from-image` only.

## License

MIT — see [LICENSE](LICENSE).
