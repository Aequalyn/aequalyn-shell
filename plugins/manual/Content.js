.pragma library

var sections = [
  {
    id: "keybindings",
    icon: "\u{F030C}",
    title: "Keybindings",
    body: [
      ["Apps and shell", [
        "Super + Return — Open terminal",
        "Super + E — Open files",
        "Super + Alt + F — Open Aequalyn file manager",
        "Super + B — Open browser",
        "Super + Space — Programs menu",
        "Super + D — App launcher",
        "Super + Alt + A — Default apps launcher",
        "Super + Alt + S — Store",
        "Super + , — Aequalyn settings",
        "Super + T — Themes picker",
        "Super + W — Wallpapers picker",
        "Super + Shift + W — Wallpaper rotation",
        "Super + Ctrl + Space — Next wallpaper",
        "Super + O — Display manager",
        "Super + I — Install chooser",
        "Super + R — Remove chooser",
        "Super + N — Dismiss notifications",
        "Super + Shift + N — Do Not Disturb",
        "Super + Ctrl + Shift + L — Lock screen"
      ]],
      ["Windows and layouts", [
        "Super + Q — Close window",
        "Super + Shift + V — Toggle floating",
        "Super + F — Fullscreen",
        "Super + J — Toggle split",
        "Super + G — Snap layouts flyout (floating)",
        "Super + L / Shift + L — Next/previous layout",
        "Super + Alt + L — Layouts page",
        "Super + Arrow — Focus nearest window",
        "Super + Shift + Arrow — Swap nearest window",
        "Super + - / = — Main pane smaller/larger",
        "Alt + Tab — Window switcher"
      ]],
      ["Workspaces", [
        "Super + 1..0 — Focus workspace 1..10",
        "Super + Shift + 1..0 — Move window to workspace",
        "Super + S — Toggle special workspace",
        "Super + Shift + S — Move window to special workspace"
      ]],
      ["Screenshots and recording", [
        "Print — Region screenshot, saved and copied",
        "Shift + Print — Full screenshot, saved and copied",
        "Super + Print — Region screenshot, saved only",
        "Super + Ctrl + S — Region screenshot, saved and copied",
        "Super + Ctrl + Shift + S — Full screenshot, saved and copied",
        "Super + Ctrl + R — Toggle screen recording",
        "Super + Shift + R — Toggle screen recording"
      ]],
      ["Built-in pack", [
        "Super + / — Key hints",
        "Super + Shift + Space — Command palette",
        "Super + = — Calculator",
        "Super + . — Emoji picker",
        "Super + Shift + P — Color picker",
        "Super + Alt + N — Quick notes",
        "Super + Shift + Escape — System monitor",
        "Super + Alt + X — Copy text from screen",
        "Super + Alt + T — Timer",
        "Super + F1 — This manual"
      ]]
    ]
  },
  {
    id: "aequalyn",
    icon: "\u{F031B}",
    title: "Aequalyn",
    body: [
      ["What it is", [
        "Aequalyn is an Arch Linux desktop built around Hyprland and a QuickShell shell.",
        "Wallpaper/theme colors, bar, docks, launcher, control center, notifications, lock screen, and system tools are designed to work together."
      ]],
      ["Everyday commands", [
        "aequalyn-update — Update Aequalyn and the shell",
        "aequalyn-shell-restart — Restart the shell",
        "aequalyn-theme <image> — Apply wallpaper/theme colors",
        "aequalyn-wallpaper next — Next wallpaper",
        "aequalyn-layout next — Next window layout",
        "aequalyn-screenshot region-clip — Region screenshot",
        "aequalyn-record toggle — Start/stop recording",
        "aequalyn-lock lock — Lock screen"
      ]],
      ["Important paths", [
        "~/.config/quickshell/ — Live shell config",
        "~/.config/aequalyn/settings.json — Desktop settings",
        "~/.config/hypr/ — Hyprland config",
        "~/.local/bin/ — User Aequalyn commands",
        "~/.local/state/aequalyn/ — Runtime/state and logs",
        "~/Pictures/Screenshots/ — Screenshots",
        "~/Videos/ — Screen recordings"
      ]],
      ["Control Center", [
        "Open with Super + , or the settings button.",
        "Use it for Appearance, Top bar, Docks, Displays, Power, Bluetooth, Plugins, and desktop behavior.",
        "Plugins can be enabled/disabled from Settings > Plugins."
      ]]
    ]
  },
  {
    id: "hyprland",
    icon: "\u{F0722}",
    title: "Hyprland",
    body: [
      ["Config files", [
        "~/.config/hypr/hyprland.lua — Main entry",
        "~/.config/hypr/keybinds.lua — Keybindings",
        "~/.config/hypr/input.lua — Input devices",
        "~/.config/hypr/monitors.lua — Monitors",
        "~/.config/hypr/window-rules.lua — Window rules",
        "~/.config/hypr/workspaces.lua — Workspace behavior",
        "~/.config/hypr/aequalyn/*.lua — Generated Aequalyn modules"
      ]],
      ["Useful commands", [
        "hyprctl monitors — Monitor status",
        "hyprctl clients — Open windows",
        "hyprctl activewindow — Focused window info",
        "hyprctl layers — Layer surfaces",
        "hyprctl binds — Active binds",
        "hyprctl reload — Reload Hyprland config"
      ]],
      ["Notes", [
        "Aequalyn manages some generated Hyprland files; prefer Settings or Aequalyn commands when available.",
        "Layout behavior is handled by Aequalyn layout modules and can be changed from layouts controls."
      ]]
    ]
  },
  {
    id: "arch",
    icon: "\u{F303}",
    title: "Arch",
    body: [
      ["Package management", [
        "sudo pacman -Syu — Full system upgrade",
        "sudo pacman -S <pkg> — Install package",
        "sudo pacman -Rns <pkg> — Remove package and unused deps",
        "pacman -Ss <term> — Search packages",
        "pacman -Qi <pkg> — Package info"
      ]],
      ["Services and logs", [
        "systemctl status <service> — Service status",
        "sudo systemctl enable --now <service> — Enable and start",
        "journalctl -b — Current boot logs",
        "journalctl --user -u <unit> — User unit logs",
        "systemctl --failed — Failed units"
      ]],
      ["Maintenance", [
        "Update regularly and read pacman output carefully.",
        "Check .pacnew files after updates.",
        "Keep snapshots/backups before major changes.",
        "Use aequalyn-update for Aequalyn-managed components."
      ]]
    ]
  },
  {
    id: "neovim",
    icon: "\u{E6AE}",
    title: "Neovim",
    body: [
      ["Getting started", [
        "Install: sudo pacman -S neovim",
        "Open: nvim . or nvim file.txt",
        "Config: ~/.config/nvim/"
      ]],
      ["Essentials", [
        "i — Insert mode",
        "Esc — Normal mode",
        "v / V — Visual / visual line",
        ":w — Save",
        ":q — Quit",
        ":wq — Save and quit",
        "/text — Search",
        "n / N — Next/previous match",
        "u / Ctrl+r — Undo/redo"
      ]],
      ["Movement and editing", [
        "h j k l — Move",
        "gg / G — File start/end",
        "0 / $ — Line start/end",
        "w / b — Word forward/back",
        "dd / yy / p — Delete/yank/paste line"
      ]]
    ]
  },
  {
    id: "bash",
    icon: "\u{F489}",
    title: "Bash",
    body: [
      ["Common files", [
        "~/.bashrc — Interactive shell config",
        "~/.bash_profile — Login shell config",
        "~/.bash_logout — Logout behavior"
      ]],
      ["Everyday commands", [
        "pwd — Current directory",
        "ls -la — List files",
        "cd <dir> — Change directory",
        "cp -a src dst — Copy preserving attributes",
        "mv src dst — Move/rename",
        "rm -i file — Remove with prompt",
        "grep -R \"text\" . — Recursive search",
        "find . -name '*.qml' — Find files"
      ]],
      ["Good habits", [
        "Quote paths with spaces.",
        "Use Ctrl+R for history search.",
        "Check scripts with bash -n script.sh before running.",
        "Keep shell customizations small and backed up."
      ]]
    ]
  },
  {
    id: "tmux",
    icon: "\u{F489}",
    title: "tmux",
    body: [
      ["Basics", [
        "Install: sudo pacman -S tmux",
        "tmux new -s work — New named session",
        "tmux ls — List sessions",
        "tmux attach -t work — Attach",
        "Prefix key: Ctrl+b"
      ]],
      ["Common keys", [
        "Ctrl+b, d — Detach",
        "Ctrl+b, c — New window",
        "Ctrl+b, n / p — Next/previous window",
        "Ctrl+b, % — Split vertically",
        "Ctrl+b, \" — Split horizontally",
        "Ctrl+b, arrows — Move between panes",
        "Ctrl+b, x — Close pane",
        "Ctrl+b, [ — Scroll/copy mode"
      ]],
      ["Config", [
        "User config: ~/.tmux.conf",
        "Reload: tmux source-file ~/.tmux.conf"
      ]]
    ]
  },
  {
    id: "herdr",
    icon: "\u{F0B1B}",
    title: "Herdr",
    body: [
      ["What it is", [
        "Herdr is a terminal workspace/runtime for running multiple coding agents in real terminal panes.",
        "It keeps agent sessions alive in a background service, tracks agent state, and can work across local and SSH machines."
      ]],
      ["Core concepts", [
        "Workspace — Project/task container",
        "Tab — Layout inside a workspace",
        "Pane — Real terminal",
        "Agent — Recognized agent process in a pane",
        "States — working, blocked, done, idle, unknown"
      ]],
      ["Practical use", [
        "Install using the official Herdr install method for your system.",
        "Use it when you need persistent agent workspaces alongside your Aequalyn desktop.",
        "Closing a client usually leaves the underlying service running; closing panes/tabs or stopping the server ends that work."
      ]]
    ]
  },
  {
    id: "community",
    icon: "\u{F0C0}",
    title: "Community",
    body: [
      ["Participate", [
        "Report issues with clear reproduction steps, logs, and expected/actual behavior.",
        "Contribute focused fixes and test before sharing.",
        "Share themes, plugins, looks, and workflows through Aequalyn repositories.",
        "Improve docs when you find gaps or unclear steps."
      ]],
      ["Good habits", [
        "Keep changes minimal and reviewable.",
        "Protect user settings and data.",
        "Document migrations or behavior changes.",
        "Be specific and helpful when answering questions."
      ]],
      ["Where to look", [
        "Aequalyn organization repositories on GitHub",
        "Issue trackers for bugs and requests",
        "docs/ for architecture and behavior details",
        "PLUGINS.md, THEMES.md, and SKILL.md for extension workflows"
      ]]
    ]
  }
];

function find(id) {
  for (var i = 0; i < sections.length; i++) if (sections[i].id === id) return sections[i];
  return sections[0];
}
