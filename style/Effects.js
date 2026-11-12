.pragma library

// auto-hide effects, used by the docks and the setting tiles.
// t: 0 shown .. 1 hidden (springy easings overshoot a bit). dist: how far a sliding dock travels
//
// returns off, opacity, scale, fold (squash onto the edge), bg (wave fades it separately)
function state(effect, t, dist) {
  const c = Math.max(0, Math.min(1, t));
  const s = { off: 0, opacity: 1, scale: 1, fold: 1, bg: 1, center: false };
  switch (effect) {
  case "fade":
    s.opacity = 1 - c;
    break;
  case "glide":
    s.off = t * dist;
    s.opacity = 1 - c;
    break;
  case "zoom":
    s.scale = Math.max(0.01, 1 - 0.4 * t);
    s.opacity = 1 - c;
    break;
  case "fold":
    s.fold = Math.max(0.01, 1 - t);
    s.opacity = 1 - 0.5 * c;
    break;
  case "pop":
    s.scale = Math.max(0.01, 1 - t);
    s.opacity = 1 - c;
    s.center = true;
    break;
  case "wave":
    s.bg = 1 - c;
    break;
  default:          // slide, bounce
    s.off = t * dist;
  }
  return s;
}

// easings that overshoot
function springy(effect) { return effect === "bounce" || effect === "pop"; }

// names for the settings
var labels = {
  slide: "Slide", fade: "Fade", glide: "Glide", zoom: "Zoom",
  fold: "Fold", bounce: "Bounce", pop: "Pop", wave: "Wave"
};
