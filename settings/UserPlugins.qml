pragma Singleton
// Plugins installed by the Store, beside the built-in ones (Plugins.js): every folder in
// ~/.local/share/aequalyn/plugins with a plugin.json. Read at start and on
// `qs ipc call plugins rescan` (the Store calls it after every install, update and
// remove). Each entry has the built-ins' shape, { id, label, source }, plus `info`: what
// PluginInfo.js says about a built-in (icon, group, keys, about), from the manifest.
// A plugin whose id is a built-in's (Plugins.js) is refused: it could never run
// alongside the real one, and would only shadow it.
import QtQuick
import Quickshell
import Quickshell.Io
import "../Plugins.js" as PluginRegistry


Singleton {
    id: root
    readonly property string dir: Quickshell.env("HOME") + "/.local/share/aequalyn/plugins"
    property var list: []
    function byId(id) { return root.list.find(p => p.id === id) || null; }
    function rescan(): bool { if (!scan.running) scan.running = true; return true; }

    property Process scan: Process {
        running: true
        command: ["python3", "-c", `
import json, pathlib, re, sys
out = []
for m in sorted(pathlib.Path(sys.argv[1]).glob('*/plugin.json')):
    try:
        d = json.loads(m.read_text())
        i, e = d.get('id', ''), d.get('entry', '')
        if i != m.parent.name or not re.match(r'^[a-z][a-z0-9-]{1,39}$', i) or '/' in e or not (m.parent / e).is_file():
            continue
        g = d.get('group') if d.get('group') in ('screen', 'key', 'background') else 'background'
        # what the plugin wants root for, shown on its card and in the
        # escalation window; the command is pinned here, never passed in.
        # The supervisor validates it again before anything runs.
        nr = []
        raw = d.get('needsRoot')
        if isinstance(raw, list):
            for a in raw[:8]:
                if not isinstance(a, dict):
                    continue
                aid, cmd = str(a.get('id', '')), a.get('command', [])
                if not re.match(r'^[a-z][a-z0-9-]{0,39}$', aid):
                    continue
                if not isinstance(cmd, list) or not (1 <= len(cmd) <= 64):
                    continue
                argv = []
                for x in cmd:
                    s = str(x)
                    if not s or len(s) > 512 or '\\x00' in s or '\\n' in s:
                        argv = None
                        break
                    argv.append(s)
                if not argv or re.match(r'^(sudo|pkexec|su|doas)$', argv[0].rsplit('/', 1)[-1]):
                    continue
                if any(x['id'] == aid for x in nr):
                    continue
                nr.append({'id': aid, 'label': str(a.get('label', aid))[:128],
                           'command': argv, 'about': str(a.get('about', ''))[:512]})
        pv = next((str(p) for p in [m.parent / 'preview.png', m.parent / 'preview.jpg',
                                    m.parent / 'preview.webp', m.parent / 'preview.mp4',
                                    m.parent / 'preview.webm'] if p.is_file()), '')
        out.append({'id': i, 'label': str(d.get('label', i)), 'source': (m.parent / e).as_uri(),
                    'version': str(d.get('version', '')),
                    'info': {'icon': str(d.get('icon', '')), 'group': g, 'keys': str(d.get('keys', '')),
                             'page': '', 'about': str(d.get('about', '')), 'user': True,
                             'preview': str(d.get('preview') or d.get('image') or d.get('screenshot') or pv),
                             'needsRoot': nr}})
    except Exception:
        pass
print(json.dumps(out))
`, root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let next = JSON.parse(text);
                    // a built-in's id is taken: the Store plugin is refused outright
                    const builtin = PluginRegistry.list.map(p => p.id)
                    next = next.filter(p => builtin.indexOf(p.id) < 0)
                    // a new array only when something changed: the loaders of the plugins
                    // already running stay as they are
                    if (JSON.stringify(next) !== JSON.stringify(root.list)) root.list = next;
                } catch (e) {}
            }
        }
    }
}
