#!/usr/bin/env python3
"""Build AppMeta.js from the same package managers the Store installs from."""
import concurrent.futures
import html
import json
import os
import re
import subprocess
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
SHELL = os.path.dirname(HERE)
ROOT = os.path.dirname(SHELL)
CLI = os.path.join(ROOT, "aequalyn", "bin", "aequalyn-store")


def run(cmd, timeout=60, cwd=None):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                          text=True, timeout=timeout, check=True, cwd=cwd).stdout


def clean(text, limit=160):
    text = html.unescape(str(text or ""))
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    text = re.sub(r"\s+([,.;:])", r"\1", text)
    if len(text) > limit:
        cut = text[:limit]
        stop = max(cut.rfind("."), cut.rfind(";"), cut.rfind(","))
        text = cut[:stop + 1] if stop > 60 else cut.rstrip() + "…"
    return text


def options():
    script = (
        "const l=require('./tests/jsload.js');"
        "const O=l('./plugins/installMenu/InstallOptions.js');"
        "console.log(JSON.stringify(O.options.filter(o=>o.cmd&&o.cmd[0]==='qs'&&o.cmd[4]==='package')"
        ".map(o=>({id:o.id,label:o.label,source:o.source,name:o.cmd[6],words:o.words}))));"
    )
    return json.loads(run(["node", "-e", script], cwd=SHELL))


def key(value):
    return re.sub(r"[^a-z0-9]+", "", str(value or "").lower())


def package_ids():
    script = (
        "const l=require('./tests/jsload.js');"
        "const O=l('./plugins/installMenu/InstallOptions.js');"
        "const P=l('./plugins/store/PackageIds.js');"
        "console.log(JSON.stringify(Object.fromEntries(O.options"
        ".filter(o=>o.cmd&&o.cmd[0]==='qs'&&o.cmd[4]==='package')"
        ".map(o=>[o.id,P.forOption(o)]))));"
    )
    return json.loads(run(["node", "-e", script], cwd=SHELL))


def info(opt):
    via = {"Arch": "arch", "AUR": "aur", "Flatpak": "flatpak", "Snap": "snap"}[opt["source"]]
    try:
        data = json.loads(run([CLI, "app-info", opt["label"], "--" + via, opt["name"]], 90))
    except Exception:
        return opt["id"], "", ""
    app = (data.get("apps") or [{}])[0]
    checked = {key(opt["name"])}
    sources = app.get("sources") or []
    chosen = next((s for s in sources if key(s.get("id")) in checked), sources[0] if sources else {})
    about = clean(chosen.get("about") or app.get("about") or "")
    if not about or len(about) < 12:
        full = clean(chosen.get("description") or app.get("description") or "", 260)
        first = clean(full.split(".")[0] + ".", 160) if full else ""
        about = first if len(first) >= 12 else full[:160]
    return opt["id"], about, next((s.get("icon") or "" for s in sources if s.get("icon")), "")


def simple_icons():
    """Checked filenames from Simple Icons, keyed by title and known alias."""
    try:
        req = urllib.request.Request("https://cdn.jsdelivr.net/npm/simple-icons@latest/_data/simple-icons.json")
        data = json.load(urllib.request.urlopen(req, timeout=30))
        version = json.load(urllib.request.urlopen(
            "https://registry.npmjs.org/simple-icons/latest", timeout=30))["version"]
        req = urllib.request.Request("https://data.jsdelivr.com/v1/package/npm/simple-icons@%s/flat" % version)
        files = json.load(urllib.request.urlopen(req, timeout=30)).get("files", [])
        names = {f["name"].split("/")[-1][:-4] for f in files
                 if f["name"].startswith("/icons/") and f["name"].endswith(".svg")}
    except Exception:
        return {}
    def slug(value):
        return re.sub(r"[^a-z0-9]+", "", str(value or "").lower().replace(".", "dot")
                      .replace("&", "and").replace("+", "plus"))
    out = {}
    for item in data:
        aliases = (item.get("aliases") or {}).get("aka", [])
        for value in [item.get("title")] + list(aliases):
            name = slug(value)
            if name in names:
                out.setdefault(key(value), "https://cdn.simpleicons.org/" + name)
    return out


SIMPLE = simple_icons()


def icon(opt, ids, remote):
    candidates = []
    if remote:
        candidates += remote
    checked = {key(opt["name"]), key(opt["label"])}
    for source, field in (("Flatpak", "flatpak"), ("Snap", "snap")):
        ident = ids.get(opt["id"], {}).get(field)
        if ident:
            checked.add(key(ident))
    want = {"Flatpak": 0, "Snap": 1, "Arch": 2, "AUR": 3}
    hits = [r for r in candidates if r.get("icon") and
            (key(r.get("id")) in checked or key(r.get("name")) in checked)]
    hits.sort(key=lambda r: want.get(r.get("source"), 9))
    if hits:
        return hits[0]["icon"]
    if key(opt["label"]) in SIMPLE:
        return SIMPLE[key(opt["label"])]
    try:
        script = (
            "const l=require('./tests/jsload.js');"
            "const I=l('./plugins/store/AppIcons.js');"
            "const u=I.url(I.slugForOption(%s),%s);"
            "console.log(u.indexOf('data:')===0?'':u);" % (json.dumps(opt["label"]), json.dumps(opt["label"]))
        )
        return run(["node", "-e", script], cwd=SHELL).strip()
    except Exception:
        return ""


def search(opt):
    try:
        data = json.loads(run([CLI, "search-apps", opt["label"]], 60))
        return opt["id"], data.get("results") or []
    except Exception:
        return opt["id"], []


AI_IDS = {
    "claude": {"aur": "", "flatpak": "", "snap": "claude-code"},
    "codex": {"aur": "openai-codex-bin", "flatpak": "", "snap": ""},
    "copilot": {"aur": "github-copilot-cli-bin", "flatpak": "", "snap": "copilot-cli"},
    "antigravity": {"aur": "", "flatpak": "", "snap": "antigravity-cli"},
    "opencode": {"arch": "opencode", "aur": "opencode-bin", "flatpak": "ai.opencode.opencode", "snap": "opencode"},
    "qwen": {"aur": "", "flatpak": "", "snap": ""},
    "kilo": {"aur": "", "flatpak": "", "snap": ""},
    "cline": {"aur": "", "flatpak": "", "snap": "cline"},
    "crush": {"aur": "crush-bin", "flatpak": "", "snap": ""},
    "amp": {"aur": "ampcode", "flatpak": "", "snap": ""},
}
AI_ICON_SLUG = {
    "claude": "claude-ai", "codex": "codex", "copilot": "github-copilot",
    "antigravity": "", "opencode": "opencode", "qwen": "qwen",
    "kilo": "", "cline": "", "crush": "", "amp": "amp",
}


def main():
    opts = options()
    ids = package_ids()
    out_path = os.path.join(SHELL, "plugins", "store", "AppMeta.js")
    old_about, old_icons = {}, {}
    if os.path.exists(out_path):
        try:
            script = ("const l=require('./tests/jsload.js');const M=l('./plugins/store/AppMeta.js');"
                      "console.log(JSON.stringify({about:M.about,icon:M.icon}));")
            old = json.loads(run(["node", "-e", script], cwd=SHELL))
            old_about, old_icons = old.get("about", {}), old.get("icon", {})
        except Exception:
            pass
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
        infos = {ident: (desc, remote) for ident, desc, remote in ex.map(info, opts)}
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
        searches = dict(ex.map(search, opts))
    about = dict(old_about)
    icons = dict(old_icons)
    for opt in opts:
        desc, _ = infos[opt["id"]]
        if desc and desc != opt["label"]:
            about[opt["id"]] = desc
        found = icon(opt, ids, searches[opt["id"]])
        if found:
            icons[opt["id"]] = found
        current = about.get(opt["id"], "")
        words = clean(opt.get("words") or "")
        generic = (not current or current == opt["label"] or len(current) < 12
                   or current.lower() == words.lower())
        if generic:
            checked = {key(opt["name"]), key(opt["label"])}
            for source, field in (("Flatpak", "flatpak"), ("Snap", "snap")):
                ident = ids.get(opt["id"], {}).get(field)
                if ident:
                    checked.add(key(ident))
            summary = next((clean(r.get("about") or "", 160) for r in searches[opt["id"]]
                            if (key(r.get("id")) in checked or key(r.get("name")) in checked)
                            and len(clean(r.get("about") or "")) >= 12), "")
            if summary:
                about[opt["id"]] = summary
            else:
                about[opt["id"]] = ((words.capitalize() + " — ") if words else "") + opt["label"]
    try:
        tools = json.loads(run(["aequalyn-ai-tool", "list", "--json"], 30))
    except Exception:
        tools = []
    ai = {}
    for tool in tools:
        ident = tool.get("id")
        if not ident:
            continue
        slug = AI_ICON_SLUG.get(ident, "")
        icon_url = ""
        if slug:
            try:
                script = ("const l=require('./tests/jsload.js');const I=l('./plugins/store/AppIcons.js');"
                          "const u=I.url(%s,'');console.log(u.indexOf('data:')===0?'':u);" % json.dumps(slug))
                icon_url = run(["node", "-e", script], cwd=SHELL).strip()
            except Exception:
                pass
        row = dict(AI_IDS.get(ident, {}))
        row.update({"about": clean(tool.get("description") or "", 140), "icon": icon_url})
        ai[ident] = row
    lines = [
        ".pragma library",
        "",
        "// Generated from the package managers the Store installs from. Descriptions",
        "// come from app-info on the checked package id; icons come from Flathub,",
        "// the Snap store, or the checked icon set. Regenerate with",
        "// tools/gen-app-meta.py; anything unchecked falls back to a local badge.",
        "var about = " + json.dumps(about, indent=2, ensure_ascii=False, sort_keys=True) + ";",
        "var icon = " + json.dumps(icons, indent=2, ensure_ascii=False, sort_keys=True) + ";",
        "var ai = " + json.dumps(ai, indent=2, ensure_ascii=False, sort_keys=True) + ";",
        "",
        "function aboutFor(id) { return about[id] || \"\"; }",
        "function iconFor(id) { return icon[id] || \"\"; }",
        "function aiFor(id) { return ai[id] || ({}); }",
        "",
    ]
    open(out_path, "w").write("\n".join(lines))
    print("wrote", out_path, "about", len(about), "icons", len(icons), "ai", len(ai), "of", len(opts))


if __name__ == "__main__":
    main()
