#!/usr/bin/env python3
import argparse, json, sys
from pathlib import Path
from PIL import Image

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--extracted", required=True)
    ap.add_argument("--man", required=True)
    ap.add_argument("--ai", required=True)
    ap.add_argument("--names", default="")
    args = ap.parse_args()

    man = Path(args.man)
    if not man.exists():
        man = Path("extracted/manifest.json")
    with open(man) as f:
        d = json.load(f)
    if isinstance(d, list):
        items = d
    else:
        items = [{"id": int(k), **v} for k,v in d.items()]

    names = {}
    if args.names:
        npath = Path(args.names)
        if npath.exists():
            with open(npath) as f:
                j = json.load(f)
                if isinstance(j, dict):
                    names = {str(k): str(v) for k,v in j.items()}
                else:
                    names = {str(x["id"]): x.get("name", "") for x in j}

    SKIP = ("englogo", "pdlogo", "sdlogo", "logo", "hud_knob", "letters", "sign_trn", "rocksign")
    have = set(p.stem for p in Path(args.ai).glob("*.png"))
    missing = 0; bad = []; skip_count = 0
    for it in items:
        tid = str(it["id"])
        name = names.get(tid, it.get("name", tid))
        w = int(it.get("width", it.get("w",0))); h = int(it.get("height", it.get("h",0)))
        if w==0: continue
        expw = w*4; exph = h*4
        if any(k in name.lower() for k in SKIP):
            skip_count += 1; continue
        if tid not in have:
            missing += 1; continue
        try:
            im = Image.open(Path(args.ai)/f"{tid}.png")
            if im.size != (expw, exph):
                bad.append(f"{tid}: {im.size}!= {(expw,exph)}")
        except Exception as e:
            bad.append(f"{tid}: {e}")
    print("items", len(items), "have", len(have), "skips", skip_count, "missing", missing, "bad", len(bad))
    if bad:
        for b in bad[:20]: print(b)
        sys.exit(1)
    print("OK")
if __name__=="__main__":
    main()
