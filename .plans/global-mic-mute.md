# global-mic-mute

**Goal:** A single keybind (`Alt+Ctrl+Super+Shift+F1`) and a waybar module that
toggle the mute state of *all* real microphone inputs at once, showing muted /
unmuted / indeterminate (mixed) status, where a mixed state resolves by muting
everything.

- [x] 1. Plan
- [x] 2. Identify code changes
- [x] 3. Implement
- [-] 4. Cleanup

## Context & decisions

### Scope
Audio microphone inputs only. Video/webcam muting was explicitly dropped for now
(the Logitech C920e webcams have no hardware privacy control, so a real video
mute would require unloading the uvcvideo module or gating /dev/videoN with
passwordless sudo — deferred).

### What "all input devices" means
The system uses PipeWire with the `pactl` compatibility layer. `pactl list short
sources` returns both real capture devices (the Focusrite Scarlett `Mic1`/`Mic2`
sources) *and* `.monitor` sources, which are loopback taps of output sinks — not
microphones. The toggle must operate only on **real** sources and skip any name
ending in `.monitor`, otherwise it would "mute" playback-monitor streams that the
user never thinks of as a mic.

Operating on every real source (rather than only `@DEFAULT_AUDIO_SOURCE@`) is the
explicit requirement: a single toggle should affect all mics so no forgotten
device stays hot.

### Toggle semantics and the mixed state
The three states are derived by inspecting `pactl get-source-mute` for every real
source:
- all unmuted  → state "unmuted"
- all muted    → state "muted"
- some of each → state "indeterminate" (mixed)

The toggle is **not** a naive per-device flip (that would preserve a mixed state
forever). Instead it decides one target state for the whole set:
- If *every* real source is currently muted → unmute all.
- Otherwise (all unmuted, OR mixed) → mute all.

This makes the mixed case resolve safely toward privacy: pressing the key when
sources disagree mutes everything, matching the requirement "if there's a mixed
state … mute all of them." A second press then unmutes all.

### Waybar integration
A single `custom/mic` module driven by the same script in a `status` sub-command
that emits waybar JSON (`return-type: json`). It reports:
- `text`/icon per state (open mic, muted mic, and a distinct indeterminate glyph),
- an `alt`/`class` per state so `style.css` can color them (green/normal,
  red/muted, amber/indeterminate),
- a tooltip listing each source and its individual mute state.

Refresh is event-ish rather than polled: the module uses a waybar `signal` so the
toggle script can push an immediate update via `pkill -RTMIN+<n> waybar` right
after changing mute state, plus a modest `interval` fallback so external changes
(pavucontrol, other apps) are still reflected. Signals 8 and 9 are already taken
(meridian, spotify-playpause); this module will claim the next free real-time
signal (10).

Clicking the module performs the same toggle as the keybind (`on-click`), and
right-click opens `pavucontrol` on the input tab for manual per-device control,
mirroring the existing pulseaudio module's ergonomics.

### Placement / consistency
- Script lives at `~/.config/hypr/scripts/mic-mute.sh` (repo path
  `hypr/.config/hypr/scripts/mic-mute.sh`), matching every other helper script's
  location and the `on-click` conventions already used in the waybar config.
- The waybar module is added to `modules-right` next to `pulseaudio`, since it is
  audio-adjacent.
- Styling follows the existing inline `<span color=…>` idiom used throughout the
  waybar config; per-state classes in `style.css` are used only if inline spans
  prove insufficient for the indeterminate accent.
- The hyprland keybind goes in the audio group near the existing
  `XF86AudioMicMute` bind, using the exact combo the user requested:
  `bind = ALT CTRL SUPER SHIFT, F1, exec, ~/.config/hypr/scripts/mic-mute.sh toggle`.

### Constraints / open questions
- Waybar RTMIN signal number must not collide with existing signals (8, 9). Using
  10. If waybar's SIGRTMIN base differs, the script's `pkill -RTMIN+10` must match
  the module's `"signal": 10`.
- The script must be resilient to zero real sources (e.g. all devices
  unplugged): it should report a neutral/disabled state rather than error.
