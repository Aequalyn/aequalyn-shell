.pragma library

// The notification log's pure data model: no Qt, so node can test it the same
// way Clipscape's clips are tested. Entries are kept until the person clears
// them; nothing expires by age or count.
//
// One entry:
//   id          stable local id (used by the UI to copy/delete an entry)
//   notifId     the originating desktop notification id, if any
//   summary     the title
//   body        the message text
//   appName     who sent it
//   appIcon     icon name/path, when the sender supplied one
//   image       notification image, when supplied
//   urgency     0 low, 1 normal, 2 critical (as QML gives it)
//   at          epoch ms when it arrived
//   suppressed  true when it arrived during Do Not Disturb
//   text        plain text to copy ("Title\nBody")

var VERSION = 1;

function normalize(raw) {
    var out = [];
    var list = Array.isArray(raw) ? raw : (raw && Array.isArray(raw.entries) ? raw.entries : []);
    for (var i = 0; i < list.length; i++) {
        var e = list[i];
        if (!e || typeof e !== "object") continue;
        var summary = String(e.summary || "");
        var body = String(e.body || "");
        if (!summary && !body) continue;
        out.push({
            id: String(e.id || ""),
            notifId: String(e.notifId || ""),
            summary: summary,
            body: body,
            appName: String(e.appName || ""),
            appIcon: String(e.appIcon || ""),
            image: String(e.image || ""),
            urgency: Number(e.urgency) || 0,
            at: Number(e.at) || Date.now(),
            suppressed: e.suppressed === true,
            text: String(e.text || (summary + (body ? "\n" + body : "")))
        });
    }
    return out;
}

function parseStore(raw) {
    var d = null;
    try { d = JSON.parse(String(raw || "")); } catch (e) { return []; }
    return normalize(d);
}

function serialize(list) {
    return JSON.stringify({ version: VERSION, entries: list || [] }) + "\n";
}

function makeId(at, seq) {
    return String(at) + "-" + String(seq);
}

function entry(notification, seq, suppressed) {
    var n = notification || {};
    var summary = String(n.summary || "");
    var body = String(n.body || "");
    var at = Date.now();
    return {
        id: makeId(at, seq),
        notifId: String(n.id || ""),
        summary: summary,
        body: body,
        appName: String(n.appName || ""),
        appIcon: String(n.appIcon || ""),
        image: String(n.image || ""),
        urgency: Number(n.urgency) || 0,
        at: at,
        suppressed: suppressed === true,
        text: summary + (body ? "\n" + body : "")
    };
}

function add(list, e) {
    var next = [e];
    var old = Array.isArray(list) ? list : [];
    for (var i = 0; i < old.length; i++) if (old[i] && old[i].id !== e.id) next.push(old[i]);
    return next;
}

function remove(list, id) {
    return (Array.isArray(list) ? list : []).filter(function(e) { return !e || e.id !== id; });
}

function find(list, id) {
    var all = Array.isArray(list) ? list : [];
    for (var i = 0; i < all.length; i++) if (all[i] && all[i].id === id) return all[i];
    return null;
}

function search(list, query) {
    var q = String(query || "").trim().toLowerCase();
    var all = Array.isArray(list) ? list : [];
    if (!q) return all;
    return all.filter(function(e) {
        return String(e.summary || "").toLowerCase().indexOf(q) >= 0
            || String(e.body || "").toLowerCase().indexOf(q) >= 0
            || String(e.appName || "").toLowerCase().indexOf(q) >= 0;
    });
}

function timeLabel(ms) {
    var t = Number(ms) || 0;
    if (!t) return "";
    var d = new Date(t);
    var now = new Date();
    var sameDay = d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth()
                  && d.getDate() === now.getDate();
    var hh = ("0" + d.getHours()).slice(-2), mm = ("0" + d.getMinutes()).slice(-2);
    return (sameDay ? "" : (d.getMonth() + 1) + "/" + d.getDate() + " ") + hh + ":" + mm;
}
