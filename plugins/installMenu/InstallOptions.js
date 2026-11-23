.pragma library
.import "../store/PackageIds.js" as PackageIds

// The curated install chooser. Every entry either goes through the Store's
// package path or runs one of Aequalyn's own tools. Labels stay plain and
// product-neutral; "See also" is built from the other choices in the category.
function pkg(source, name) {
    return ["qs", "ipc", "call", "store", "package", source, name];
}
function agent(id) {
    return ["aequalyn-ai-tool", "install", id];
}
// A short, visible shell session for the handful of choices that are a setup
// step rather than a package (database containers, web app creation).
function term(script) {
    return ["sh", "-c", 'exec xdg-terminal-exec sh -c "$1"', "sh",
            script + '; echo; read -rp "Done. Press Enter to close " _'];
}
// A package row is [id, category, label, icon, source, name, words]. The source
// is the visible one; the Store path gets its lowercase package backend.
function packageChoice(row) {
    var via = ({ Arch: "arch", AUR: "aur", Flatpak: "flatpak", Snap: "snap" })[row[4]] || "aur";
    return { id: row[0], category: row[1], label: row[2], icon: row[3], source: row[4],
             cmd: pkg(via, row[5]), words: row[6] };
}

var categories = [
    { key: "all",        label: "All",         icon: "\u{F03A}" },
    { key: "ai",         label: "AI",          icon: "\u{F06A9}" },
    { key: "service",    label: "Service",     icon: "\u{F0528}" },
    { key: "development",label: "Development", icon: "\u{F0B8C}" },
    { key: "editor",     label: "Editor",      icon: "\u{F075B}" },
    { key: "style",      label: "Style",       icon: "\u{F053E}" },
    { key: "gaming",     label: "Gaming",      icon: "\u{F11B3}" },
    { key: "browser",    label: "Browser",     icon: "\u{F0834}" },
    { key: "terminal",   label: "Terminal",    icon: "\u{F489}" },
    { key: "other",      label: "Uncategorised", icon: "\u{F03A}" }
];

var options = [
    { id: "ai-amp", category: "ai", label: "Amp Desktop", icon: "\u{F06A9}", source: "AUR", cmd: pkg("aur", "amp-desktop-bin"), words: "desktop coding agent" },
    { id: "ai-chatgpt", category: "ai", label: "ChatGPT Desktop", icon: "\u{F06A9}", source: "AUR", cmd: pkg("aur", "codex-desktop-bin"), words: "desktop app" },
    { id: "ai-claude-desktop", category: "ai", label: "Claude Desktop", icon: "\u{F06A9}", source: "AUR", cmd: pkg("aur", "claude-desktop"), words: "desktop app" },
    { id: "ai-grok", category: "ai", label: "Grok Bot", icon: "\u{F06A9}", source: "AUR", cmd: pkg("aur", "grok-bot-bin"), words: "desktop app" },
    { id: "ai-hermes", category: "ai", label: "Hermes Desktop", icon: "\u{F06A9}", source: "AUR", cmd: pkg("aur", "hermes-agent-desktop-bin"), words: "desktop app" },
    { id: "ai-lmstudio", category: "ai", label: "LM Studio", icon: "\u{F06A9}", source: "AUR", cmd: pkg("aur", "lmstudio-bin"), words: "local models desktop" },
    { id: "ai-ollama", category: "ai", label: "Ollama", icon: "\u{F06A9}", source: "Arch", cmd: pkg("arch", "ollama"), words: "local models server" },
    { id: "ai-openclaw", category: "ai", label: "OpenClaw", icon: "\u{F06A9}", source: "AUR", cmd: pkg("aur", "openclaw"), words: "desktop coding agent" },
    { id: "ai-perplexity", category: "ai", label: "Perplexity", icon: "\u{F06A9}", source: "AUR", cmd: pkg("aur", "perplexity"), words: "desktop app" },
    { id: "ai-t3", category: "ai", label: "T3 Code", icon: "\u{F06A9}", source: "AUR", cmd: pkg("aur", "t3code-bin"), words: "desktop app" },
    { id: "ai-claude", category: "ai", label: "Claude Code", icon: "\u{F0E0}", source: "Agent", cmd: agent("claude"), words: "anthropic terminal coding agent" },
    { id: "ai-codex", category: "ai", label: "Codex CLI", icon: "\u{F0E0}", source: "Agent", cmd: agent("codex"), words: "openai terminal coding agent" },
    { id: "ai-opencode", category: "ai", label: "OpenCode", icon: "\u{F0E0}", source: "Agent", cmd: agent("opencode"), words: "open source terminal coding agent" },
    { id: "ai-copilot", category: "ai", label: "Copilot CLI", icon: "\u{F0E0}", source: "Agent", cmd: agent("copilot"), words: "github terminal coding agent" },
    { id: "ai-qwen", category: "ai", label: "Qwen Code", icon: "\u{F0E0}", source: "Agent", cmd: agent("qwen"), words: "terminal coding agent" },
    { id: "ai-kilo", category: "ai", label: "Kilo Code", icon: "\u{F0E0}", source: "Agent", cmd: agent("kilo"), words: "terminal coding agent" },
    { id: "ai-cline", category: "ai", label: "Cline", icon: "\u{F0E0}", source: "Agent", cmd: agent("cline"), words: "terminal coding agent" },
    { id: "ai-crush", category: "ai", label: "Crush", icon: "\u{F0E0}", source: "Agent", cmd: agent("crush"), words: "charm terminal coding agent" },

    { id: "svc-1password", category: "service", label: "1Password", icon: "\u{F0528}", source: "AUR", cmd: pkg("aur", "1password"), words: "password manager" },
    { id: "svc-bitwarden", category: "service", label: "Bitwarden", icon: "\u{F0528}", source: "Arch", cmd: pkg("arch", "bitwarden"), words: "password manager" },
    { id: "svc-chromium-account", category: "service", label: "Chromium sign-in", icon: "\u{F0528}", source: "Setup", cmd: ["chromium", "chrome://settings/syncSetup"], words: "account google sync" },
    { id: "svc-dropbox", category: "service", label: "Dropbox", icon: "\u{F0528}", source: "AUR", cmd: pkg("aur", "dropbox"), words: "cloud files sync" },
    { id: "svc-microsoft", category: "service", label: "Microsoft 365", icon: "\u{F0528}", source: "Web app", cmd: ["aequalyn-webapp", "add", "--name", "Microsoft 365", "--url", "https://www.office.com/", "--category", "office"], words: "outlook word excel teams onedrive" },
    { id: "svc-nordvpn", category: "service", label: "NordVPN", icon: "\u{F0528}", source: "AUR", cmd: pkg("aur", "nordvpn-bin"), words: "vpn" },
    { id: "svc-signal", category: "service", label: "Signal", icon: "\u{F0528}", source: "Arch", cmd: pkg("arch", "signal-desktop"), words: "chat messenger" },
    { id: "svc-spotify", category: "service", label: "Spotify", icon: "\u{F0528}", source: "AUR", cmd: pkg("aur", "spotify"), words: "music" },
    { id: "svc-tailscale", category: "service", label: "Tailscale", icon: "\u{F0528}", source: "Arch", cmd: pkg("arch", "tailscale"), words: "vpn network" },
    { id: "svc-slack", category: "service", label: "Slack", icon: "\u{F0528}", source: "AUR", cmd: pkg("aur", "slack-desktop"), words: "chat work" },
    { id: "svc-notion", category: "service", label: "Notion", icon: "\u{F0528}", source: "AUR", cmd: pkg("aur", "notion-app-electron-bin"), words: "notes" },
    { id: "svc-syncthing", category: "service", label: "Syncthing", icon: "\u{F0528}", source: "Arch", cmd: pkg("arch", "syncthing"), words: "files sync" },
    { id: "svc-once", category: "service", label: "ONCE", icon: "\u{F0528}", source: "AUR", cmd: pkg("aur", "once-bin"), words: "password manager" },

    { id: "dev-rails", category: "development", label: "Ruby on Rails", icon: "\u{E21E}", source: "AUR", cmd: pkg("aur", "ruby-rails"), words: "ruby web framework" },
    { id: "dev-docker", category: "development", label: "Docker", icon: "\u{F0521}", source: "Arch", cmd: pkg("arch", "docker"), words: "containers" },
    { id: "dev-docker-compose", category: "development", label: "Docker Compose", icon: "\u{F0521}", source: "Arch", cmd: pkg("arch", "docker-compose"), words: "containers" },
    { id: "dev-docker-db", category: "development", label: "Docker DB", icon: "\u{F0521}", source: "Setup", cmd: term("docker run -d --name aequalyn-postgres -e POSTGRES_PASSWORD=aequalyn -p 5432:5432 postgres:16 || true"), words: "database postgres containers" },
    { id: "dev-node", category: "development", label: "Node.js", icon: "\u{E718}", source: "Arch", cmd: pkg("arch", "nodejs"), words: "javascript runtime" },
    { id: "dev-bun", category: "development", label: "Bun", icon: "\u{E72C}", source: "Arch", cmd: pkg("arch", "bun"), words: "javascript runtime" },
    { id: "dev-deno", category: "development", label: "Deno", icon: "\u{E72C}", source: "Arch", cmd: pkg("arch", "deno"), words: "javascript runtime" },
    { id: "dev-go", category: "development", label: "Go", icon: "\u{E27F}", source: "Arch", cmd: pkg("arch", "go"), words: "language" },
    { id: "dev-python", category: "development", label: "Python", icon: "\u{E606}", source: "Arch", cmd: pkg("arch", "python"), words: "language" },
    { id: "dev-rust", category: "development", label: "Rust", icon: "\u{E7A8}", source: "Arch", cmd: pkg("arch", "rust"), words: "language" },
    { id: "dev-java", category: "development", label: "Java", icon: "\u{E738}", source: "Arch", cmd: pkg("arch", "jdk-openjdk"), words: "language" },
    { id: "dev-dotnet", category: "development", label: ".NET", icon: "\u{E77C}", source: "Arch", cmd: pkg("arch", "dotnet-sdk"), words: "language csharp" },
    { id: "dev-ocaml", category: "development", label: "OCaml", icon: "\u{E67A}", source: "Arch", cmd: pkg("arch", "ocaml"), words: "language" },
    { id: "dev-clojure", category: "development", label: "Clojure", icon: "\u{E768}", source: "Arch", cmd: pkg("arch", "clojure"), words: "language" },
    { id: "dev-scala", category: "development", label: "Scala", icon: "\u{E737}", source: "AUR", cmd: pkg("aur", "scala3"), words: "language" },
    { id: "dev-zig", category: "development", label: "Zig", icon: "\u{E6A9}", source: "Arch", cmd: pkg("arch", "zig"), words: "language" },
    { id: "dev-php", category: "development", label: "PHP", icon: "\u{E73D}", source: "Arch", cmd: pkg("arch", "php"), words: "language" },
    { id: "dev-laravel", category: "development", label: "Laravel", icon: "\u{E73D}", source: "AUR", cmd: pkg("aur", "laravel"), words: "php framework" },
    { id: "dev-symfony", category: "development", label: "Symfony", icon: "\u{E73D}", source: "AUR", cmd: pkg("aur", "symfony-cli"), words: "php framework" },
    { id: "dev-elixir", category: "development", label: "Elixir", icon: "\u{E62D}", source: "Arch", cmd: pkg("arch", "elixir"), words: "language" },
    { id: "dev-phoenix", category: "development", label: "Phoenix", icon: "\u{E62D}", source: "AUR", cmd: pkg("aur", "phoenix"), words: "elixir framework" },

    { id: "ed-vscode", category: "editor", label: "VSCode", icon: "\u{E70C}", source: "AUR", cmd: pkg("aur", "visual-studio-code-bin"), words: "editor microsoft" },
    { id: "ed-cursor", category: "editor", label: "Cursor", icon: "\u{E70C}", source: "AUR", cmd: pkg("aur", "cursor-bin"), words: "editor ai" },
    { id: "ed-zed", category: "editor", label: "Zed", icon: "\u{E70C}", source: "Arch", cmd: pkg("arch", "zed"), words: "editor" },
    { id: "ed-sublime", category: "editor", label: "Sublime Text", icon: "\u{E70C}", source: "AUR", cmd: pkg("aur", "sublime-text-4"), words: "editor" },
    { id: "ed-helix", category: "editor", label: "Helix", icon: "\u{E70C}", source: "Arch", cmd: pkg("arch", "helix"), words: "editor modal" },
    { id: "ed-vim", category: "editor", label: "Vim", icon: "\u{E62B}", source: "Arch", cmd: pkg("arch", "vim"), words: "editor modal" },
    { id: "ed-emacs", category: "editor", label: "Emacs", icon: "\u{E632}", source: "Arch", cmd: pkg("arch", "emacs"), words: "editor" },
    { id: "ed-neovim", category: "editor", label: "Neovim", icon: "\u{E62B}", source: "Arch", cmd: pkg("arch", "neovim"), words: "editor modal" },
    { id: "ed-micro", category: "editor", label: "Micro", icon: "\u{E70C}", source: "Arch", cmd: pkg("arch", "micro"), words: "editor terminal" },

    { id: "style-theme", category: "style", label: "Pick a theme", icon: "\u{F03D8}", source: "Picker", cmd: ["qs", "ipc", "call", "atelier", "toggle", "themes"], words: "colours look" },
    { id: "style-background", category: "style", label: "Pick a wallpaper", icon: "\u{F02E9}", source: "Picker", cmd: ["qs", "ipc", "call", "atelier", "toggle", "wallpapers"], words: "background image" },
    { id: "style-cascadia", category: "style", label: "Cascadia Mono", icon: "\u{F0311}", source: "Arch", cmd: pkg("arch", "ttf-cascadia-mono-nerd"), words: "font" },
    { id: "style-meslo", category: "style", label: "Meslo LG Mono", icon: "\u{F0311}", source: "Arch", cmd: pkg("arch", "ttf-meslo-nerd"), words: "font" },
    { id: "style-fira", category: "style", label: "Fira Code", icon: "\u{F0311}", source: "Arch", cmd: pkg("arch", "ttf-firacode-nerd"), words: "font" },
    { id: "style-victor", category: "style", label: "Victor Code", icon: "\u{F0311}", source: "Arch", cmd: pkg("arch", "ttf-victor-mono-nerd"), words: "font" },
    { id: "style-bitstream", category: "style", label: "Bitstream Vera Mono", icon: "\u{F0311}", source: "Arch", cmd: pkg("arch", "ttf-bitstream-vera-mono-nerd"), words: "font" },
    { id: "style-iosevka", category: "style", label: "Iosevka", icon: "\u{F0311}", source: "Arch", cmd: pkg("arch", "ttf-iosevka-nerd"), words: "font" },

    { id: "game-steam", category: "gaming", label: "Steam", icon: "\u{F1B6}", source: "Arch", cmd: pkg("arch", "steam"), words: "games" },
    { id: "game-retroarch", category: "gaming", label: "RetroArch", icon: "\u{F11B3}", source: "Arch", cmd: pkg("arch", "retroarch"), words: "emulator retro games" },
    { id: "game-retro-launcher", category: "gaming", label: "RetroArch launcher", icon: "\u{F11B3}", source: "Launcher", cmd: ["retroarch"], words: "emulator retro games" },
    { id: "game-minecraft", category: "gaming", label: "Minecraft", icon: "\u{F11B3}", source: "AUR", cmd: pkg("aur", "minecraft-launcher"), words: "games" },
    { id: "game-geforce", category: "gaming", label: "GeForce NOW", icon: "\u{F11B3}", source: "Flatpak", cmd: pkg("flatpak", "com.nvidia.geforcenow"), words: "cloud games" },
    { id: "game-xbox-cloud", category: "gaming", label: "Xbox Cloud Gaming", icon: "\u{F11B3}", source: "Web app", cmd: ["aequalyn-webapp", "add", "--name", "Xbox Cloud Gaming", "--url", "https://www.xbox.com/play", "--category", "games"], words: "cloud games" },
    { id: "game-xbox", category: "gaming", label: "Xbox Controllers", icon: "\u{F11B3}", source: "AUR", cmd: pkg("aur", "xpadneo-dkms"), words: "controller drivers" },
    { id: "game-battlenet", category: "gaming", label: "Battle.net", icon: "\u{F11B3}", source: "AUR", cmd: pkg("aur", "battlenet-proton"), words: "games launcher" },
    { id: "game-lutris", category: "gaming", label: "Lutris", icon: "\u{F11B3}", source: "Arch", cmd: pkg("arch", "lutris"), words: "games launcher" },
    { id: "game-heroic", category: "gaming", label: "Heroic (Epic Games)", icon: "\u{F11B3}", source: "AUR", cmd: pkg("aur", "heroic-games-launcher-bin"), words: "epic games launcher" },
    { id: "game-gamemode", category: "gaming", label: "GameMode", icon: "\u{F11B3}", source: "Arch", cmd: pkg("arch", "gamemode"), words: "performance games" },
    { id: "game-mangohud", category: "gaming", label: "MangoHud", icon: "\u{F11B3}", source: "Arch", cmd: pkg("arch", "mangohud"), words: "overlay games" },

    { id: "web-chrome", category: "browser", label: "Chrome", icon: "\u{F0834}", source: "AUR", cmd: pkg("aur", "google-chrome"), words: "browser" },
    { id: "web-edge", category: "browser", label: "Edge", icon: "\u{F0834}", source: "AUR", cmd: pkg("aur", "microsoft-edge-stable-bin"), words: "browser" },
    { id: "web-brave", category: "browser", label: "Brave", icon: "\u{F0834}", source: "AUR", cmd: pkg("aur", "brave-bin"), words: "browser" },
    { id: "web-brave-origin", category: "browser", label: "Brave Origin", icon: "\u{F0834}", source: "AUR", cmd: pkg("aur", "brave-origin-bin"), words: "browser" },
    { id: "web-firefox", category: "browser", label: "Firefox", icon: "\u{F0834}", source: "Arch", cmd: pkg("arch", "firefox"), words: "browser" },
    { id: "web-zen", category: "browser", label: "Zen", icon: "\u{F0834}", source: "AUR", cmd: pkg("aur", "zen-browser-bin"), words: "browser" },
    { id: "web-chromium", category: "browser", label: "Chromium", icon: "\u{F0834}", source: "Arch", cmd: pkg("arch", "chromium"), words: "browser" },

    { id: "term-alacritty", category: "terminal", label: "Alacritty", icon: "\u{F489}", source: "Arch", cmd: pkg("arch", "alacritty"), words: "terminal emulator" },
    { id: "term-foot", category: "terminal", label: "Foot", icon: "\u{F489}", source: "Arch", cmd: pkg("arch", "foot"), words: "terminal emulator" },
    { id: "term-ghostty", category: "terminal", label: "Ghostty", icon: "\u{F489}", source: "Arch", cmd: pkg("arch", "ghostty"), words: "terminal emulator" },
    { id: "term-kitty", category: "terminal", label: "Kitty", icon: "\u{F489}", source: "Arch", cmd: pkg("arch", "kitty"), words: "terminal emulator" },
    { id: "term-wezterm", category: "terminal", label: "WezTerm", icon: "\u{F489}", source: "Arch", cmd: pkg("arch", "wezterm"), words: "terminal emulator" }
];

// Every Apps category has thirty real package choices. They are kept together
// here rather than scattered through the hand-written list above, so a category
// stays full without repeating a label or a package name.
(function () {
    var rows = [
        // AI
        ["ai-open-webui", "ai", "Open WebUI", "\u{F06A9}", "AUR", "open-webui", "local chat web ui"],
        ["ai-ollama-webui", "ai", "Ollama WebUI", "\u{F06A9}", "AUR", "ollama-webui-bin", "local chat web ui"],
        ["ai-jan", "ai", "Jan", "\u{F06A9}", "AUR", "jan-bin", "local chat desktop"],
        ["ai-gpt4all", "ai", "GPT4All", "\u{F06A9}", "AUR", "gpt4all", "local chat desktop"],
        ["ai-llamafile", "ai", "llamafile", "\u{F06A9}", "AUR", "llamafile", "local model runner"],
        ["ai-textgen-webui", "ai", "Text Generation WebUI", "\u{F06A9}", "AUR", "text-generation-webui", "local model web ui"],
        ["ai-comfyui", "ai", "ComfyUI", "\u{F06A9}", "AUR", "comfyui", "image generation"],
        ["ai-sd-webui", "ai", "Stable Diffusion WebUI", "\u{F06A9}", "AUR", "stable-diffusion-webui", "image generation"],
        ["ai-invokeai", "ai", "InvokeAI", "\u{F06A9}", "AUR", "invokeai", "image generation"],
        ["ai-fooocus", "ai", "Fooocus", "\u{F06A9}", "AUR", "fooocus", "image generation"],
        ["ai-localai", "ai", "LocalAI", "\u{F06A9}", "AUR", "localai-bin", "local models server"],
        ["ai-llamacpp", "ai", "llama.cpp", "\u{F06A9}", "Arch", "llama.cpp", "local model runner"],
        ["ai-whispercpp", "ai", "whisper.cpp", "\u{F06A9}", "Arch", "whisper.cpp", "speech transcription"],
        ["ai-anythingllm", "ai", "AnythingLLM", "\u{F06A9}", "AUR", "anythingllm-bin", "local knowledge chat"],
        ["ai-cherrystudio", "ai", "Cherry Studio", "\u{F06A9}", "AUR", "cherry-studio-bin", "local chat desktop"],
        ["ai-windsurf", "ai", "Windsurf", "\u{F06A9}", "AUR", "windsurf-bin", "desktop coding agent"],
        ["ai-trae", "ai", "Trae", "\u{F06A9}", "AUR", "trae-bin", "desktop coding agent"],
        ["ai-librechat", "ai", "LibreChat", "\u{F06A9}", "AUR", "librechat", "chat web ui"],
        ["ai-tabby", "ai", "Tabby", "\u{F06A9}", "AUR", "tabby-bin", "local coding server"],
        ["ai-aider", "ai", "Aider", "\u{F0E0}", "AUR", "aider", "terminal coding agent"],

        // Service
        ["svc-discord", "service", "Discord", "\u{F0528}", "Arch", "discord", "chat voice"],
        ["svc-telegram", "service", "Telegram", "\u{F0528}", "Arch", "telegram-desktop", "chat messenger"],
        ["svc-element", "service", "Element", "\u{F0528}", "Arch", "element-desktop", "chat matrix"],
        ["svc-whatsapp", "service", "WhatsApp", "\u{F0528}", "AUR", "whatsapp-for-linux", "chat messenger"],
        ["svc-teams", "service", "Teams", "\u{F0528}", "AUR", "teams", "chat work microsoft"],
        ["svc-zoom", "service", "Zoom", "\u{F0528}", "AUR", "zoom", "video meetings"],
        ["svc-google-drive", "service", "Google Drive", "\u{F0528}", "AUR", "google-drive", "cloud files sync"],
        ["svc-megasync", "service", "MEGASync", "\u{F0528}", "AUR", "megasync", "cloud files sync"],
        ["svc-pcloud", "service", "pCloud", "\u{F0528}", "AUR", "pcloud", "cloud files sync"],
        ["svc-protonvpn", "service", "Proton VPN", "\u{F0528}", "AUR", "protonvpn", "vpn privacy"],
        ["svc-mullvad", "service", "Mullvad VPN", "\u{F0528}", "AUR", "mullvad-vpn", "vpn privacy"],
        ["svc-openvpn", "service", "OpenVPN", "\u{F0528}", "Arch", "openvpn", "vpn network"],
        ["svc-wireguard", "service", "WireGuard", "\u{F0528}", "Arch", "wireguard-tools", "vpn network"],
        ["svc-cloudflared", "service", "Cloudflared", "\u{F0528}", "AUR", "cloudflared", "tunnel network"],
        ["svc-rsync", "service", "rsync", "\u{F0528}", "Arch", "rsync", "files sync backup"],
        ["svc-rclone", "service", "rclone", "\u{F0528}", "Arch", "rclone", "cloud files sync"],
        ["svc-borg", "service", "BorgBackup", "\u{F0528}", "Arch", "borg", "backup"],
        ["svc-restic", "service", "Restic", "\u{F0528}", "Arch", "restic", "backup"],
        ["svc-nextcloud", "service", "Nextcloud", "\u{F0528}", "Arch", "nextcloud-desktop", "cloud files sync"],

        // Development
        ["dev-git", "development", "Git", "\u{F0B8C}", "Arch", "git", "version control"],
        ["dev-gh", "development", "GitHub CLI", "\u{F0B8C}", "Arch", "github-cli", "git github"],
        ["dev-glab", "development", "GitLab CLI", "\u{F0B8C}", "Arch", "glab", "git gitlab"],
        ["dev-cmake", "development", "CMake", "\u{F0B8C}", "Arch", "cmake", "build"],
        ["dev-ninja", "development", "Ninja", "\u{F0B8C}", "Arch", "ninja", "build"],
        ["dev-gcc", "development", "GCC", "\u{F0B8C}", "Arch", "gcc", "compiler"],
        ["dev-clang", "development", "Clang", "\u{F0B8C}", "Arch", "clang", "compiler"],
        ["dev-gdb", "development", "GDB", "\u{F0B8C}", "Arch", "gdb", "debugger"],
        ["dev-podman", "development", "Podman", "\u{F0B8C}", "Arch", "podman", "containers"],
        ["dev-postgresql", "development", "PostgreSQL", "\u{F0B8C}", "Arch", "postgresql", "database"],

        // Editor
        ["ed-code-oss", "editor", "Code OSS", "\u{E70C}", "AUR", "code-oss", "editor open source"],
        ["ed-vscodium", "editor", "VSCodium", "\u{E70C}", "AUR", "vscodium-bin", "editor open source"],
        ["ed-atom", "editor", "Atom", "\u{E70C}", "AUR", "atom", "editor"],
        ["ed-pycharm", "editor", "PyCharm", "\u{E70C}", "AUR", "pycharm-community", "editor python ide"],
        ["ed-pycharm-pro", "editor", "PyCharm Pro", "\u{E70C}", "AUR", "pycharm-professional", "editor python ide"],
        ["ed-intellij", "editor", "IntelliJ IDEA", "\u{E70C}", "Arch", "intellij-idea-community-edition", "editor java ide"],
        ["ed-intellij-ultimate", "editor", "IntelliJ Ultimate", "\u{E70C}", "AUR", "intellij-idea-ultimate-edition", "editor java ide"],
        ["ed-webstorm", "editor", "WebStorm", "\u{E70C}", "AUR", "webstorm", "editor web ide"],
        ["ed-goland", "editor", "GoLand", "\u{E70C}", "AUR", "goland", "editor go ide"],
        ["ed-rustrover", "editor", "RustRover", "\u{E70C}", "AUR", "rustrover", "editor rust ide"],
        ["ed-phpstorm", "editor", "PhpStorm", "\u{E70C}", "AUR", "phpstorm", "editor php ide"],
        ["ed-android-studio", "editor", "Android Studio", "\u{E70C}", "AUR", "android-studio", "editor android ide"],
        ["ed-geany", "editor", "Geany", "\u{E70C}", "Arch", "geany", "editor"],
        ["ed-kate", "editor", "Kate", "\u{E70C}", "Arch", "kate", "editor kde"],
        ["ed-gedit", "editor", "gedit", "\u{E70C}", "Arch", "gedit", "editor gnome"],
        ["ed-mousepad", "editor", "Mousepad", "\u{E70C}", "Arch", "mousepad", "editor xfce"],
        ["ed-pluma", "editor", "Pluma", "\u{E70C}", "Arch", "pluma", "editor mate"],
        ["ed-leafpad", "editor", "Leafpad", "\u{E70C}", "AUR", "leafpad", "editor"],
        ["ed-bluefish", "editor", "Bluefish", "\u{E70C}", "AUR", "bluefish", "editor web"],
        ["ed-brackets", "editor", "Brackets", "\u{E70C}", "AUR", "brackets-bin", "editor web"],
        ["ed-nova", "editor", "Nova", "\u{E70C}", "AUR", "nova-bin", "editor mac"],

        // Style
        ["style-jetbrains", "style", "JetBrains Mono", "\u{F0311}", "Arch", "ttf-jetbrains-mono-nerd", "font mono"],
        ["style-ubuntu", "style", "Ubuntu Font", "\u{F0311}", "Arch", "ttf-ubuntu-font-family", "font"],
        ["style-dejavu", "style", "DejaVu", "\u{F0311}", "Arch", "ttf-dejavu", "font"],
        ["style-liberation", "style", "Liberation", "\u{F0311}", "Arch", "ttf-liberation", "font"],
        ["style-noto", "style", "Noto", "\u{F0311}", "Arch", "noto-fonts", "font"],
        ["style-noto-emoji", "style", "Noto Emoji", "\u{F0311}", "Arch", "noto-fonts-emoji", "font emoji"],
        ["style-roboto", "style", "Roboto", "\u{F0311}", "Arch", "ttf-roboto", "font"],
        ["style-open-sans", "style", "Open Sans", "\u{F0311}", "Arch", "ttf-open-sans", "font"],
        ["style-lato", "style", "Lato", "\u{F0311}", "Arch", "ttf-lato", "font"],
        ["style-sourcecode", "style", "Source Code Pro", "\u{F0311}", "Arch", "ttf-sourcecodepro-nerd", "font mono"],
        ["style-hack", "style", "Hack", "\u{F0311}", "Arch", "ttf-hack-nerd", "font mono"],
        ["style-inconsolata", "style", "Inconsolata", "\u{F0311}", "Arch", "ttf-inconsolata-nerd", "font mono"],
        ["style-anonymous", "style", "Anonymous Pro", "\u{F0311}", "Arch", "ttf-anonymous-pro", "font mono"],
        ["style-droid", "style", "Droid Sans", "\u{F0311}", "Arch", "ttf-droid", "font"],
        ["style-fira-sans", "style", "Fira Sans", "\u{F0311}", "Arch", "ttf-fira-sans", "font"],
        ["style-adwaita", "style", "Adwaita Icons", "\u{F053E}", "Arch", "adwaita-icon-theme", "icons"],
        ["style-papirus", "style", "Papirus", "\u{F053E}", "Arch", "papirus-icon-theme", "icons"],
        ["style-numix", "style", "Numix", "\u{F053E}", "AUR", "numix-icon-theme-git", "icons"],
        ["style-breeze", "style", "Breeze", "\u{F053E}", "Arch", "breeze", "icons theme kde"],
        ["style-oxygen", "style", "Oxygen", "\u{F053E}", "Arch", "oxygen", "icons theme kde"],
        ["style-kvantum", "style", "KVantum", "\u{F053E}", "Arch", "kvantum", "theme qt"],
        ["style-qt5ct", "style", "Qt5 Settings", "\u{F053E}", "Arch", "qt5ct", "theme qt"],
        ["style-qt6ct", "style", "Qt6 Settings", "\u{F053E}", "Arch", "qt6ct", "theme qt"],
        ["style-nwg-look", "style", "NWG Look", "\u{F053E}", "AUR", "nwg-look", "theme gtk"],

        // Gaming
        ["game-wine", "gaming", "Wine", "\u{F11B3}", "Arch", "wine", "windows games"],
        ["game-wine-staging", "gaming", "Wine Staging", "\u{F11B3}", "AUR", "wine-staging", "windows games"],
        ["game-proton-ge", "gaming", "Proton GE", "\u{F11B3}", "AUR", "proton-ge-custom-bin", "steam proton"],
        ["game-playonlinux", "gaming", "PlayOnLinux", "\u{F11B3}", "AUR", "playonlinux", "windows games"],
        ["game-vkbasalt", "gaming", "vkBasalt", "\u{F11B3}", "AUR", "vkbasalt", "overlay games"],
        ["game-libstrangle", "gaming", "Libstrangle", "\u{F11B3}", "AUR", "libstrangle", "performance games"],
        ["game-dxvk", "gaming", "DXVK", "\u{F11B3}", "AUR", "dxvk", "windows games"],
        ["game-vkd3d", "gaming", "VKD3D", "\u{F11B3}", "AUR", "vkd3d-proton-bin", "windows games"],
        ["game-ppsspp", "gaming", "PPSSPP", "\u{F11B3}", "Arch", "ppsspp", "emulator psp"],
        ["game-dolphin", "gaming", "Dolphin", "\u{F11B3}", "AUR", "dolphin-emu", "emulator gamecube"],
        ["game-rpcs3", "gaming", "RPCS3", "\u{F11B3}", "AUR", "rpcs3", "emulator ps3"],
        ["game-yuzu", "gaming", "Yuzu", "\u{F11B3}", "AUR", "yuzu-git", "emulator switch"],
        ["game-citra", "gaming", "Citra", "\u{F11B3}", "AUR", "citra", "emulator 3ds"],
        ["game-duckstation", "gaming", "DuckStation", "\u{F11B3}", "AUR", "duckstation", "emulator ps1"],
        ["game-melonds", "gaming", "melonDS", "\u{F11B3}", "AUR", "melonds", "emulator ds"],
        ["game-steamcmd", "gaming", "SteamCMD", "\u{F11B3}", "AUR", "steamcmd", "steam tools"],
        ["game-itchio", "gaming", "itch.io", "\u{F11B3}", "AUR", "itchio", "games launcher"],
        ["game-godot", "gaming", "Godot", "\u{F11B3}", "Arch", "godot", "game engine"],
        ["game-unityhub", "gaming", "Unity Hub", "\u{F11B3}", "AUR", "unityhub", "game engine"],
        ["game-blender", "gaming", "Blender", "\u{F11B3}", "Arch", "blender", "game art"],

        // Browser
        ["web-firefox-dev", "browser", "Firefox Developer", "\u{F0834}", "AUR", "firefox-developer-edition", "browser"],
        ["web-firefox-esr", "browser", "Firefox ESR", "\u{F0834}", "AUR", "firefox-esr", "browser"],
        ["web-librewolf", "browser", "LibreWolf", "\u{F0834}", "AUR", "librewolf-bin", "browser privacy"],
        ["web-waterfox", "browser", "Waterfox", "\u{F0834}", "AUR", "waterfox-bin", "browser"],
        ["web-palladian", "browser", "Palladian", "\u{F0834}", "AUR", "palladian-bin", "browser"],
        ["web-seamonkey", "browser", "SeaMonkey", "\u{F0834}", "AUR", "seamonkey", "browser"],
        ["web-vivaldi", "browser", "Vivaldi", "\u{F0834}", "AUR", "vivaldi", "browser"],
        ["web-opera", "browser", "Opera", "\u{F0834}", "AUR", "opera", "browser"],
        ["web-opera-dev", "browser", "Opera Developer", "\u{F0834}", "AUR", "opera-developer", "browser"],
        ["web-qutebrowser", "browser", "qutebrowser", "\u{F0834}", "Arch", "qutebrowser", "browser keyboard"],
        ["web-luakit", "browser", "Luakit", "\u{F0834}", "AUR", "luakit", "browser keyboard"],
        ["web-uzbl", "browser", "Uzbl", "\u{F0834}", "AUR", "uzbl-browser", "browser keyboard"],
        ["web-surf", "browser", "Surf", "\u{F0834}", "AUR", "surf", "browser minimal"],
        ["web-otter", "browser", "Otter", "\u{F0834}", "AUR", "otter-browser", "browser"],
        ["web-falkon", "browser", "Falkon", "\u{F0834}", "Arch", "falkon", "browser kde"],
        ["web-midori", "browser", "Midori", "\u{F0834}", "AUR", "midori", "browser"],
        ["web-epiphany", "browser", "Epiphany", "\u{F0834}", "Arch", "epiphany", "browser gnome"],
        ["web-tungsten", "browser", "Tungsten", "\u{F0834}", "AUR", "tungsten", "browser"],
        ["web-yandex", "browser", "Yandex Browser", "\u{F0834}", "AUR", "yandex-browser-stable", "browser"],
        ["web-naver", "browser", "NAVER Whale", "\u{F0834}", "AUR", "naver-whale-stable", "browser"],
        ["web-slimjet", "browser", "SlimJet", "\u{F0834}", "AUR", "slimjet", "browser"],
        ["web-iridium", "browser", "Iridium", "\u{F0834}", "AUR", "iridium", "browser privacy"],
        ["web-bromite", "browser", "Bromite", "\u{F0834}", "AUR", "bromite", "browser"],

        // Terminal
        ["term-xterm", "terminal", "xterm", "\u{F489}", "Arch", "xterm", "terminal emulator"],
        ["term-urxvt", "terminal", "rxvt-unicode", "\u{F489}", "Arch", "rxvt-unicode", "terminal emulator"],
        ["term-terminator", "terminal", "Terminator", "\u{F489}", "Arch", "terminator", "terminal emulator"],
        ["term-tilix", "terminal", "Tilix", "\u{F489}", "Arch", "tilix", "terminal emulator"],
        ["term-xfce", "terminal", "Xfce Terminal", "\u{F489}", "Arch", "xfce4-terminal", "terminal emulator"],
        ["term-gnome", "terminal", "GNOME Terminal", "\u{F489}", "Arch", "gnome-terminal", "terminal emulator"],
        ["term-konsole", "terminal", "Konsole", "\u{F489}", "Arch", "konsole", "terminal emulator kde"],
        ["term-lx", "terminal", "LX Terminal", "\u{F489}", "Arch", "lxterminal", "terminal emulator"],
        ["term-mate", "terminal", "MATE Terminal", "\u{F489}", "Arch", "mate-terminal", "terminal emulator"],
        ["term-qterminal", "terminal", "QTerminal", "\u{F489}", "Arch", "qterminal", "terminal emulator"],
        ["term-sakura", "terminal", "Sakura", "\u{F489}", "Arch", "sakura", "terminal emulator"],
        ["term-st", "terminal", "st", "\u{F489}", "AUR", "st", "terminal emulator suckless"],
        ["term-tmux", "terminal", "tmux", "\u{F489}", "Arch", "tmux", "terminal multiplexer"],
        ["term-screen", "terminal", "GNU Screen", "\u{F489}", "Arch", "screen", "terminal multiplexer"],
        ["term-zellij", "terminal", "Zellij", "\u{F489}", "Arch", "zellij", "terminal multiplexer"],
        ["term-byobu", "terminal", "Byobu", "\u{F489}", "Arch", "byobu", "terminal multiplexer"],
        ["term-fish", "terminal", "Fish", "\u{F489}", "Arch", "fish", "shell"],
        ["term-zsh", "terminal", "Zsh", "\u{F489}", "Arch", "zsh", "shell"],
        ["term-nushell", "terminal", "Nushell", "\u{F489}", "Arch", "nushell", "shell"],
        ["term-xonsh", "terminal", "Xonsh", "\u{F489}", "AUR", "xonsh", "shell"],
        ["term-starship", "terminal", "Starship", "\u{F489}", "Arch", "starship", "prompt"],
        ["term-oh-my-zsh", "terminal", "Oh My Zsh", "\u{F489}", "AUR", "oh-my-zsh-git", "shell prompt"],
        ["term-powerlevel10k", "terminal", "Powerlevel10k", "\u{F489}", "AUR", "powerlevel10k", "shell prompt"],
        ["term-direnv", "terminal", "direnv", "\u{F489}", "Arch", "direnv", "shell environment"],
        ["term-ranger", "terminal", "Ranger", "\u{F489}", "Arch", "ranger", "terminal file manager"],

        // Uncategorised
        ["other-gimp", "other", "GIMP", "\u{F03A}", "Arch", "gimp", "image editor"],
        ["other-inkscape", "other", "Inkscape", "\u{F03A}", "Arch", "inkscape", "vector graphics"],
        ["other-krita", "other", "Krita", "\u{F03A}", "Arch", "krita", "digital painting"],
        ["other-darktable", "other", "darktable", "\u{F03A}", "Arch", "darktable", "photo editing"],
        ["other-shotcut", "other", "Shotcut", "\u{F03A}", "Arch", "shotcut", "video editor"],
        ["other-kdenlive", "other", "Kdenlive", "\u{F03A}", "Arch", "kdenlive", "video editor"],
        ["other-obs", "other", "OBS Studio", "\u{F03A}", "Arch", "obs-studio", "screen recording"],
        ["other-audacity", "other", "Audacity", "\u{F03A}", "Arch", "audacity", "audio editor"],
        ["other-libreoffice", "other", "LibreOffice", "\u{F03A}", "Arch", "libreoffice", "office suite"],
        ["other-onlyoffice", "other", "OnlyOffice", "\u{F03A}", "AUR", "onlyoffice-bin", "office suite"],
        ["other-thunderbird", "other", "Thunderbird", "\u{F03A}", "Arch", "thunderbird", "email"],
        ["other-calibre", "other", "Calibre", "\u{F03A}", "Arch", "calibre", "ebooks"],
        ["other-okular", "other", "Okular", "\u{F03A}", "Arch", "okular", "pdf reader"],
        ["other-evince", "other", "Evince", "\u{F03A}", "Arch", "evince", "pdf reader"],
        ["other-filezilla", "other", "FileZilla", "\u{F03A}", "Arch", "filezilla", "file transfer"],
        ["other-transmission", "other", "Transmission", "\u{F03A}", "Arch", "transmission-gtk", "torrent"],
        ["other-qbittorrent", "other", "qBittorrent", "\u{F03A}", "Arch", "qbittorrent", "torrent"],
        ["other-keepassxc", "other", "KeePassXC", "\u{F03A}", "Arch", "keepassxc", "password manager"],
        ["other-veracrypt", "other", "VeraCrypt", "\u{F03A}", "AUR", "veracrypt", "encryption"],
        ["other-cryptomator", "other", "Cryptomator", "\u{F03A}", "AUR", "cryptomator", "encryption"],
        ["other-typora", "other", "Typora", "\u{F03A}", "AUR", "typora", "markdown writing"],
        ["other-zettlr", "other", "Zettlr", "\u{F03A}", "AUR", "zettlr", "markdown writing"],
        ["other-obsidian", "other", "Obsidian", "\u{F03A}", "AUR", "obsidian", "notes"],
        ["other-joplin", "other", "Joplin", "\u{F03A}", "AUR", "joplin", "notes"],
        ["other-standardnotes", "other", "Standard Notes", "\u{F03A}", "AUR", "standardnotes", "notes"],
        ["other-google-earth", "other", "Google Earth", "\u{F03A}", "AUR", "google-earth-pro", "maps"],
        ["other-stellarium", "other", "Stellarium", "\u{F03A}", "Arch", "stellarium", "astronomy"],
        ["other-marble", "other", "Marble", "\u{F03A}", "Arch", "marble", "maps"],
        ["other-gcompris", "other", "GCompris", "\u{F03A}", "Arch", "gcompris", "education"],
        ["other-tuxpaint", "other", "Tux Paint", "\u{F03A}", "Arch", "tuxpaint", "drawing"]
    ];
    for (var i = 0; i < rows.length; i++) options.push(packageChoice(rows[i]));
})();

function categoryLabel(key) {
    const c = categories.find(x => x.key === key);
    return c ? c.label : "";
}

function related(o) {
    return options.filter(x => x.category === o.category && x.id !== o.id)
        .slice(0, 2).map(x => x.label);
}

function matches(o, q) {
    if (q === "") return true;
    return (o.label + " " + o.words + " " + o.source + " " + categoryLabel(o.category)).toLowerCase().indexOf(q) >= 0;
}

// The other half of the contract: how to take a choice back off. Packages go
// through the same Store path as installs (Arch through the approval gate),
// agents through their own tool, web apps by name, and the one setup step that
// leaves something behind removes the thing it made. Launchers and sign-in
// pages have nothing to remove, so they return an empty command.
function packageCommand(action, source, name) {
    if (!/^[A-Za-z0-9@._+-]{1,128}$/.test(String(name || ""))) return [];
    return ["qs", "ipc", "call", "store", action, source, name];
}

function uninstall(o) {
    const c = (o && o.cmd) || [];
    if (c[0] === "qs" && c[4] === "package")
        return packageCommand("remove", c[5], c[6]);
    if (c[0] === "aequalyn-ai-tool" && c[1] === "install")
        return ["aequalyn-ai-tool", "remove", c[2]];
    if (c[0] === "aequalyn-webapp" && c[1] === "add") {
        const i = c.indexOf("--name");
        return i >= 0 && i + 1 < c.length ? ["aequalyn-webapp", "remove", "--name", c[i + 1]] : [];
    }
    if (o && o.id === "dev-docker-db")
        return ["sh", "-c", "docker rm -f aequalyn-postgres || true"];
    return [];
}

// ---- installation state ---------------------------------------------------
// The panel only needs to know which choices are here already. The sweep in
// InstallMenu.qml prints one marked section per source; the two JSON sections
// stay JSON so the agent and web app details survive intact.

function blankState() {
    return { pacman: [], flatpak: [], snap: [], agents: [], webapps: [], containers: [], ready: false };
}

function stateFromText(text) {
    const sections = { pacman: [], flatpak: [], snap: [], agents: [], webapps: [], containers: [] };
    let part = "";
    for (const line of String(text || "").split("\n")) {
        if (line.charAt(0) === "#") { part = line.slice(1); continue; }
        const value = line.trim();
        if (part === "" || value === "" || !sections[part]) continue;
        sections[part].push(value);
    }
    let agents = [];
    try {
        const parsed = JSON.parse(sections.agents.join("\n"));
        if (Array.isArray(parsed)) agents = parsed;
    } catch (e) { /* no agent CLI: every agent is simply not installed */ }
    let webapps = [];
    try {
        const parsed = JSON.parse(sections.webapps.join("\n"));
        if (parsed && Array.isArray(parsed.apps))
            webapps = parsed.apps.map(a => a.name || "");
    } catch (e) { /* no web app CLI: no web apps are installed */ }
    return {
        pacman: sections.pacman, flatpak: sections.flatpak, snap: sections.snap,
        agents: agents, webapps: webapps, containers: sections.containers, ready: true
    };
}

function normKey(v) { return String(v || "").toLowerCase().trim(); }

function has(list, value) {
    const v = String(value || "");
    return v !== "" && (list || []).some(x => String(x) === v);
}

function hasName(list, value) {
    const v = normKey(value);
    return v !== "" && (list || []).some(x => normKey(x) === v);
}

function agentId(o) {
    const c = (o && o.cmd) || [];
    return c[0] === "aequalyn-ai-tool" && c[1] === "install" ? c[2] || "" : "";
}

function agentRecord(o, state) {
    const id = agentId(o);
    return id ? (state && state.agents || []).find(a => a && a.id === id) : null;
}

function webappName(o) {
    const c = (o && o.cmd) || [];
    const i = c.indexOf("--name");
    return c[0] === "aequalyn-webapp" && c[1] === "add" && i >= 0 && i + 1 < c.length ? c[i + 1] : "";
}

// Which path actually put this choice here: the primary one, a Flatpak/Snap
// edition of the same app, an installed agent, a web app, or the setup container.
function installedVia(o, state) {
    if (!o || !state) return "";
    const c = o.cmd || [];
    if (c[0] === "qs" && c[4] === "package") {
        const source = String(c[5] || "").toLowerCase();
        const name = c[6] || "";
        if ((source === "arch" || source === "aur") && has(state.pacman, name)) return source;
        if (source === "flatpak" && has(state.flatpak, name)) return "flatpak";
        if (source === "snap" && has(state.snap, name)) return "snap";
        const alt = PackageIds.forOption(o);
        if (alt.flatpak && has(state.flatpak, alt.flatpak)) return "flatpak";
        if (alt.snap && has(state.snap, alt.snap)) return "snap";
        // A same-named Arch package counts too: the app is here whichever
        // store it came from, even when this choice names another store.
        if (has(state.pacman, name)) return "arch";
        return "";
    }
    if (c[0] === "aequalyn-ai-tool" && c[1] === "install") {
        const a = agentRecord(o, state);
        if (!a) return "";
        if (a.installed) return "agent";
        if (a.availableElsewhere) return "system:" + String(a.systemManager || "agent").toLowerCase();
        return "";
    }
    if (webappName(o) !== "" && hasName(state.webapps, webappName(o))) return "webapp";
    if (o.id === "dev-docker-db" && has(state.containers, "aequalyn-postgres")) return "container";
    return "";
}

function isInstalled(o, state) { return installedVia(o, state) !== ""; }

// Removal follows the backend that is really installed. A Flatpak/Snap edition
// of a curated Arch app removes by that store's id; an agent installed by the
// system package manager removes through the Store, not the agent tool.
function removal(o, state) {
    if (!o || !isInstalled(o, state)) return [];
    const via = installedVia(o, state);
    const c = o.cmd || [];
    if (c[0] === "qs" && c[4] === "package") {
        if (via === "flatpak" || via === "snap") {
            const alt = PackageIds.forOption(o);
            const id = c[5] === via ? c[6]
                : via === "flatpak" ? alt.flatpak : alt.snap;
            return id ? packageCommand("remove", via, id) : [];
        }
        if (via === "arch" && c[5] !== "arch" && c[5] !== "aur")
            return packageCommand("remove", "arch", c[6]);
        return uninstall(o);
    }
    if (c[0] === "aequalyn-ai-tool" && via.indexOf("system:") === 0) {
        const a = agentRecord(o, state) || {};
        const manager = String(a.systemManager || "").toLowerCase();
        const source = manager === "aur" ? "aur" : manager === "flatpak" ? "flatpak"
            : manager === "snap" ? "snap" : "arch";
        const id = a.systemId || a.systemPrefix || a.command || a.package || "";
        return packageCommand("remove", source, id);
    }
    return uninstall(o);
}
