# Omarchy Notify

> Preview placeholder — capture `preview.png` from a real Omarchy session before publishing.

Omarchy Notify is a dark, minimal, keyboard-first notification drawer for the [Omarchy](https://omarchy.org/) Quattro shell. It is a bar widget, not a notification daemon: Omarchy remains the only process that receives, persists, displays, and dismisses desktop notifications.

The drawer opens from the right edge, keeps the desktop visible, follows Omarchy `Color`, `Style`, and border tokens, and is designed to be usable without leaving the keyboard.

## Status and Omarchy 4.0.3 compatibility

This release is deliberately capability-safe. On the locally inspected Omarchy 4.0.3-1 / Quickshell 0.3.1 installation, arbitrary third-party bar widgets receive a service-less facade. The narrow `omarchy.notifications` proxy (`doNotDisturb` and `setDoNotDisturb()`) is reserved for a full replacement bar and specific trusted indicators clones. No notification-entry API is available to this plugin.

Consequently, on that version the drawer, IPC, theming, and empty-state diagnostic work; notification rows, badges, DND control, search, history, actions, and dismiss controls remain safely unavailable. The UI feature-detects a future official read/action API and activates those features without changing the original model. It does not inspect or bypass shell-private objects.

For a fully functional third-party notification center, Omarchy needs an explicitly supported, read-only presentation API, for example a proxy exposing `popupModel`, `showRecentHistory()`, `dismissPopup(index)`, and `invokePopupDefault(index)`. `pendingModel`, `pastModel`, `dismissPending`, `dismissPast`, and mark-seen methods are not present in Omarchy 4.0.3's installed service.

## Features

- Right-edge, near-full-height slide-in drawer; desktop remains visible.
- Native Omarchy typography, theme colors, border and spacing tokens.
- Bell widget with contextual tooltip and DND indication.
- Left click opens/closes; DND controls activate automatically only if the host grants that capability.
- Keyboard navigation designed for notification rows when the official model API is available.
- Plain-text body rendering: sender HTML is never rendered as rich text by this plugin.
- No daemon, polling loop, shell command, persistent process, telemetry, network access, or file writes.

## Requirements

- Omarchy with Quattro shell-plugin support.
- Quickshell 0.3 or newer.
- The built-in `omarchy.notifications` service enabled (it is first-party infrastructure by default).

## Install

After publishing, install from the repository URL:

```sh
omarchy plugin add <REPOSITORY_URL> --enable
```

For this checkout, validate first and then install from its absolute path:

```sh
omarchy plugin validate .
omarchy plugin add "$(pwd)" --enable
```

The widget's default section is `right`. To enable an existing installation explicitly:

```sh
omarchy plugin enable caio.omarchy-notify --section right
```

## Usage

- Left-click the bell to toggle the drawer.
- Right-click the bell and the drawer DND label toggle Do Not Disturb only when the installed Omarchy host grants that capability. Omarchy 4.0.3 does not grant it to arbitrary third-party bar widgets.

When the notification-entry API is available:

| Key | Action |
| --- | --- |
| `j` / `↓` | Next notification |
| `k` / `↑` | Previous notification |
| `g` / `G` | First / last notification |
| `Enter` | Invoke the service's default action |
| `d` or `x` | Dismiss selected notification |
| `/` | Focus search |
| `Esc` | Clear/leave search, then close |
| `Tab`, `h`, `l` | Switch Unread / History |
| `D` | Toggle DND |
| `?` | Toggle shortcut help |

Typing in search never triggers panel shortcuts.

## IPC and global hotkey

The bar widget implements the standard lifecycle required by the shell:

```sh
omarchy-shell shell toggle caio.omarchy-notify '{}'
omarchy-shell shell summon caio.omarchy-notify '{}'
omarchy-shell shell hide caio.omarchy-notify
```

`toggle`, `summon`, and `hide` require a running Omarchy shell. This project does not modify Hyprland bindings. The current local `~/.config/hypr/bindings.lua` uses `o.bind(...)`; add a personal override such as:

```lua
o.bind("SUPER + ALT + N", "Omarchy Notify", "omarchy-shell shell toggle caio.omarchy-notify '{}'")
```

Before using `SUPER + N`, inspect `omarchy menu keybindings --print` for a conflict. `SUPER + ALT + N` is the safer alternative. Reload/validate Hyprland only after making your own configuration change.

## Update and removal

```sh
omarchy plugin update caio.omarchy-notify
omarchy plugin remove caio.omarchy-notify
```

## Development and validation

```sh
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
omarchy-shell shell rescanPlugins
omarchy-shell shell toggle caio.omarchy-notify '{}'
```

The distribution's `qmllint` may need Quickshell's registered QML module paths to resolve `qs.Commons` and `qs.Ui`; unresolved-module warnings alone are not a runtime validation. With a graphical session running, also test `notify-send "Omarchy Notify" "Test notification"`, DND, mouse opening, all keyboard bindings, IPC, and shell restart.

## Architecture

```text
BarWidget.qml          bell, badge capability detection, IPC, drawer host
Panel.qml              right-edge drawer, focus, selection, search, tabs
NotificationLogic.js   pure search, body normalization, relative time
```

The project intentionally has no `Service.qml`: it must consume Omarchy's existing notification service rather than start another daemon.

## Troubleshooting

- **“Notification service unavailable”**: ensure the shell is running and `omarchy.notifications` has not been disabled. On Omarchy 4.0.3 the supported third-party facade exposes neither notification entries nor DND; this is expected, not a crash.
- **IPC says the shell is not running**: start/restart the graphical Omarchy shell, then retry.
- **No rows on a future version**: inspect that version's official proxy contract; this plugin intentionally refuses undocumented object access.

## License

[MIT](LICENSE).
