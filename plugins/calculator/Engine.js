.pragma library
// The calculator's engine: a sum read into a tree and worked out from it, never run as
// code. Plain JavaScript with no Qt in it, so tools/calc-test.js can check it.
//
//   parse(text)            -> tree, or throws Error("what is wrong")
//   evaluate(tree, env)    -> number, or throws; env: { vars, ans, deg }
//   run(text, env)         -> { value, text, exact, store, roots, error } for the home line
//   compile(text)          -> f(x) for a graph (NaN where it has no value), or throws
//   format(v), exact(v)    -> the answer as shown, and its fraction or multiple of π
//   roots / extrema / stats / regress: what the graph and the lists work out
//
// What it reads, beyond numbers and + - × ÷ ^:
//   implicit products (2x, 3(4), 2π, (1)(2)), postfix ! ² ³ ⁻¹ and %, √, unary minus
//   a → name stores (or ->), ans is the last answer, letters are variables
//   an equation (x^2 = 2) on the home line is solved for its one unknown
//   sin cos tan and their inverses (in degrees or radians), sinh cosh tanh asinh acosh
//   atanh, sqrt cbrt root(x, n), ln log(x[, base]) exp, abs sign round(x[, places])
//   floor ceil int ipart fpart, min max gcd lcm mod ncr npr gamma, mean median, rand
//   randint(a, b), and, taking a sum of x: deriv(f, x, at) integral(f, x, a, b)
//   solve(f, x[, guess]) sum(f, k, a, b) prod(f, k, a, b)

// ---- reading ---------------------------------------------------------------------------

var CONSTS = { pi: Math.PI, "π": Math.PI, e: Math.E, phi: (1 + Math.sqrt(5)) / 2, tau: 2 * Math.PI };

// [arity: fixed count, or [min, max]], what it does with (args, env)
var FUNCS = {
    sin: [1, function (a, env) { return Math.sin(rad(a[0], env)); }],
    cos: [1, function (a, env) { return Math.cos(rad(a[0], env)); }],
    tan: [1, function (a, env) { return tanOf(rad(a[0], env)); }],
    asin: [1, function (a, env) { return unrad(Math.asin(a[0]), env); }],
    acos: [1, function (a, env) { return unrad(Math.acos(a[0]), env); }],
    atan: [[1, 2], function (a, env) { return unrad(a.length === 2 ? Math.atan2(a[0], a[1]) : Math.atan(a[0]), env); }],
    sinh: [1, function (a) { return Math.sinh(a[0]); }],
    cosh: [1, function (a) { return Math.cosh(a[0]); }],
    tanh: [1, function (a) { return Math.tanh(a[0]); }],
    asinh: [1, function (a) { return Math.asinh(a[0]); }],
    acosh: [1, function (a) { return Math.acosh(a[0]); }],
    atanh: [1, function (a) { return Math.atanh(a[0]); }],
    sqrt: [1, function (a) { return Math.sqrt(a[0]); }],
    cbrt: [1, function (a) { return Math.cbrt(a[0]); }],
    root: [2, function (a) { return nthRoot(a[0], a[1]); }],
    ln: [1, function (a) { return Math.log(a[0]); }],
    log: [[1, 2], function (a) { return a.length === 2 ? Math.log(a[0]) / Math.log(a[1]) : Math.log10(a[0]); }],
    exp: [1, function (a) { return Math.exp(a[0]); }],
    abs: [1, function (a) { return Math.abs(a[0]); }],
    sign: [1, function (a) { return Math.sign(a[0]); }],
    round: [[1, 2], function (a) { return roundTo(a[0], a.length === 2 ? a[1] : 0); }],
    floor: [1, function (a) { return Math.floor(a[0]); }],
    ceil: [1, function (a) { return Math.ceil(a[0]); }],
    int: [1, function (a) { return Math.floor(a[0]); }],
    ipart: [1, function (a) { return Math.trunc(a[0]); }],
    fpart: [1, function (a) { return a[0] - Math.trunc(a[0]); }],
    min: [[1, 99], function (a) { return Math.min.apply(null, a); }],
    max: [[1, 99], function (a) { return Math.max.apply(null, a); }],
    mean: [[1, 99], function (a) { return a.reduce(function (s, v) { return s + v; }, 0) / a.length; }],
    median: [[1, 99], function (a) { return quantile(a.slice().sort(function (p, q) { return p - q; }), 0.5); }],
    gcd: [[2, 99], function (a) { return a.reduce(gcd2); }],
    lcm: [[2, 99], function (a) { return a.reduce(function (p, q) { return p === 0 || q === 0 ? 0 : Math.abs(p * q) / gcd2(p, q); }); }],
    mod: [2, function (a) { return modOf(a[0], a[1]); }],
    ncr: [2, function (a) { return choose(a[0], a[1]); }],
    npr: [2, function (a) { return perm(a[0], a[1]); }],
    gamma: [1, function (a) { return gamma(a[0]); }],
    rand: [0, function () { return Math.random(); }],
    randint: [2, function (a) { var lo = Math.ceil(Math.min(a[0], a[1])), hi = Math.floor(Math.max(a[0], a[1])); return lo + Math.floor(Math.random() * (hi - lo + 1)); }]
};
// these take a sum of a variable, not its value: (f, var, ...numbers)
var LAZY = { deriv: [3, 3], integral: [4, 4], solve: [2, 3], sum: [4, 4], prod: [4, 4] };
var ALIASES = { arcsin: "asin", arccos: "acos", arctan: "atan", nderiv: "deriv", fnint: "integral",
                "√": "sqrt", "∛": "cbrt", lg: "log", sqr: "sqrt" };
var WORDS = ["ans"].concat(Object.keys(FUNCS), Object.keys(LAZY), Object.keys(ALIASES), Object.keys(CONSTS))
    .sort(function (a, b) { return b.length - a.length; });

function err(msg) { return new Error(msg); }

function tokenize(src) {
    var s = String(src).replace(/[−–]/g, "-").replace(/×|·|∙/g, "*").replace(/÷/g, "/")
        .replace(/->/g, "→");
    var out = [], i = 0;
    while (i < s.length) {
        var c = s[i];
        if (/\s/.test(c)) { i++; continue; }
        if (/[0-9.]/.test(c)) {
            var m = /^(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?/.exec(s.slice(i));
            if (!m || m[0] === ".") throw err("A lone point");
            out.push({ t: "num", v: parseFloat(m[0]), p: i });
            i += m[0].length;
            continue;
        }
        if (/[a-zA-Zπ]/.test(c)) {
            var w = /^[a-zA-Zπ]+/.exec(s.slice(i))[0];
            splitWord(w.toLowerCase(), i).forEach(function (tk) { out.push(tk); });
            i += w.length;
            continue;
        }
        if (c === "⁻" && s[i + 1] === "¹") { out.push({ t: "op", v: "⁻¹", p: i }); i += 2; continue; }
        if (c === "*" && s[i + 1] === "*") { out.push({ t: "op", v: "^", p: i }); i += 2; continue; }
        if ("+-*/^%!(),=²³√∛→".indexOf(c) >= 0) { out.push({ t: "op", v: c, p: i }); i++; continue; }
        if (c === "[" || c === "{") { out.push({ t: "op", v: "(", p: i }); i++; continue; }
        if (c === "]" || c === "}") { out.push({ t: "op", v: ")", p: i }); i++; continue; }
        if (c === ";") { out.push({ t: "op", v: ",", p: i }); i++; continue; }
        throw err("“" + c + "” isn't something it knows");
    }
    return out;
}

// a run of letters: one known name ("sin", "pi"), or several ("pix" is π·x, "xy" is x·y)
function splitWord(w, at) {
    var out = [], i = 0;
    while (i < w.length) {
        var hit = null;
        for (var k = 0; k < WORDS.length; k++) {
            if (w.substr(i, WORDS[k].length) === WORDS[k]) { hit = WORDS[k]; break; }
        }
        // nothing known starts here: a variable, which is one letter
        if (!hit) hit = w[i];
        out.push({ t: "name", v: ALIASES[hit] || hit, p: at + i });
        i += hit.length;
    }
    return out;
}

function Parser(tokens) { this.t = tokens; this.i = 0; }
Parser.prototype.peek = function () { return this.t[this.i]; };
Parser.prototype.is = function (v) { var k = this.t[this.i]; return !!k && k.t === "op" && k.v === v; };
Parser.prototype.take = function (v) {
    if (!this.is(v)) {
        var k = this.peek();
        throw err(k ? "Expected “" + v + "” before “" + (k.v + "") + "”" : "Expected “" + v + "” at the end");
    }
    this.i++;
};
// can the next token start a value (for 2x, 3(4), x sin y)?
Parser.prototype.startsValue = function () {
    var k = this.peek();
    if (!k) return false;
    if (k.t === "num" || k.t === "name") return true;
    return k.t === "op" && (k.v === "(" || k.v === "√" || k.v === "∛");
};

Parser.prototype.top = function () {
    var e = this.equation();
    if (this.is("→")) {
        this.i++;
        var k = this.peek();
        if (!k || k.t !== "name" || isReserved(k.v)) throw err("→ needs a letter to store in");
        this.i++;
        e = { k: "store", name: k.v, e: e };
    }
    if (this.i < this.t.length) throw err("“" + this.peek().v + "” is out of place");
    return e;
};
Parser.prototype.equation = function () {
    var l = this.additive();
    if (this.is("=")) { this.i++; return { k: "eq", l: l, r: this.additive() }; }
    return l;
};
Parser.prototype.additive = function () {
    var e = this.term();
    while (this.is("+") || this.is("-")) {
        var op = this.peek().v; this.i++;
        e = { k: "bin", op: op, l: e, r: this.term() };
    }
    return e;
};
Parser.prototype.term = function () {
    var e = this.unary();
    for (;;) {
        if (this.is("*") || this.is("/")) {
            var op = this.peek().v; this.i++;
            e = { k: "bin", op: op, l: e, r: this.unary() };
        } else if (this.is("%") && this.t[this.i + 1] && this.startsAfterPercent()) {
            this.i++;
            e = { k: "bin", op: "mod", l: e, r: this.unary() };
        } else if (this.startsValue()) {
            e = { k: "bin", op: "*", l: e, r: this.power() };
        } else break;
    }
    return e;
};
// 7 % 3 is a remainder; 50% (then nothing, or an operator) is a percent
Parser.prototype.startsAfterPercent = function () {
    var k = this.t[this.i + 1];
    return k.t === "num" || k.t === "name" || (k.t === "op" && (k.v === "(" || k.v === "√" || k.v === "∛"));
};
Parser.prototype.unary = function () {
    if (this.is("-")) { this.i++; return { k: "neg", e: this.unary() }; }
    if (this.is("+")) { this.i++; return this.unary(); }
    return this.power();
};
Parser.prototype.power = function () {
    var b = this.postfix();
    if (this.is("^")) { this.i++; return { k: "bin", op: "^", l: b, r: this.unary() }; }
    return b;
};
Parser.prototype.postfix = function () {
    var e = this.primary();
    for (;;) {
        if (this.is("!")) { this.i++; e = { k: "call", f: "fact", a: [e] }; }
        else if (this.is("²")) { this.i++; e = { k: "bin", op: "^", l: e, r: { k: "num", v: 2 } }; }
        else if (this.is("³")) { this.i++; e = { k: "bin", op: "^", l: e, r: { k: "num", v: 3 } }; }
        else if (this.is("⁻¹")) { this.i++; e = { k: "bin", op: "/", l: { k: "num", v: 1 }, r: e }; }
        else if (this.is("%") && !(this.t[this.i + 1] && this.startsAfterPercent())) { this.i++; e = { k: "bin", op: "/", l: e, r: { k: "num", v: 100 } }; }
        else break;
    }
    return e;
};
Parser.prototype.primary = function () {
    var k = this.peek();
    if (!k) throw err("Something is missing at the end");
    if (k.t === "num") { this.i++; return { k: "num", v: k.v }; }
    if (k.t === "op" && k.v === "(") {
        this.i++;
        var e = this.equation();
        // a bracket left open at the end closes itself, as on a calculator
        if (this.peek()) this.take(")");
        return e;
    }
    if (k.t === "op" && (k.v === "√" || k.v === "∛")) {
        this.i++;
        return { k: "call", f: k.v === "√" ? "sqrt" : "cbrt", a: [this.power()] };
    }
    if (k.t === "name") {
        this.i++;
        var n = k.v;
        if (n === "ans") return { k: "ans" };
        if (CONSTS[n] !== undefined) return { k: "num", v: CONSTS[n], name: n };
        if (FUNCS[n] || LAZY[n]) {
            var args = [];
            if (this.is("(")) {
                this.i++;
                if (!this.is(")") && this.peek()) {
                    args.push(this.equation());
                    while (this.is(",")) { this.i++; args.push(this.equation()); }
                }
                if (this.peek()) this.take(")");
            } else if (FUNCS[n] && FUNCS[n][0] !== 0) {
                // sin x, ln 2: a function without brackets takes the value after it
                args.push(this.power());
            }
            checkArity(n, args.length);
            if (LAZY[n]) {
                if (args[1].k !== "var") throw err(n + " needs a letter as its second part, like " + n + "(x^2, x, …)");
                return { k: "lazy", f: n, a: args };
            }
            return { k: "call", f: n, a: args };
        }
        return { k: "var", name: n };
    }
    throw err("“" + k.v + "” is out of place");
};

function checkArity(n, got) {
    var want = FUNCS[n] ? FUNCS[n][0] : LAZY[n];
    var lo = typeof want === "number" ? want : want[0], hi = typeof want === "number" ? want : want[1];
    if (got < lo || got > hi) {
        var says = lo === hi ? lo + (lo === 1 ? " value" : " values") : lo + " to " + hi + " values";
        throw err(n + " takes " + says + ", not " + got);
    }
}
function isReserved(n) { return n === "ans" || CONSTS[n] !== undefined || !!FUNCS[n] || !!LAZY[n]; }

function parse(text) {
    var tk = tokenize(text);
    if (tk.length === 0) throw err("Nothing to work out");
    return new Parser(tk).top();
}

// ---- working out ----------------------------------------------------------------------

function rad(v, env) { return env && env.deg ? v * Math.PI / 180 : v; }
function unrad(v, env) { return env && env.deg ? v * 180 / Math.PI : v; }
// tan(90°) is undefined, not 1.6e16
function tanOf(r) { var c = Math.cos(r); return Math.abs(c) < 1e-15 ? NaN : Math.sin(r) / c; }
function nthRoot(x, n) {
    if (x < 0 && Math.abs(n % 2) === 1) return -Math.pow(-x, 1 / n);
    return Math.pow(x, 1 / n);
}
function roundTo(v, places) { var f = Math.pow(10, Math.round(places)); return Math.round(v * f) / f; }
function gcd2(a, b) {
    a = Math.abs(Math.round(a)); b = Math.abs(Math.round(b));
    while (b) { var t = a % b; a = b; b = t; }
    return a;
}
function modOf(a, b) { return b === 0 ? NaN : a - b * Math.floor(a / b); }
function gamma(z) {
    if (z < 0.5) return Math.PI / (Math.sin(Math.PI * z) * gamma(1 - z));
    var g = 7, c = [0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
                    -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6,
                    1.5056327351493116e-7];
    z -= 1;
    var x = c[0];
    for (var i = 1; i < g + 2; i++) x += c[i] / (z + i);
    var t = z + g + 0.5;
    return Math.sqrt(2 * Math.PI) * Math.pow(t, z + 0.5) * Math.exp(-t) * x;
}
function fact(n) {
    if (n < 0 && Number.isInteger(n)) return NaN;
    if (Number.isInteger(n) && n <= 170) { var r = 1; for (var i = 2; i <= n; i++) r *= i; return r; }
    return gamma(n + 1);
}
function choose(n, k) {
    if (!Number.isInteger(n) || !Number.isInteger(k) || k < 0 || n < 0) return NaN;
    if (k > n) return 0;
    k = Math.min(k, n - k);
    var r = 1;
    for (var i = 1; i <= k; i++) r = r * (n - k + i) / i;
    return Math.round(r);
}
function perm(n, k) {
    if (!Number.isInteger(n) || !Number.isInteger(k) || k < 0 || n < 0) return NaN;
    if (k > n) return 0;
    var r = 1;
    for (var i = 0; i < k; i++) r *= n - i;
    return r;
}
function quantile(sorted, q) {
    if (sorted.length === 0) return NaN;
    var pos = (sorted.length - 1) * q, lo = Math.floor(pos), hi = Math.ceil(pos);
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

function evaluate(n, env) {
    switch (n.k) {
    case "num": return n.v;
    case "ans":
        if (env.ans === undefined || env.ans === null) throw err("There is no answer yet");
        return env.ans;
    case "var":
        if (env.bind && env.bind[n.name] !== undefined) return env.bind[n.name];
        if (env.vars && typeof env.vars[n.name] === "number") return env.vars[n.name];
        throw err(n.name + " has no value yet: store one with 5 → " + n.name);
    case "neg": return -evaluate(n.e, env);
    case "bin": {
        var l = evaluate(n.l, env), r = evaluate(n.r, env);
        switch (n.op) {
        case "+": return l + r;
        case "-": return l - r;
        case "*": return l * r;
        case "/": return l / r;
        case "mod": return modOf(l, r);
        case "^":
            // a cube root of a negative number is real: (-8)^(1/3) = -2
            if (l < 0 && !Number.isInteger(r)) {
                var inv = 1 / r;
                if (Math.abs(inv - Math.round(inv)) < 1e-9 && Math.round(inv) % 2 !== 0) return -Math.pow(-l, r);
            }
            return Math.pow(l, r);
        }
        throw err("Unknown operator " + n.op);
    }
    case "call": {
        var a = n.a.map(function (x) { return evaluate(x, env); });
        if (n.f === "fact") return fact(a[0]);
        return FUNCS[n.f][1](a, env);
    }
    case "lazy": return lazy(n, env);
    case "eq": return evaluate(n.l, env) - evaluate(n.r, env);
    case "store": return evaluate(n.e, env);
    }
    throw err("Can't work that out");
}

// f(v): the sum n.a[0] with the variable n.a[1] set to v
// (one scope made for it and reused: a graph or a root search calls it thousands of times;
// a lazy one inside it makes its own when it is worked out, so nothing is shared wrongly)
function bound(n, env) {
    var name = n.a[1].name, body = n.a[0];
    var b = Object.assign({}, env.bind || {});
    var scope = Object.assign({}, env, { bind: b });
    return function (v) {
        b[name] = v;
        return evaluate(body, scope);
    };
}

function lazy(n, env) {
    var f = bound(n, env);
    var num = function (i) { return evaluate(n.a[i], env); };
    switch (n.f) {
    case "deriv": {
        var at = num(2), h = 1e-4 * Math.max(1, Math.abs(at));
        // five points: exact for polynomials up to the fourth degree
        return (-f(at + 2 * h) + 8 * f(at + h) - 8 * f(at - h) + f(at - 2 * h)) / (12 * h);
    }
    case "integral": return integrate(f, num(2), num(3));
    case "solve": {
        var guess = n.a.length === 3 ? num(2) : 0;
        var r = solveNear(f, guess);
        if (r === null) throw err("No solution found near " + format(guess));
        return r;
    }
    case "sum": case "prod": {
        var a = Math.round(num(2)), b = Math.round(num(3));
        if (b - a > 1e6) throw err("That's too many steps");
        var acc = n.f === "sum" ? 0 : 1;
        for (var k = a; k <= b; k++) acc = n.f === "sum" ? acc + f(k) : acc * f(k);
        return acc;
    }
    }
    throw err("Can't work that out");
}

// adaptive Simpson, so curves with corners and peaks come out right
function integrate(f, a, b) {
    if (a === b) return 0;
    if (a > b) return -integrate(f, b, a);
    function simpson(a, b, fa, fm, fb) { return (b - a) / 6 * (fa + 4 * fm + fb); }
    var calls = 0;
    function rec(a, b, fa, fm, fb, whole, eps, depth) {
        var m = (a + b) / 2, lm = (a + m) / 2, rm = (m + b) / 2;
        var flm = f(lm), frm = f(rm);
        calls += 2;
        var left = simpson(a, m, fa, flm, fm), right = simpson(m, b, fm, frm, fb);
        if (depth <= 0 || calls > 40000 || Math.abs(left + right - whole) <= 15 * eps)
            return left + right + (left + right - whole) / 15;
        return rec(a, m, fa, flm, fm, left, eps / 2, depth - 1) + rec(m, b, fm, frm, fb, right, eps / 2, depth - 1);
    }
    // split into pieces first, so a narrow peak isn't missed
    var pieces = 16, h = (b - a) / pieces, total = 0;
    for (var i = 0; i < pieces; i++) {
        var x0 = a + i * h, x1 = x0 + h, xm = (x0 + x1) / 2;
        var f0 = f(x0), fm = f(xm), f1 = f(x1);
        total += rec(x0, x1, f0, fm, f1, simpson(x0, x1, f0, fm, f1), 1e-10, 30);
    }
    return total;
}

// a root near the guess: Newton's steps, then a wider search with bisection
function solveNear(f, guess) {
    var x = guess;
    for (var i = 0; i < 60; i++) {
        var fx = f(x);
        if (!isFinite(fx)) break;
        if (Math.abs(fx) < 1e-14) return clean(x);
        var h = 1e-7 * Math.max(1, Math.abs(x));
        var d = (f(x + h) - f(x - h)) / (2 * h);
        if (!isFinite(d) || d === 0) break;
        var nx = x - fx / d;
        if (!isFinite(nx)) break;
        if (Math.abs(nx - x) < 1e-13 * Math.max(1, Math.abs(x))) { x = nx; if (Math.abs(f(x)) < 1e-9) return clean(x); break; }
        x = nx;
    }
    // look outwards from the guess for a change of sign
    for (var span = 1; span <= 1e6; span *= 4) {
        var found = roots(f, guess - span, guess + span, 400);
        if (found.length) {
            found.sort(function (p, q) { return Math.abs(p - guess) - Math.abs(q - guess); });
            return found[0];
        }
    }
    return null;
}

// tidy a root: 1.9999999999999998 is 2
function clean(x) {
    var r = Math.round(x);
    if (Math.abs(x - r) < 1e-12 * Math.max(1, Math.abs(x))) return r;
    var p = parseFloat(x.toPrecision(13));
    return p;
}

// every root of f between a and b that shows as a change of sign (or a touch of zero)
// in n steps, each made exact by bisection; poles (where f jumps through infinity) are
// left out. At most `limit` of them (all, without one), from a towards b.
function roots(f, a, b, n, limit) {
    var out = [], h = (b - a) / n, x0 = a, y0 = f(a), cap = limit || Infinity;
    function add(r) {
        for (var i = 0; i < out.length; i++) if (Math.abs(out[i] - r) < Math.abs(h) * 1e-3) return;
        out.push(clean(r));
    }
    if (y0 === 0) add(a);
    for (var i = 1; i <= n && out.length < cap; i++) {
        var x1 = a + i * h, y1 = f(x1);
        if (isFinite(y0) && isFinite(y1)) {
            if (y1 === 0) add(x1);
            else if (y0 !== 0 && (y0 < 0) !== (y1 < 0)) {
                var lo = x0, hi = x1, flo = y0;
                for (var k = 0; k < 80 && hi - lo > 1e-15 * Math.max(1, Math.abs(lo)); k++) {
                    var m = (lo + hi) / 2, fm = f(m);
                    if (!isFinite(fm)) break;
                    if ((fm < 0) === (flo < 0)) { lo = m; flo = fm; } else hi = m;
                }
                var r = (lo + hi) / 2, fr = f(r);
                // a real root goes to zero; a pole only changes sign while blowing up
                if (isFinite(fr) && Math.abs(fr) < 1e-6 * Math.max(1, Math.abs(y0), Math.abs(y1)) ) add(r);
            }
        }
        x0 = x1; y0 = y1;
    }
    return out;
}

// the highest and lowest points of f between a and b: [{ x, y, kind: "max"|"min" }]
function extrema(f, a, b, n) {
    var out = [], h = (b - a) / n, ys = [];
    for (var i = 0; i <= n; i++) ys.push(f(a + i * h));
    for (var j = 1; j < n; j++) {
        var p = ys[j - 1], c = ys[j], q = ys[j + 1];
        if (!isFinite(p) || !isFinite(c) || !isFinite(q)) continue;
        var isMax = c > p && c >= q, isMin = c < p && c <= q;
        if (!isMax && !isMin) continue;
        // golden-section search inside the two steps around it
        var lo = a + (j - 1) * h, hi = a + (j + 1) * h, gr = (Math.sqrt(5) - 1) / 2;
        var sgn = isMax ? -1 : 1;
        var x1 = hi - gr * (hi - lo), x2 = lo + gr * (hi - lo), f1 = sgn * f(x1), f2 = sgn * f(x2);
        for (var k = 0; k < 80; k++) {
            if (f1 < f2) { hi = x2; x2 = x1; f2 = f1; x1 = hi - gr * (hi - lo); f1 = sgn * f(x1); }
            else { lo = x1; x1 = x2; f1 = f2; x2 = lo + gr * (hi - lo); f2 = sgn * f(x2); }
        }
        var x = clean((lo + hi) / 2), y = f(x);
        // a spike next to a pole isn't a turning point
        if (isFinite(y) && Math.abs(y) < 1e12) out.push({ x: x, y: clean(y), kind: isMax ? "max" : "min" });
    }
    return out;
}

// ---- the home line --------------------------------------------------------------------

// the letters in a tree that have no value (the unknowns of an equation)
function unknowns(n, env, acc) {
    acc = acc || [];
    if (!n || typeof n !== "object") return acc;
    if (n.k === "var" && !(env.vars && typeof env.vars[n.name] === "number") && acc.indexOf(n.name) < 0) acc.push(n.name);
    if (n.k === "lazy") { unknowns(n.a[0], env, []).forEach(function (u) { if (u !== n.a[1].name && acc.indexOf(u) < 0) acc.push(u); }); n.a.slice(2).forEach(function (x) { unknowns(x, env, acc); }); return acc; }
    ["l", "r", "e"].forEach(function (k) { if (n[k]) unknowns(n[k], env, acc); });
    if (n.a) n.a.forEach(function (x) { unknowns(x, env, acc); });
    return acc;
}

// a line on the home screen: { value, text, exact, store, solvedFor, roots } or { error }
function run(text, env) {
    try {
        var tree = parse(text);
        if (tree.k === "eq") {
            var u = unknowns(tree, env);
            var name = u.length === 1 ? u[0] : u.length === 0 ? "x" : null;
            if (!name) return { error: "An equation needs one unknown; it has " + u.join(", ") };
            var f = bound({ a: [tree, { k: "var", name: name }] }, env);
            var rs = solutions(f);
            if (rs.length === 0) return { error: "No real solution for " + name };
            return { value: rs[0], text: rs.map(function (r) { return name + " = " + format(r); }).join("    ") + (rs.more ? "    …" : ""),
                     exact: rs.length === 1 ? exact(rs[0]) : "", solvedFor: name, roots: rs.slice(), more: rs.more };
        }
        var v = evaluate(tree, env);
        if (typeof v !== "number" || isNaN(v)) return { error: "Not a real number" };
        if (!isFinite(v)) return { error: v > 0 ? "Too large (or a division by zero)" : "Too large, below zero" };
        var out = { value: v, text: format(v), exact: exact(v) };
        if (tree.k === "store") out.store = tree.name;
        return out;
    } catch (e) {
        return { error: e.message || String(e) };
    }
}

// the real solutions of f(x) = 0 people look for: finely near zero, more widely out to
// ±1000, and where the curve only touches zero (x² = 0). The six nearest zero, in order;
// `more` on the list says there were others (tan x = 0 has hundreds)
function solutions(f) {
    var rs = [];
    function add(r) { if (!rs.some(function (q) { return Math.abs(q - r) < 1e-9 * Math.max(1, Math.abs(r)); })) rs.push(r); }
    roots(f, -10, 10, 4000).forEach(add);
    // further out only when near zero didn't give enough, each side from zero outwards
    if (rs.length < 6) {
        roots(f, 10, 1000, 4000, 6).forEach(add);
        roots(f, -10, -1000, 4000, 6).forEach(add);
    }
    extrema(f, -10, 10, 4000).forEach(function (p) { if (Math.abs(p.y) < 1e-10) add(p.x); });
    if (rs.length === 0) { var near = solveNear(f, 0); if (near !== null) add(near); }
    rs.sort(function (a, b) { return Math.abs(a) - Math.abs(b) || a - b; });
    var out = rs.slice(0, 6).sort(function (a, b) { return a - b; });
    out.more = rs.length > 6;
    return out;
}

// a graph's sum of x, worked out fast: NaN where it has no value
function compile(text, env) {
    var tree = parse(text);
    if (tree.k === "store") throw err("A graph can't store a value");
    if (tree.k === "eq") {
        // y = 2x + 1 is the same as 2x + 1
        if (tree.l.k === "var" && tree.l.name === "y") tree = tree.r;
        else throw err("Write it as a sum of x, like x^2 - 1");
    }
    var bind = { x: 0 };
    var scope = Object.assign({ vars: {} }, env || {}, { bind: bind });
    return function (x) {
        try {
            bind.x = x;
            var v = evaluate(tree, scope);
            return typeof v === "number" ? v : NaN;
        } catch (e) { return NaN; }
    };
}

// ---- showing numbers ------------------------------------------------------------------

function format(v) {
    if (typeof v !== "number" || isNaN(v)) return "—";
    if (!isFinite(v)) return v > 0 ? "∞" : "−∞";
    if (v === 0) return "0";
    var a = Math.abs(v);
    if (a >= 1e15 || a < 1e-9) {
        var m = v.toExponential(9).replace(/\.?0+e/, "e");
        var parts = m.split("e");
        return (parts[0] + " × 10^" + parseInt(parts[1], 10)).replace(/-/g, "−");
    }
    // ten digits, as a TI-84 shows them: what a numeric method leaves past them goes
    var s = String(parseFloat(v.toPrecision(10)));
    if (/e/.test(s)) s = v.toFixed(12).replace(/\.?0+$/, "");
    return s.replace("-", "−");
}

// the same number as a fraction or a multiple of π, when it is one (0.75 is 3/4); ""
// when it is a whole number or no small fraction fits
function exact(v) {
    if (typeof v !== "number" || !isFinite(v) || Number.isInteger(v) || Math.abs(v) > 1e9) return "";
    var f = fraction(v, 10000);
    if (f && f[1] !== 1) return (f[0] < 0 ? "−" : "") + Math.abs(f[0]) + "/" + f[1];
    var p = fraction(v / Math.PI, 360);
    if (p && Math.abs(p[0]) <= 1000) {
        var num = Math.abs(p[0]) === 1 ? "" : String(Math.abs(p[0]));
        return (p[0] < 0 ? "−" : "") + num + "π" + (p[1] === 1 ? "" : "/" + p[1]);
    }
    var r = fraction(v * v, 10000);
    if (r && r[0] > 0 && !isSquare(r[0] * r[1]) && r[0] <= 10000) {
        // √(a/b) as k√m / n
        var top = r[0] * r[1], bottom = r[1];
        var k = 1, m = top;
        for (var d = Math.floor(Math.sqrt(m)); d > 1; d--) if (m % (d * d) === 0) { k = d; m = m / (d * d); break; }
        var g = gcd2(k, bottom);
        k /= g; bottom /= g;
        if (m < 10000) return (v < 0 ? "−" : "") + (k === 1 ? "" : k) + "√" + m + (bottom === 1 ? "" : "/" + bottom);
    }
    return "";
}
function isSquare(n) { var s = Math.round(Math.sqrt(n)); return s * s === n; }
// [p, q] with p/q = v to 12 digits and q at most maxDen, or null
function fraction(v, maxDen) {
    var x = v, h0 = 1, h1 = 0, k0 = 0, k1 = 1;
    for (var i = 0; i < 40; i++) {
        var a = Math.floor(x);
        var h2 = a * h0 + h1, k2 = a * k0 + k1;
        if (k2 > maxDen) break;
        h1 = h0; h0 = h2; k1 = k0; k0 = k2;
        if (Math.abs(v - h0 / k0) <= 1e-12 * Math.max(1, Math.abs(v))) return [h0, k0];
        var frac = x - a;
        if (frac < 1e-15) break;
        x = 1 / frac;
    }
    return null;
}

// the number in other bases, for whole numbers: { hex, bin, oct } or null
function bases(v) {
    if (!Number.isInteger(v) || Math.abs(v) > 0xFFFFFFFFFFFF) return null;
    var sign = v < 0 ? "−" : "", a = Math.abs(v);
    return { hex: sign + "0x" + a.toString(16).toUpperCase(), bin: sign + "0b" + a.toString(2), oct: sign + "0o" + a.toString(8) };
}

// ---- lists ------------------------------------------------------------------------------

// "1, 2, 3.5 4" -> [1, 2, 3.5, 4]; each item may be a sum ("2^3, pi"); throws on a bad one
function parseList(text, env) {
    var s = String(text).trim();
    if (s === "") return [];
    // items are split on commas and semicolons, or on spaces when there are none
    var parts = /[,;]/.test(s) ? s.split(/[,;]/) : s.split(/\s+/);
    return parts.map(function (p) { return p.trim(); }).filter(function (p) { return p !== ""; }).map(function (p) {
        var v = evaluate(parse(p), env || {});
        if (!isFinite(v)) throw err("“" + p + "” isn't a number");
        return v;
    });
}

// one list's numbers: n, sum, mean, the spreads and the five-number summary
function stats(xs) {
    var n = xs.length;
    if (n === 0) return null;
    var s = xs.slice().sort(function (a, b) { return a - b; });
    var sum = 0, sum2 = 0;
    xs.forEach(function (v) { sum += v; sum2 += v * v; });
    var mean = sum / n, ss = 0;
    xs.forEach(function (v) { ss += (v - mean) * (v - mean); });
    // the quartiles as the TI-84 takes them: the medians of the lower and upper halves
    var half = Math.floor(n / 2);
    var lower = s.slice(0, half), upper = s.slice(n % 2 ? half + 1 : half);
    return { n: n, sum: sum, sum2: sum2, mean: mean,
             sx: n > 1 ? Math.sqrt(ss / (n - 1)) : NaN, sigma: Math.sqrt(ss / n),
             min: s[0], q1: n > 1 ? quantile(lower, 0.5) : s[0], median: quantile(s, 0.5),
             q3: n > 1 ? quantile(upper, 0.5) : s[0], max: s[n - 1] };
}

// y = a·x + b through the pairs, with r and r²; and, given three or more, y = a·x² + b·x + c
function regress(xs, ys) {
    var n = Math.min(xs.length, ys.length);
    if (n < 2) return null;
    var mx = 0, my = 0;
    for (var i = 0; i < n; i++) { mx += xs[i]; my += ys[i]; }
    mx /= n; my /= n;
    var sxx = 0, syy = 0, sxy = 0;
    for (var j = 0; j < n; j++) { var dx = xs[j] - mx, dy = ys[j] - my; sxx += dx * dx; syy += dy * dy; sxy += dx * dy; }
    if (sxx === 0) return null;
    var a = sxy / sxx, b = my - a * mx, r = syy === 0 ? 1 : sxy / Math.sqrt(sxx * syy);
    var out = { n: n, a: a, b: b, r: r, r2: r * r, quad: null };
    if (n >= 3) {
        // the normal equations for a·x² + b·x + c
        var S = [0, 0, 0, 0, 0], T = [0, 0, 0];
        for (var k = 0; k < n; k++) {
            var x = xs[k], y = ys[k], p = 1;
            for (var e = 0; e <= 4; e++) { S[e] += p; if (e <= 2) T[e] += p * y; p *= x; }
        }
        var M = [[S[4], S[3], S[2], T[2]], [S[3], S[2], S[1], T[1]], [S[2], S[1], S[0], T[0]]];
        var q = gauss(M);
        if (q) {
            var res = 0;
            for (var m = 0; m < n; m++) { var fy = q[0] * xs[m] * xs[m] + q[1] * xs[m] + q[2]; res += (ys[m] - fy) * (ys[m] - fy); }
            out.quad = { a: q[0], b: q[1], c: q[2], r2: syy === 0 ? 1 : 1 - res / syy };
        }
    }
    return out;
}
function gauss(M) {
    var n = M.length;
    for (var c = 0; c < n; c++) {
        var p = c;
        for (var r = c + 1; r < n; r++) if (Math.abs(M[r][c]) > Math.abs(M[p][c])) p = r;
        if (Math.abs(M[p][c]) < 1e-12) return null;
        var t = M[c]; M[c] = M[p]; M[p] = t;
        for (var r2 = 0; r2 < n; r2++) {
            if (r2 === c) continue;
            var f = M[r2][c] / M[c][c];
            for (var k = c; k <= n; k++) M[r2][k] -= f * M[c][k];
        }
    }
    return M.map(function (row, i) { return row[n] / row[i]; });
}

// a number as it goes back into a sum (no thousands, no "×10^"), for a fit sent to a graph
function plain(v) {
    if (!isFinite(v)) return "0";
    var s = String(parseFloat(v.toPrecision(10)));
    return s.indexOf("e") >= 0 ? "(" + s.replace("e", "*10^(") + "))" : s;
}

// nice steps for an axis between lo and hi: about n of them, at 1, 2 or 5 × 10^k
function ticks(lo, hi, n) {
    var span = hi - lo;
    if (!(span > 0)) return [];
    var raw = span / Math.max(1, n), mag = Math.pow(10, Math.floor(Math.log10(raw)));
    var step = [1, 2, 5, 10].map(function (m) { return m * mag; }).find(function (s) { return s >= raw; });
    var out = [];
    for (var v = Math.ceil(lo / step) * step; v <= hi + step * 1e-9; v += step) out.push(Math.abs(v) < step * 1e-9 ? 0 : v);
    return out;
}
