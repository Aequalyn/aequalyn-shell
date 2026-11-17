#!/usr/bin/python3
"""Turns a cover the image library won't open with its plain loaders into a PNG.

Radio stations and some players hand over a favicon as their cover: an .ico, a .bmp
or an .svg. The cover step only uses the plain loaders (PNG, JPEG, GIF, WebP), so
these are made into a PNG here first, and that PNG then goes through the same
shrinking as every other cover:

  * .ico and .bmp are read here, in Python, with no library at all: the largest
    picture in an icon, at most 1024 by 1024
  * .svg is drawn by rsvg-convert at 256 by 256, read from stdin so it can't load
    other files next to it

It runs under the same memory and processor limits as the rest of the cover step,
reads at most 8 MiB and exits 1 on anything it doesn't know.

    art.py SOURCE TARGET.png
"""
import os
import shutil
import struct
import subprocess
import sys
import zlib

MAX_BYTES = 8 * 1048576
MAX_SIDE = 1024


class Bad(Exception):
    pass


def png(w, h, rgba):
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    rows = b"".join(b"\x00" + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows, 6)) + chunk(b"IEND", b""))


def dib(data, in_icon):
    """A Windows bitmap without its file header, as (w, h, rgba)."""
    if len(data) < 40:
        raise Bad("short bitmap")
    size, w, h, planes, bits, comp = struct.unpack_from("<IiiHHI", data, 0)
    if size < 40 or size > len(data):
        raise Bad("bad header")
    colors = struct.unpack_from("<I", data, 32)[0]
    if comp not in (0, 3) or bits not in (1, 4, 8, 24, 32):
        raise Bad("unsupported bitmap")
    top_down = h < 0
    h = abs(h)
    if in_icon:
        h //= 2                                   # the colors, then the transparency mask
    if not (0 < w <= MAX_SIDE and 0 < h <= MAX_SIDE):
        raise Bad("bad size")
    off = size + (12 if comp == 3 and size == 40 else 0)
    palette = []
    if bits <= 8:
        n = colors or (1 << bits)
        if n > 256 or off + n * 4 > len(data):
            raise Bad("bad palette")
        palette = [data[off + i * 4:off + i * 4 + 3][::-1] + b"\xff" for i in range(n)]
        off += n * 4
    stride = ((w * bits + 31) // 32) * 4
    mask_stride = ((w + 31) // 32) * 4
    if off + stride * h > len(data):
        raise Bad("short pixels")
    mask_off = off + stride * h
    has_mask = in_icon and mask_off + mask_stride * h <= len(data)
    out = bytearray(w * h * 4)
    any_alpha = False
    for y in range(h):
        src = y if top_down else h - 1 - y
        row = data[off + src * stride:off + (src + 1) * stride]
        for x in range(w):
            if bits == 32:
                b, g, r, a = row[x * 4:x * 4 + 4]
                px = bytes((r, g, b, a))
                any_alpha = any_alpha or a != 0
            elif bits == 24:
                b, g, r = row[x * 3:x * 3 + 3]
                px = bytes((r, g, b, 255))
            else:
                per = 8 // bits
                byte = row[x // per]
                i = (byte >> (8 - bits * (x % per + 1))) & ((1 << bits) - 1)
                px = palette[i] if i < len(palette) else b"\0\0\0\xff"
            out[(y * w + x) * 4:(y * w + x) * 4 + 4] = px
    # the mask counts when the colors carry no transparency of their own
    if has_mask and not (bits == 32 and any_alpha):
        for y in range(h):
            src = y if top_down else h - 1 - y
            row = data[mask_off + src * mask_stride:mask_off + (src + 1) * mask_stride]
            for x in range(w):
                if (row[x // 8] >> (7 - x % 8)) & 1:
                    out[(y * w + x) * 4 + 3] = 0
                elif bits == 32:
                    out[(y * w + x) * 4 + 3] = 255
    return w, h, bytes(out)


def icon(data):
    """The largest picture in an .ico, as PNG bytes."""
    count = struct.unpack_from("<H", data, 4)[0]
    if not 0 < count <= 64 or len(data) < 6 + 16 * count:
        raise Bad("bad icon")
    best = None
    for i in range(count):
        w, h, _, _, _, bits, size, off = struct.unpack_from("<BBBBHHII", data, 6 + 16 * i)
        if size == 0 or off + size > len(data):
            continue
        key = ((w or 256) * (h or 256), bits)
        if best is None or key > best[0]:
            best = (key, data[off:off + size])
    if best is None:
        raise Bad("empty icon")
    part = best[1]
    if part.startswith(b"\x89PNG\r\n\x1a\n"):
        return part                               # the shrinking step reads it as any PNG
    return png(*dib(part, True))


def bitmap(data):
    if len(data) < 54:
        raise Bad("short bitmap")
    return png(*dib(data[14:], False))


def drawing(data):
    rsvg = shutil.which("rsvg-convert", path="/usr/bin:/bin")
    if not rsvg:
        raise Bad("rsvg-convert is not installed")
    run = subprocess.run([rsvg, "--width", "256", "--height", "256", "--keep-aspect-ratio",
                          "--format", "png"], input=data, capture_output=True, timeout=10, check=False)
    if run.returncode != 0 or not run.stdout.startswith(b"\x89PNG\r\n\x1a\n") or len(run.stdout) > MAX_BYTES:
        raise Bad("the drawing could not be drawn")
    return run.stdout


def is_svg(data):
    head = data[:4096].lstrip(b"\xef\xbb\xbf \t\r\n").lower()
    return head.startswith(b"<svg") or ((head.startswith(b"<?xml") or head.startswith(b"<!--")
                                         or head.startswith(b"<!doctype")) and b"<svg" in head)


def convert(data):
    if data[:4] in (b"\0\0\1\0", b"\0\0\2\0"):
        return icon(data)
    if data[:2] == b"BM":
        return bitmap(data)
    if is_svg(data):
        return drawing(data)
    raise Bad("not a format this helper reads")


def main(argv):
    if len(argv) != 3 or not argv[1].startswith("/") or not argv[2].startswith("/") or not argv[2].endswith(".png"):
        print(__doc__.strip().splitlines()[-1].strip(), file=sys.stderr)
        return 2
    try:
        fd = os.open(argv[1], os.O_RDONLY | os.O_CLOEXEC)
        with os.fdopen(fd, "rb") as fh:
            data = fh.read(MAX_BYTES + 1)
        if len(data) > MAX_BYTES:
            raise Bad("too big")
        out = convert(data)
        tmp = argv[2] + ".part"
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
        with os.fdopen(fd, "wb") as fh:
            fh.write(out)
        os.replace(tmp, argv[2])
        return 0
    except (Bad, OSError, ValueError, struct.error, subprocess.SubprocessError) as e:
        print("art: %s" % e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
