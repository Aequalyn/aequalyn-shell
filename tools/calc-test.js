#!/usr/bin/env node
// calc-test: checks the calculator's engine (plugins/calculator/Engine.js) against sums
// with known answers.   node tools/calc-test.js
"use strict";
const fs = require("fs");
const path = require("path");
const src = fs.readFileSync(path.join(__dirname, "..", "plugins", "calculator", "Engine.js"), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const E = new Function(src + "\nreturn { parse, evaluate, run, compile, format, exact, bases, parseList, stats, regress, roots, extrema, ticks, plain, solutions };")();

let failed = 0, passed = 0;
function near(a, b, tol) { return Math.abs(a - b) <= (tol || 1e-9) * Math.max(1, Math.abs(b)); }
function check(name, ok, got) {
    if (ok) passed++;
    else { failed++; console.log("FAIL  " + name + "   got: " + JSON.stringify(got)); }
}
function val(sum, want, env, tol) {
    const r = E.run(sum, Object.assign({ vars: {}, ans: null, deg: false }, env || {}));
    check(sum + " = " + want, r.error === undefined && near(r.value, want, tol), r);
}
function bad(sum, env) {
    const r = E.run(sum, Object.assign({ vars: {}, ans: null, deg: false }, env || {}));
    check(sum + " is an error", r.error !== undefined, r);
}
function shows(fn, v, want) { const got = E[fn](v); check(fn + "(" + v + ") = " + want, got === want, got); }

// the basics, and the order of operations
val("1+2*3", 7);
val("(1+2)*3", 9);
val("2^3^2", 512);
val("-2^2", -4);
val("(-2)^2", 4);
val("2^-1", 0.5);
val("10/4", 2.5);
val("7 % 3", 1);
val("-7 % 3", 2);
val("50%", 0.5);
val("200 * 15%", 30);
val("50% + 1", 1.5);
val("50% - 10", -9.5);
val("1.5e3", 1500);
val(".5 + .25", 0.75);
val("3 × 4 ÷ 2 − 1", 5);
val("2**10", 1024);
val("((2+3)", 5);
val("sqrt(16", 4);
// implicit products
val("2pi", 2 * Math.PI);
val("2(3+4)", 14);
val("(1+1)(2+2)", 8);
val("3x", 6, { vars: { x: 2 } });
val("xy", 6, { vars: { x: 2, y: 3 } });
val("2sin(pi/2)", 2);
val("4√9", 12);
val("√2√2", 2);
val("2x^2", 18, { vars: { x: 3 } });
// postfix
val("5!", 120);
val("0!", 1);
val("4.5!", 52.34277778455352, null, 1e-9);
val("3²", 9);
val("2³", 8);
val("4⁻¹", 0.25);
val("3²!", 362880);
// functions
val("sin(pi/6)", 0.5);
val("sin 30", 0.5, { deg: true });
val("cos(60)", 0.5, { deg: true });
val("asin(1)", 90, { deg: true });
val("atan(1, 1)", 45, { deg: true });
val("ln(e)", 1);
val("log(1000)", 3);
val("log(8, 2)", 3);
val("exp(0)", 1);
val("root(27, 3)", 3);
val("root(-27, 3)", -3);
val("(-8)^(1/3)", -2);
val("cbrt(-8)", -2);
val("abs(-3.5)", 3.5);
val("round(2.567, 2)", 2.57);
val("round(2.5)", 3);
val("ipart(-2.7)", -2);
val("fpart(2.75)", 0.75);
val("int(-2.5)", -3);
val("min(3, 1, 2)", 1);
val("max(3, 1, 2)", 3);
val("gcd(12, 18)", 6);
val("lcm(4, 6)", 12);
val("ncr(5, 2)", 10);
val("npr(5, 2)", 20);
val("mod(10, 3)", 1);
val("mean(1, 2, 3, 4)", 2.5);
val("median(5, 1, 3)", 3);
val("gamma(5)", 24, null, 1e-9);
val("sinh(0)", 0);
val("arcsin(0)", 0);
val("phi", (1 + Math.sqrt(5)) / 2);
// lazy ones: derivatives, integrals, solving, sums
val("deriv(x^3, x, 2)", 12, null, 1e-7);
val("nderiv(sin(x), x, 0)", 1, null, 1e-7);
val("integral(x^2, x, 0, 3)", 9, null, 1e-9);
val("fnint(sin(x), x, 0, pi)", 2, null, 1e-9);
val("integral(abs(x), x, -1, 1)", 1, null, 1e-7);
val("integral(1/x, x, 1, e)", 1, null, 1e-9);
val("solve(x^2 - 2, x, 1)", Math.SQRT2, null, 1e-10);
val("solve(cos(x) = x, x)", 0.7390851332151607, null, 1e-10);
val("sum(k, k, 1, 100)", 5050);
val("sum(1/k^2, k, 1, 1000)", 1.6439345666815615, null, 1e-12);
val("prod(k, k, 1, 5)", 120);
val("deriv(a x^2, x, 1)", 6, { vars: { a: 3 } }, 1e-7);
// variables and the answer
val("ans * 2", 10, { ans: 5 });
val("ans", 5, { ans: 5 });
{
    const r = E.run("5 → a", { vars: {}, ans: null });
    check("5 → a stores a", r.store === "a" && r.value === 5, r);
    const r2 = E.run("3+4->b", { vars: {}, ans: null });
    check("3+4->b stores b", r2.store === "b" && r2.value === 7, r2);
}
// equations on the home line are solved
{
    const r = E.run("x^2 = 4", { vars: {} });
    check("x^2 = 4 has -2 and 2", r.roots && r.roots.length === 2 && near(r.roots[0], -2) && near(r.roots[1], 2), r);
    const r2 = E.run("x^2 = 0", { vars: {} });
    check("x^2 = 0 has 0", r2.roots && r2.roots.length === 1 && near(r2.roots[0], 0), r2);
    const r3 = E.run("2t + 1 = 7", { vars: {} });
    check("2t + 1 = 7 solves t = 3", r3.solvedFor === "t" && near(r3.value, 3), r3);
    const r4 = E.run("x^2 = -1", { vars: {} });
    check("x^2 = -1 has no real solution", r4.error !== undefined, r4);
    const r5 = E.run("tan(x) = 0", { vars: {} });
    check("tan(x) = 0 finds 0 and no poles", r5.roots && r5.roots.some(v => near(v, 0)) && r5.roots.every(v => near(Math.tan(v), 0, 1e-6)), r5);
    const r6 = E.run("x = 2y", { vars: {} });
    check("x = 2y has two unknowns", r6.error !== undefined, r6);
}
// errors read as errors
bad("");
bad("2 +");
bad("1/0");
bad("sqrt(-1)");
bad("ln(0)");
bad("tan(90)", { deg: true });
bad("q + 1");
bad("sin(1, 2)");
bad("5 → pi");
bad("2 # 3");
bad(")");
bad("deriv(x^2, 2, 1)");
bad("ans");
bad(".");
// code never runs: names that aren't known are variables, nothing else
bad("constructor");
bad("this");
bad("alert(1)");
// showing answers
shows("format", 0.1 + 0.2, "0.3");
shows("format", 1 / 3, "0.3333333333");
shows("format", 3.99999999999, "4");
shows("format", 123456.7890123, "123456.789");
shows("format", 1e20, "1 × 10^20");
shows("format", -2.5e-12, "−2.5 × 10^−12");
shows("format", 123456789, "123456789");
shows("format", -4, "−4");
shows("exact", 0.75, "3/4");
shows("exact", -1 / 3, "−1/3");
shows("exact", Math.PI / 2, "π/2");
shows("exact", 3 * Math.PI / 4, "3π/4");
shows("exact", Math.SQRT2, "√2");
shows("exact", Math.SQRT1_2, "√2/2");
shows("exact", 2 * Math.sqrt(3), "2√3");
shows("exact", 5, "");
shows("exact", 0.123456789123, "");
check("format reads back", near(E.run(E.format(-2.5e-12), {}).value, -2.5e-12), E.format(-2.5e-12));
{
    const b = E.bases(255);
    check("bases(255)", b && b.hex === "0xFF" && b.bin === "0b11111111" && b.oct === "0o377", b);
    check("bases(2.5) is none", E.bases(2.5) === null, E.bases(2.5));
}
// graphs
{
    const f = E.compile("x^2 - 1");
    check("compile x^2 - 1 at 3", f(3) === 8, f(3));
    const g = E.compile("y = 2x + 1");
    check("compile y = 2x + 1 at 2", g(2) === 5, g(2));
    const h = E.compile("1/x");
    check("1/x at 0 is not a number", !isFinite(h(0)), h(0));
    const s = E.compile("sqrt(x)");
    check("sqrt(x) at -1 is NaN", isNaN(s(-1)), s(-1));
    const a = E.compile("a x", { vars: { a: 2 } });
    check("compile with a stored a", a(3) === 6, a(3));
    let threw = false;
    try { E.compile("5 → a"); } catch (e) { threw = true; }
    check("a graph can't store", threw, threw);
    const rs = E.roots(E.compile("x^2 - 2"), -10, 10, 400);
    check("roots of x^2 - 2", rs.length === 2 && near(rs[0], -Math.SQRT2) && near(rs[1], Math.SQRT2), rs);
    const tp = E.roots(E.compile("tan(x)"), -5, 5, 800);
    check("roots of tan leave out its poles", tp.every(v => Math.abs(Math.tan(v)) < 1e-6) && tp.length === 3, tp);
    const ex = E.extrema(E.compile("x^3 - 3x"), -3, 3, 600);
    check("extrema of x^3 - 3x", ex.length === 2 && ex.some(p => p.kind === "max" && near(p.x, -1, 1e-6) && near(p.y, 2, 1e-6))
          && ex.some(p => p.kind === "min" && near(p.x, 1, 1e-6) && near(p.y, -2, 1e-6)), ex);
    const ep = E.extrema(E.compile("1/x"), -2, 2, 401);
    check("1/x has no turning points", ep.length === 0, ep);
    check("ticks 0..10", JSON.stringify(E.ticks(0, 10, 5)) === "[0,2,4,6,8,10]", E.ticks(0, 10, 5));
    check("ticks -1..1", E.ticks(-1, 1, 4).indexOf(0) >= 0, E.ticks(-1, 1, 4));
    check("plain(1e-7)", near(E.run(E.plain(1e-7), {}).value, 1e-7), E.plain(1e-7));
}
// lists, statistics and fits
{
    const l = E.parseList("1, 2, 3, 4, 5", {});
    check("parseList commas", JSON.stringify(l) === "[1,2,3,4,5]", l);
    check("parseList spaces", JSON.stringify(E.parseList("1 2  3", {})) === "[1,2,3]", E.parseList("1 2  3", {}));
    check("parseList sums", near(E.parseList("2^3, pi", {})[1], Math.PI), E.parseList("2^3, pi", {}));
    let threw = false;
    try { E.parseList("1, q", {}); } catch (e) { threw = true; }
    check("parseList bad item", threw, threw);
    const s = E.stats([1, 2, 3, 4, 5, 6, 7]);
    check("stats mean", s.mean === 4 && s.median === 4 && s.n === 7 && s.sum === 28, s);
    check("stats quartiles (TI)", s.q1 === 2 && s.q3 === 6, s);
    check("stats sx", near(s.sx, 2.160246899469287), s);
    check("stats sigma", near(s.sigma, 2), s);
    const s2 = E.stats([1, 2, 3, 4]);
    check("stats even quartiles", s2.q1 === 1.5 && s2.q3 === 3.5 && s2.median === 2.5, s2);
    const r = E.regress([1, 2, 3, 4], [3, 5, 7, 9]);
    check("linear fit", near(r.a, 2) && near(r.b, 1) && near(r.r, 1), r);
    const q = E.regress([0, 1, 2, 3], [1, 2, 5, 10]);
    check("quadratic fit", q.quad && near(q.quad.a, 1) && near(q.quad.b, 0, 1e-9) && near(q.quad.c, 1) && near(q.quad.r2, 1), q.quad);
    check("fit needs two", E.regress([1], [2]) === null, E.regress([1], [2]));
}

console.log(passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
