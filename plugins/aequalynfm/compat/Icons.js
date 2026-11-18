.pragma library

// Nerd Font (JetBrainsMono) glyphs for files and folders, so they follow the
// theme's accent colour instead of the fixed GTK icon-theme art.
var glyphs = ({
    "folder": "\u{F024B}",
    "folder-home": "\u{F02DC}",
    "folder-open": "\u{F024C}",
    "folder-remote": "\u{F0318}",
    "folder-shared": "\u{F0318}",
    "folder-public": "\u{F0318}",
    "folder-desktop": "\u{F01C4}",
    "folder-documents": "\u{F0219}",
    "folder-download": "\u{F01DA}",
    "folder-music": "\u{F075A}",
    "folder-pictures": "\u{F03E}",
    "folder-videos": "\u{F52C}",
    "folder-templates": "\u{F0219}",
    "home": "\u{F02DC}",
    "desktop": "\u{F01C4}",
    "recent": "\u{F02DA}",
    "trash": "\u{F0A79}",
    "trash-full": "\u{F0A79}",
    "drive": "\u{F02CA}",
    "drive-usb": "\u{F02CA}",
    "drive-optical": "\u{F02CA}",
    "computer": "\u{F01C4}",
    "network": "\u{F015F}",
    "cloud": "\u{F015F}",
    "phone": "\u{F01C4}",
    "connect": "\u{F0415}",
    "file": "\u{F0219}",
    "text": "\u{F0219}",
    "pdf": "\u{F0226}",
    "ebook": "\u{F00BA}",
    "document": "\u{F0219}",
    "spreadsheet": "\u{F021B}",
    "presentation": "\u{F0227}",
    "disk-image": "\u{F05EE}",
    "package": "\u{F03D3}",
    "script": "\u{F0BC2}",
    "image": "\u{F03E}",
    "video": "\u{F52C}",
    "audio": "\u{F0223}",
    "archive": "\u{F0A23}",
    "font": "\u{F0219}",
    "code": "\u{F0169}"
});

function glyph(slot) {
    if (glyphs[slot]) return glyphs[slot];
    if (slot && slot.indexOf("folder") === 0) return glyphs["folder"];
    return glyphs["file"];
}

function isGlyphSlot(slot) {
    if (!slot) return false;
    if (glyphs[slot]) return true;
    if (slot.indexOf("folder") === 0) return true;
    if (slot === "drive-usb" || slot === "drive-optical" || slot === "phone" || slot === "cloud") return true;
    return false;
}
