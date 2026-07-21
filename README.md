# agent-signal

Status indicator for Claude Code — shows what the agent is doing right now, via the Caps Lock LED and/or a small floating spinner near the notch, visible even over fullscreen apps.

### Install

Install via script:
```sh
curl -fsSL https://raw.githubusercontent.com/arturious/caps-signal-for-agents/main/install-remote.sh | bash
```

This downloads and installs `agent-signal.pkg`, which puts the binary at `/usr/local/bin/agent-signal` and automatically wires it into Claude Code's hooks (`~/.claude/settings.json`). Restart your Claude Code session (`/exit`, then `claude` again) to pick up the hooks.

The installer is unsigned — if Gatekeeper blocks it, right-click the downloaded `.pkg` → Open, or run the `curl`/`installer` steps manually.

### Configure

```sh
agent-signal config              # show current settings
agent-signal config led off      # disable the Caps Lock LED, keep the spinner
agent-signal config overlay off  # disable the spinner, keep the LED
```

```sh
agent-signal working    # start the "working" indicator
agent-signal done       # done pattern
agent-signal attention  # needs-attention pattern
agent-signal stop       # turn everything off
agent-signal status     # print Caps Lock LED state (on/off)
```

- **Caps Lock LED** — IOKit's `IOHIDSetModifierLockState`, the same mechanism the physical Caps Lock key uses. This means typing while the LED is on/blinking produces CAPITALS — it's tied to the real modifier state, not a separate light.
- **Floating spinner** — a borderless `NSWindow` with `.fullScreenAuxiliary` collection behavior (the same mechanism Spotlight/Notification Center use to stay visible over fullscreen apps), positioned via `NSScreen.auxiliaryTopRightArea` to sit just right of the camera notch.
- Both are driven by the same `working`/`done`/`attention`/`stop` commands, wired into Claude Code's `UserPromptSubmit`/`Stop`/`Notification`/`SessionEnd` hooks via `agent-signal install-hooks` (run automatically by the installer's postinstall script, as the logged-in user rather than root).
