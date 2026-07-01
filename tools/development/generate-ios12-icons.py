#!/usr/bin/env python3
"""Generate iOS 12-compatible template imagesets from SF Symbol .symbolset assets.

iOS 12 cannot load .symbolset assets (UIImage(named:) returns nil), so every
icon is blank. This extracts the Regular glyph from each symbolset's SF Symbols
export SVG, rasterizes it to @1x/@2x/@3x template PNGs via qlmanage, writes a
sibling .imageset (same asset name), and removes the .symbolset. The resulting
imagesets load on iOS 12 and iOS 13+ alike, so no code changes are needed.

Re-run this after adding/updating symbolsets. Requires macOS (qlmanage).
"""
import os, re, glob, json, shutil, subprocess, tempfile

HERE = os.path.dirname(__file__)
ROOT = os.path.join(HERE, "..", "..",
                    "browser/Reynard/Resources/Assets.xcassets")
SVG2PNG = None  # path to the compiled Swift renderer, set in main()
K = 0.8  # px per SVG unit at @3x (~24pt nominal for a ~90-unit glyph)
WEIGHT_RE = r'<g id="(?:Ultralight|Thin|Light|Regular|Medium|Semibold|Bold|Heavy|Black)-[SML]"'
# Preference order for which weight/scale glyph to extract.
PREF = ["Regular-M", "Regular-S", "Regular-L", "Medium-M", "Medium-S",
        "Semibold-M", "Black-S", "Black-M"]
PATH_RE = re.compile(r'<path[^>]*\bd="([^"]+)"')
NUM_RE = re.compile(r'-?\d+\.?\d*(?:e-?\d+)?')


def extract_paths(svg):
    for weight in PREF:
        i = svg.find(f'<g id="{weight}"')
        if i < 0:
            continue
        nxt = re.search(WEIGHT_RE, svg[i + 5:])
        block = svg[i:(i + 5 + nxt.start()) if nxt else svg.find('</svg>')]
        paths = PATH_RE.findall(block)
        if paths:
            return paths
    return []


def render(svg_text, out_png, size):
    # Render via the Swift/NSImage helper, which preserves transparency so the
    # PNG works as a tintable template image (qlmanage flattens onto opaque
    # white, producing solid tinted squares).
    with tempfile.TemporaryDirectory() as td:
        src = os.path.join(td, "g.svg")
        open(src, "w").write(svg_text)
        subprocess.run([SVG2PNG, src, out_png, str(size)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return os.path.exists(out_png)


def build_renderer():
    global SVG2PNG
    out = os.path.join(tempfile.gettempdir(), "reynard_svg2png")
    subprocess.run(["xcrun", "swiftc", "-O",
                    os.path.join(HERE, "svg2png.swift"), "-o", out], check=True)
    SVG2PNG = out


def main():
    build_renderer()
    sets = sorted(glob.glob(f"{ROOT}/**/*.symbolset", recursive=True))
    done = fail = 0
    for d in sets:
        name = os.path.basename(d)[:-len(".symbolset")]
        svgf = glob.glob(f"{d}/*.svg")
        paths = extract_paths(open(svgf[0]).read()) if svgf else []
        if not paths:
            print("FAIL (no glyph):", name); fail += 1; continue
        ax, ay = [], []
        for dd in paths:
            nums = [float(n) for n in NUM_RE.findall(dd)]
            ax += nums[0::2]; ay += nums[1::2]
        minx, maxx, miny, maxy = min(ax), max(ax), min(ay), max(ay)
        pad = max(maxx - minx, maxy - miny) * 0.08
        minx -= pad; miny -= pad; maxx += pad; maxy += pad
        w, h = maxx - minx, maxy - miny
        body = "".join(f'<path d="{p}" fill="black"/>' for p in paths)
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" '
               f'viewBox="{minx:.2f} {miny:.2f} {w:.2f} {h:.2f}">{body}</svg>')
        base = max(w, h) * K
        imgset = os.path.join(os.path.dirname(d), name + ".imageset")
        os.makedirs(imgset, exist_ok=True)
        ok = True
        for scale, factor in (("1x", 1 / 3), ("2x", 2 / 3), ("3x", 1.0)):
            fn = "icon.png" if scale == "1x" else f"icon@{scale}.png"
            ok &= render(svg, os.path.join(imgset, fn), max(8, round(base * factor)))
        if not ok:
            print("FAIL (render):", name); fail += 1; shutil.rmtree(imgset); continue
        json.dump({
            "images": [
                {"idiom": "universal", "filename": "icon.png", "scale": "1x"},
                {"idiom": "universal", "filename": "icon@2x.png", "scale": "2x"},
                {"idiom": "universal", "filename": "icon@3x.png", "scale": "3x"},
            ],
            "info": {"author": "xcode", "version": 1},
            "properties": {"template-rendering-intent": "template"},
        }, open(os.path.join(imgset, "Contents.json"), "w"), indent=2)
        shutil.rmtree(d)
        done += 1
    print(f"done: {done}, failed: {fail}, total: {len(sets)}")


if __name__ == "__main__":
    main()
