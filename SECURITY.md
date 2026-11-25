# Aequalyn Shell — security model

The shell is the desktop's trusted process, and it is also the host for third-party
plugins. Security is layered: in-process for trusted first-party plugins, a
supervisor (sandbox) for untrusted ones, and a single root gate for anything that
needs privileges.

## Layers

1. **In-process plugins** — trusted first-party modules run inside the shell process.
   They can do anything the user can; consent is implicit by shipping them.
2. **Sandboxed plugins** — run as separate QuickShell instances under
   `tools/watchdog/aequalyn-watchdog`. The supervisor enforces RAM budgets, a
   heartbeat, and turns a plugin off on failure.
3. **Root gate** — the only door to root. Plugins declare `needsRoot` actions with
   pinned argv; approval is per-plugin, per-command, and recorded.

## Sandbox

- Supervisor: `tools/watchdog/aequalyn-watchdog` (Python).
  Runs the shell plus sandboxed plugins as separate QuickShell processes; refuses to
  run as root; monitors RAM and heartbeats; kills and disables on failure.
- Sandbox set: built-ins with `sandbox:true` (`batteryGuard`, `breaks`, `diskWatch`,
  `nightLight`, `watchdogTest`, `rootTest`); Store plugins with group `background`;
  `forceSandbox`/`noSandbox` from `~/.config/aequalyn/watchdog.json`.
- Config validation: `clean_root_actions` limits argv; escalation password is never
  placed in argv or logs.
- Honest limits: 3 s `/proc` sampling can miss short runs; static QML checks ban
  words but not string construction; same-user code can do anything the user can.
  The gate is consent and audit, not a hard wall.

## Root gate

- Only door: `aequalyn-watchdog exec-root <actionId>`.
- Caller pinned by `SO_PEERCRED` + `/proc` ancestors.
- Escalation window names the plugin and the exact command.
- Password fed to `sudo -S` on a pipe (never argv/log); 2-minute timeout = denial.
- "Always allow" remembers consent only.
- Tripwire scans process trees for `sudo/pkexec/su/doas` (direct, shell args, env/
  timeout pass-throughs), kills the attempt, counts it as a failure.
- First-party flows (browser theme, SDDM, store packages, installer) use the same gate.

## Risk hotspots

- QML uses `Quickshell.execDetached(["sh","-c", ...])` with string interpolation in
  places (`CaptureQuick.shot` mode; `watchdogTest.persist` paths; theme/kitty color
  injection; app launcher runs desktop `Exec` via `sh -c`).
- Store plugins are arbitrary code; key/screen group plugins run in-process.
- IPC targets are unauthenticated locally (any local process can call
  `qs ipc call ...`).
- Escalation password handling relies on a pipe.

## Mitigations present

- Atomic settings write (tmp + mv).
- Store id/entry validation; built-in id collision refusal.
- Watchdog config validation (`clean_root_actions` argv limits).
- Escalation password not in argv/log.

## Security concerns inherited from the core

See `aequalyn/Security.md` for system-level concerns: SDDM autologin, unverified
update path, first-boot AUR bootstrap, offline repo `SigLevel = Never`, password in
argv, theme install supply chain, path traversal in theme removal, installer placeholder
injection, command injection in `aequalyn-dpms`, QML palette injection, clipboard
history trust, global git config mutation, arbitrary jq filters.

## Reporting

Report security issues privately to the maintainers before public disclosure.
