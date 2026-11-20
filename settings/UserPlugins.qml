pragma Singleton
// Plugins installed by the Store, beside the built-in ones (Plugins.js): every folder in
// ~/.local/share/aequalyn/plugins with a plugin.json. Read at start and on
// `qs ipc call plugins rescan` (the Store calls it after every install, update and
// remove). Each entry has the built-ins' shape, { id, label, source }, plus `info`: what
// PluginInfo.js says about a built-in (icon, group, keys, about), from the manifest.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string dir: Quickshell.env("HOME") + "/.local/share/aequalyn/plugins"
    property var list: []
    function byId(id) { return root.list.find(p => p.id === id) || null; }
    function rescan() { if (!scan.running) scan.running = true; }

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
        out.append({'id': i, 'label': str(d.get('label', i)), 'source': (m.parent / e).as_uri(),
                    'version': str(d.get('version', '')),
                    'info': {'icon': str(d.get('icon', '')), 'group': g, 'keys': str(d.get('keys', '')),
                             'page': '', 'about': str(d.get('about', '')), 'user': True}})
    except Exception:
        pass
print(json.dumps(out))
`, root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(text);
                    // a new array only when something changed: the loaders of the plugins
                    // already running stay as they are
                    if (JSON.stringify(next) !== JSON.stringify(root.list)) root.list = next;
                } catch (e) {}
            }
        }
    }
}
