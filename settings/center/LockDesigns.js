.pragma library

// The lock screens: "custom" is the shell's own, every other one a design hyprlock draws
// (bin/aequalyn-lockscreen). Shown by the Lock and sleep page and the Quick looks panel.
var list = [
    { key: "classic", label: "Classic", about: "The time, your name and the password over the blurred wallpaper." },
    { key: "clean", label: "Clean", about: "A big clock and the date over a soft blur, a round password line under them." },
    { key: "mono", label: "Mono", about: "Only your theme's colour: a large clock, the date, the password line at the bottom." },
    { key: "corner", label: "Corner", about: "The wallpaper as it is; the time in the lower left, the password in the lower right." },
    { key: "pill", label: "Pill", about: "One pill in the middle holding the time and the password." },
    { key: "split", label: "Split", about: "A panel down the left with the time, the date and your name; the wallpaper beside it." },
    { key: "stack", label: "Stack", about: "Hours over minutes, large, the minutes in the accent colour." },
    { key: "dot", label: "Dot", about: "Nothing but a greeting and the dots you type, on your theme's colour." },
    { key: "frame", label: "Frame", about: "The wallpaper inside a thin accent frame, the time at the top." },
    { key: "glass", label: "Glass", about: "A see-through card on a deep blur, with the time, the date and the password." },
    { key: "line", label: "Line", about: "A single accent line to type on, and the time small at the top." },
    { key: "terminal", label: "Terminal", about: "A prompt in the corner: the seconds ticking, your name, and a password: line to type after." },
    { key: "neon", label: "Neon", about: "A glowing clock, date and password ring in your accent colours on the dark." },
    { key: "poster", label: "Poster", about: "Today's name across the whole screen, faint, with the time small over it." },
    { key: "orbit", label: "Orbit", about: "A ring in your two accents around the time and the date." },
    { key: "dashboard", label: "Dashboard", about: "The time, then the battery, how long it has been on, and what is playing." },
    { key: "zen", label: "Zen", about: "No clock to watch: a greeting for the time of day over a deep blur." },
    { key: "vertical", label: "Vertical", about: "The time turned on its side down a dark strip on the left." },
    { key: "duo", label: "Duo", about: "Hours and minutes side by side, the minutes in the accent colour, split by a line." },
    { key: "card", label: "Card", about: "Your picture (~/.face), your name and the password on one card at the bottom." },
    { key: "nowplaying", label: "Now playing", about: "The song's cover, large, with its title and artist, and whether it plays." },
    { key: "binary", label: "Binary", about: "The time in dots, hours over minutes, for those who read them." },
    { key: "words", label: "Words", about: "The time as you'd say it, \"twenty past eleven\", large on the left." },
    { key: "day", label: "Day", about: "The time, and a bar of how much of today has already gone." },
    { key: "calendar", label: "Calendar", about: "The time beside this month's calendar, on one card." },
    { key: "weather", label: "Weather", about: "The time and the sky where you are, looked up every half hour." },
    { key: "quote", label: "Quote", about: "A short line to read, a different one each day, over a deep blur." },
    { key: "avatar", label: "Avatar", about: "Your picture (~/.face) large in a ring of your two accents, your name under it." },
    { key: "battery", label: "Battery", about: "The time, the battery as a bar of blocks, and how long it has been on." },
    { key: "custom", label: "Custom", about: "Your own layout: place elements where you want them and save." }
];
