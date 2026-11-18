#!/usr/bin/env python3
"""cc-index: the control center's search index, read from its pages.

Every titled control on a page (a switch, an amount, a choice, a group of settings, a
row) becomes a line the search finds: its words, its page and sub page, and, when it
is bound to a setting (`setting: "key"`), what it needs to be changed right in the
search results.

    python3 tools/cc-index.py          writes settings/center/SettingsIndex.js
    python3 tools/cc-index.py --check  fails when the index is out of date

Run it after changing a page; the control center reads the file as it is.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGES = os.path.join(ROOT, "settings", "center", "pages")
OUT = os.path.join(ROOT, "settings", "center", "SettingsIndex.js")
PAGES_JS = os.path.join(ROOT, "settings", "center", "Pages.js")

KINDS = {"CcToggle": "toggle", "CcSlider": "slider", "CcChoice": "choice", "CcSection": "group",
         "CcRow": "row", "CcMore": "more", "CcField": "field", "CcButton": "button"}
OPEN = re.compile(r"\b(Cc(?:Toggle|Slider|Choice|Section|Row|More|Field|Button))\s*\{")
STR = r'"((?:[^"\\]|\\.)*)"'


def block_end(src, i):
    """the index just past the brace that closes the block opening at src[i] == '{'"""
    depth, j, n = 0, i, len(src)
    in_str = None
    while j < n:
        c = src[j]
        if in_str:
            if c == "\\":
                j += 2
                continue
            if c == in_str:
                in_str = None
        elif c in "\"'`":
            in_str = c
        elif c == "/" and src[j:j + 2] == "//":
            j = src.find("\n", j)
            if j < 0:
                return n
            continue
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return j + 1
        j += 1
    return n


def own_text(body):
    """a block's own lines: its nested blocks taken out, so their properties don't count"""
    out, j, n = [], 0, len(body)
    while j < n:
        k = body.find("{", j)
        if k < 0:
            out.append(body[j:])
            break
        out.append(body[j:k])
        j = block_end(body, k)
    return "".join(out)


def prop(text, name):
    m = re.search(r"(?:^|[\s;{])" + name + r"\s*:\s*" + STR, text)
    return json.loads('"' + m.group(1) + '"') if m else None


def num(text, name):
    m = re.search(r"(?:^|[\s;{])" + name + r"\s*:\s*(-?\d+(?:\.\d+)?)\b", text)
    return float(m.group(1)) if m else None


def options_of(block):
    """a literal options list: ["a", "b"] or [{ key: "a", label: "A" }, ...]"""
    m = re.search(r"\boptions\s*:\s*\[", block)
    if not m:
        return None
    i = m.end() - 1
    depth, j = 0, i
    while j < len(block):
        if block[j] == "[":
            depth += 1
        elif block[j] == "]":
            depth -= 1
            if depth == 0:
                break
        j += 1
    lit = block[i:j + 1]
    bare = re.sub(STR, '""', lit)
    # only a list written out in full: nothing computed
    if re.search(r"[A-Za-z_]", re.sub(r"\b(key|label)\s*:", "", bare)):
        return None
    pairs = re.findall(r'\{\s*key\s*:\s*' + STR + r'\s*,\s*label\s*:\s*' + STR + r'\s*\}', lit)
    if pairs and len(pairs) == lit.count("{"):
        return [{"key": json.loads('"' + k + '"'), "label": json.loads('"' + l + '"')} for k, l in pairs]
    if "{" not in lit:
        plain = re.findall(STR, lit)
        if plain:
            return [{"key": json.loads('"' + v + '"'), "label": json.loads('"' + v + '"')} for v in plain]
    return None


def page_files():
    """page id -> file, from Pages.js"""
    src = open(PAGES_JS).read()
    return {m.group(1): m.group(2) for m in re.finditer(r'(\w+)\s*:\s*\{\s*label\s*:\s*"[^"]*"\s*,\s*icon\s*:\s*"[^"]*"\s*,\s*file\s*:\s*"(\w+)"', src)}


def scan(page, path):
    src = open(path).read()
    entries, seen = [], set()
    for m in OPEN.finditer(src):
        typ = m.group(1)
        start = src.index("{", m.start())
        end = block_end(src, start)
        block = src[start + 1:end - 1]
        own = own_text(block)
        title = prop(own, "title")
        if typ == "CcButton":
            title = prop(own, "text")
        if not title:
            continue
        # the sub page it is on (the nearest `visible: page.tab === N` on or around it),
        # and the group it is in (the titled section or fold around it)
        tab, group = None, None
        t = re.search(r"visible\s*:\s*page\.tab\s*===\s*(\d+)", own)
        if t:
            tab = int(t.group(1))
        depth, k = 0, start - 1
        while k >= 0 and (tab is None or group is None):
            c = src[k]
            if c == "}":
                depth += 1
            elif c == "{":
                if depth == 0:
                    b_end = block_end(src, k)
                    o = own_text(src[k + 1:b_end - 1])
                    if tab is None:
                        t = re.search(r"visible\s*:\s*page\.tab\s*===\s*(\d+)", o)
                        if t:
                            tab = int(t.group(1))
                    if group is None:
                        kind = re.search(r"(\w+)\s*$", src[:k])
                        if kind and kind.group(1) in ("CcSection", "CcMore"):
                            group = prop(o, "title")
                else:
                    depth -= 1
            k -= 1
        e = {"page": page, "title": title, "kind": KINDS[typ]}
        sub = prop(own, "sub") or prop(own, "hint")
        if sub:
            e["sub"] = sub
        if tab:
            e["tab"] = tab
        if group and group != title:
            e["group"] = group
        setting = prop(own, "setting")
        if typ == "CcSection":
            # a group holding one choice bound to a setting: change it from the search too
            inner = list(OPEN.finditer(block))
            choices = [x for x in inner if x.group(1) == "CcChoice"]
            if len(choices) == 1:
                cs = block.index("{", choices[0].start())
                cb = block[cs + 1:block_end(block, cs) - 1]
                cset = prop(own_text(cb), "setting")
                opts = options_of(cb)
                if cset and opts:
                    e.update(kind="choice", setting=cset, options=opts)
        elif setting:
            e["setting"] = setting
            if typ == "CcSlider":
                for k in ("from", "to", "step"):
                    v = num(own, k)
                    if v is not None:
                        e[k] = v
                unit = prop(own, "unit")
                if unit:
                    e["unit"] = unit
            if typ == "CcChoice":
                opts = options_of(block)
                if opts:
                    e["options"] = opts
                else:
                    del e["setting"]
        key = (title.lower(), e.get("group"), e.get("tab"), e.get("setting"))
        if key in seen:
            continue
        seen.add(key)
        entries.append(e)
    return entries


def build():
    files = page_files()
    out = []
    for page, f in files.items():
        p = os.path.join(PAGES, f + ".qml")
        if os.path.exists(p):
            out += scan(page, p)
    return out


def render(entries):
    lines = ["// Generated by tools/cc-index.py from the pages: every titled control, for the",
             "// control center's search. Don't edit by hand: change the page, then run it again.",
             ".pragma library", "", "var entries = ["]
    lines += ["    " + json.dumps(e, ensure_ascii=False) + "," for e in entries]
    lines.append("];")
    return "\n".join(lines) + "\n"


def main():
    text = render(build())
    if "--check" in sys.argv:
        cur = open(OUT).read() if os.path.exists(OUT) else ""
        if cur != text:
            sys.exit("SettingsIndex.js is out of date: run tools/cc-index.py")
        print("SettingsIndex.js is up to date")
        return
    with open(OUT, "w") as fh:
        fh.write(text)
    print("%d settings indexed" % text.count("\n    {"))


if __name__ == "__main__":
    main()
