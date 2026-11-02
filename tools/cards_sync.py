"""Rebuilds cards.json from the Hina Hub card memory webhook.

The hub posts every roguelike card players meet into one Discord message per group (each weather,
Buffs, Curses). This reads those messages and writes cards.json, which the hub downloads at load.
Run by .github/workflows/cards.yml every hour; safe to run by hand (python tools/cards_sync.py).
"""
import json
import re
import sys
import time
import urllib.request
from datetime import date
from pathlib import Path

HOOK = "https://discord.com/api/webhooks/1462719657558671537/IOnwzP-AbjnSI-UzayAg6qz2UhYIiaWgJV1VvC3frdPrin-iFv331eTEmIMvibCn1MVe"
GROUPS = {
    "Starfall": "1566652767248846900", "Windy": "1566652773553152121", "Stormy": "1566652779630559284",
    "Rainy": "1566652785913630745", "Blizzard": "1566652792062480385", "Inferno": "1566652798282764309",
    "Flooded": "1566652804360044599", "Sandstorm": "1566652810521743371", "Magical": "1566652816372535342",
    "Buffs": "1566652822798340152", "Curses": "1566652829266088049",
}
WEATHERS = [g for g in GROUPS if g not in ("Buffs", "Curses")]
ROMAN = {"I": 1, "II": 2, "III": 3, "IV": 4, "V": 5}
OUT = Path(__file__).resolve().parent.parent / "cards.json"


def fetch(message_id):
    req = urllib.request.Request(f"{HOOK}/messages/{message_id}", headers={"User-Agent": "HinaHub cards sync"})
    with urllib.request.urlopen(req, timeout=20) as r:
        data = json.load(r)
    lines = []
    for embed in data.get("embeds", []):
        for line in (embed.get("description") or "").split("\n"):
            if line and line != "(none yet)" and " — " in line:
                lines.append(line)
    return lines


def base_name(title):
    """'+ Enemy Speed II' -> ('Enemy Speed', 2); '\U0001f320 Wishing Star' -> ('Wishing Star', 1)."""
    name = re.sub(r"^[^\w]+", "", title).strip()
    tier = 1
    m = re.search(r"\s+([IVX]+)$", name)
    if m and m.group(1) in ROMAN:
        tier = ROMAN[m.group(1)]
        name = name[: m.start()].strip()
    return name, tier


def list_for(group, name):
    if group in WEATHERS:
        return "SHWeatherCards"
    # The game colours these red (the cooldown / range half), the hub lists them as buffs.
    if name.startswith("Double Attack"):
        return "SHBuffs"
    return "SHBuffs" if group == "Buffs" else "SHCurses"


def main():
    previous = {}
    if OUT.exists():
        previous = json.loads(OUT.read_text(encoding="utf-8"))
    best = {}  # (list, name) -> (tier, text)
    for group, mid in GROUPS.items():
        try:
            lines = fetch(mid)
        except Exception as e:  # one unreachable message must not drop the others
            print(f"{group}: fetch failed: {e}", file=sys.stderr)
            continue
        time.sleep(0.3)
        for line in lines:
            title, effects = line.split(" — ", 1)
            if "(reward)" in title:
                continue
            name, tier = base_name(title)
            if not name:
                continue
            lst = list_for(group, name)
            text = effects
            if lst == "SHWeatherCards":
                text = re.sub(r"\+(\d+)% SummerPearls", r"+\1% pearls", text)
                text = f"{group}: {text}"
            else:
                text = re.sub(r",?\s*\+\d+% SummerPearls", "", text).strip(", ")
            key = (lst, name)
            if key not in best or tier < best[key][0]:
                best[key] = (tier, text)
    out = {"SHBuffs": [], "SHCurses": [], "SHWeatherCards": []}
    # Weather cards grouped by weather (the text starts with it), the others by name.
    def order(kv):
        (lst, name), (_, text) = kv
        return (lst, text if lst == "SHWeatherCards" else name)
    for (lst, name), (_, text) in sorted(best.items(), key=order):
        out[lst].append([name, text])
    # Default weather picks are chosen by hand (safe cards): carried over, never auto-extended.
    for k, v in previous.items():
        if k.endswith("_default"):
            out[k] = v
    same = {k: v for k, v in previous.items() if k != "updated"} == out
    out["updated"] = previous.get("updated", "") if same else date.today().isoformat()
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("unchanged" if same else "updated", {k: len(v) for k, v in out.items() if isinstance(v, list)})


if __name__ == "__main__":
    main()
