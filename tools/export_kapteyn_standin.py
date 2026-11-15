#!/usr/bin/env python3
"""STAND-IN art for the new Kapteyn-3 (round 1 concept, to be replaced by round 2).

Splits Gemini's round 1 station into the game's four layers per module WITHOUT adding or changing a
pixel: it imports Gemini's own drawing functions from the Art Drop folder, calls them onto separate
transparent canvases (floor, walls, roof; props and hatch pieces are left out, since the game places
them from data), and crops each module's canvas. It also copies the prop and hatch PNGs untouched and
writes kapteyn_3_standin.json (every number, taken from Gemini's own tables), which
tools/import_station.gd turns into data/kapteyn_3.tres and data/station_props/*.tres.

Run from the repo root:  python3 tools/export_kapteyn_standin.py [path to the art drop's kapteyn_3 folder]
From docs/briefs/kapteyn_3.md, ticket 6a.
"""
import json
import os
import shutil
import struct
import sys

DROP = sys.argv[1] if len(sys.argv) > 1 else "/Users/emmanuelwalters/Projects/Final Orbit Art Drop/kapteyn_3"
sys.path.insert(0, DROP)
os.chdir(DROP)  # Gemini's code writes a few PNGs on import of build_props; keep them out of the repo

import build_station as bs  # noqa: E402
from art_lib import Canvas  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(REPO, "art", "kapteyn_3", "standin")
PROPS_OUT = os.path.join(REPO, "art", "station_props", "standin")

ORDER = ["concourse", "docking_hub", "med_bay", "crew_hab", "eva_prep", "ops"]
DISPLAY = {"concourse": "Concourse", "docking_hub": "Docking hub", "med_bay": "Med bay",
           "crew_hab": "Crew hab", "eva_prep": "EVA prep", "ops": "Ops"}
# Which module each bolts to: (parent module, parent port name, own port name).
BOLTS = {"docking_hub": ("concourse", "south", "north"), "med_bay": ("concourse", "west", "east"),
         "crew_hab": ("concourse", "east", "west"), "eva_prep": ("crew_hab", "north", "south"),
         "ops": ("concourse", "north", "south")}
# Port names: (module, side) -> name.
PORT_NAMES = {("concourse", "N"): "north", ("concourse", "S"): "south", ("concourse", "W"): "west",
              ("concourse", "E"): "east", ("docking_hub", "N"): "north", ("docking_hub", "W"): "dock_w",
              ("docking_hub", "E"): "dock_e", ("docking_hub", "S"): "dock_s", ("med_bay", "E"): "east",
              ("crew_hab", "W"): "west", ("crew_hab", "N"): "north", ("eva_prep", "S"): "south",
              ("eva_prep", "N"): "airlock", ("ops", "S"): "south", ("ops", "W"): "capped_west"}
FACE = {"N": (0, -1), "S": (0, 1), "W": (-1, 0), "E": (1, 0)}
# Footprints of the standing props, from the props brief's table: width x depth, drawn at the top of
# the picture, so what's left at the bottom is the front lip.
FOOTPRINT = {"gig_board": (48, 12), "service_terminal": (32, 12), "breaker_panel": (20, 6),
             "directory_sign": (24, 4), "med_bed": (42, 20), "med_cabinet": (24, 10), "bunk": (42, 20),
             "galley_counter": (48, 14), "table": (28, 18), "locker": (12, 10), "suit_rack": (20, 12),
             "bench": (32, 8), "console": (32, 14), "comms_rack": (16, 12), "crate": (16, 16),
             "crate_small": (10, 10), "cargo_cage": (40, 28), "planter": (12, 12)}
SPOT_OF_TAG = {"gig_board": "gig_board", "service": "service", "wake": "wake", "power": "power"}


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


def canvas_rects():
    """Each module's canvas on the 1200 x 1000 picture: its shell, plus the outside parts drawn on it."""
    rects = {m: list(bs.MODULES[m]["shell"]) for m in ORDER}
    # The truss, solar wings and antenna north of Ops.
    rects["ops"] = [464, 79, 736 - 464, 392 - 79]
    # The nav lights just past the med bay's and crew hab's edges.
    rects["med_bay"] = [254, 462, 432 - 254, 116]
    rects["crew_hab"] = [768, 462, 946 - 768, 116]
    return rects


def doorways(m, ports):
    """The wall openings, in canvas coordinates, as rectangles (the deck runs through them)."""
    out = []
    sx, sy, sw, sh = bs.MODULES[m]["shell"]
    if m == "eva_prep":
        # The stepped shape: main room (788, 306, 136, 116) and the airlock chamber (818, 238, 76, 76).
        out.append((840, 306, 32, 8))  # between the chamber and the room
        out.append((840, 238, 32, 8))  # the airlock's outer opening
        out.append((840, 414, 32, 8))  # the room's south door
        return out
    for p in ports:
        if p["kind"] == "capped":
            continue
        px, py = p["outer"]
        s = p["side"]
        if s == "N":
            out.append((px - 16, sy, 32, 8))
        elif s == "S":
            out.append((px - 16, sy + sh - 8, 32, 8))
        elif s == "W":
            out.append((sx, py - 16, 8, 32))
        else:
            out.append((sx + sw - 8, py - 16, 8, 32))
    return out


def crop(canvas, rect):
    x, y, w, h = rect
    out = Canvas(w, h)
    for py in range(h):
        for px in range(w):
            out.put_px_raw(px, py, canvas.get_px(x + px, y + py))
    return out


class Blank:
    """Stands in for the door leaf and lamp pictures, so Gemini's eva_prep wall function draws none of
    them: the game's own doors and lamps are data."""


def main():
    props, hatch_pieces = bs.build_all_props()
    rects = canvas_rects()
    floor_c = Canvas(1200, 1000)
    walls_c = Canvas(1200, 1000)
    roof_c = Canvas(1200, 1000)

    # Floor: the deck of every module, the doorways, and Gemini's floor markings.
    for m in ORDER:
        mod = bs.MODULES[m]
        bs.draw_deck_floor(floor_c, *mod["floor"])
        if "airlock_floor" in mod:
            bs.draw_deck_floor(floor_c, *mod["airlock_floor"])
        for rect in doorways(m, mod["ports"]):
            bs.draw_deck_floor(floor_c, *rect)
    bs.draw_concourse_floor_markings(floor_c)
    bs.draw_med_bay_floor_markings(floor_c)
    bs.draw_docking_hub_floor_markings(floor_c)

    # Walls, by Gemini's own functions. For eva_prep its door leaves and lamps are left out (blank).
    empty = Canvas(1, 1)
    blank_pieces = {"hatch_door_left": empty, "hatch_door_right": empty,
                    "airlock_lamp_red": empty, "airlock_lamp_green": empty}
    for m in ORDER:
        mod = bs.MODULES[m]
        if m == "eva_prep":
            bs.draw_eva_prep_walls(walls_c, props, blank_pieces)
        else:
            sx, sy, sw, sh = mod["shell"]
            bs.draw_room_walls(walls_c, sx, sy, sw, sh, mod["ports"], has_north_lip=True)
            if m == "ops":
                walls_c.framed_rect(532, 257, 136, 6, bs.GLD, bs.O)
                walls_c.fill_rect(534, 258, 132, 4, bs.GLL)
                for mx in range(552, 660, 20):
                    walls_c.vline(mx, 258, 4, bs.GLD)

    # Roof, by Gemini's functions: the truss and wings, each module's roof, and the nav lights.
    bs.draw_north_truss_and_solar_wings(roof_c)
    for m in ORDER:
        bs.draw_module_roof(roof_c, m, bs.MODULES[m])
    roof_c.framed_rect(254, 517, 6, 6, bs.O, bs.O)
    roof_c.fill_rect(255, 518, 4, 4, bs.RED)
    roof_c.framed_rect(940, 517, 6, 6, bs.O, bs.O)
    roof_c.fill_rect(941, 518, 4, 4, bs.GW_GREEN)

    os.makedirs(ART, exist_ok=True)
    os.makedirs(PROPS_OUT, exist_ok=True)
    for m in ORDER:
        crop(floor_c, rects[m]).save_png(os.path.join(ART, m + "_floor.png"))
        crop(walls_c, rects[m]).save_png(os.path.join(ART, m + "_walls.png"))
        crop(roof_c, rects[m]).save_png(os.path.join(ART, m + "_roof.png"))

    # The props and hatch pieces, copied untouched.
    sizes = {}
    for name in sorted(os.listdir(os.path.join(DROP, "props"))):
        if name.endswith(".png"):
            shutil.copyfile(os.path.join(DROP, "props", name), os.path.join(PROPS_OUT, name))
            sizes[name[:-4]] = png_size(os.path.join(DROP, "props", name))

    def local(m, x, y):
        return [x - rects[m][0], y - rects[m][1]]

    modules = []
    for m in ORDER:
        mod = bs.MODULES[m]
        ox, oy = rects[m][0], rects[m][1]
        sx, sy, sw, sh = mod["shell"]
        ports = []
        for p in mod["ports"]:
            px, py = p["outer"]
            # Gemini's south and east ports are one pixel past the shell; the game's are on its last pixel.
            if p["side"] == "S":
                py -= 1
            elif p["side"] == "E":
                px -= 1
            kind = p["kind"]
            ports.append({"name": PORT_NAMES[(m, p["side"])], "kind": kind,
                          "point": local(m, px, py), "face": list(FACE[p["side"]])})
        floors = [[mod["floor"][0] - ox, mod["floor"][1] - oy, mod["floor"][2], mod["floor"][3]]]
        if "airlock_floor" in mod:
            a = mod["airlock_floor"]
            floors.append([a[0] - ox, a[1] - oy, a[2], a[3]])
        for d in doorways(m, mod["ports"]):
            floors.append([d[0] - ox, d[1] - oy, d[2], d[3]])
        props_here = []
        for item in bs.PROP_PLACEMENTS[m]:
            assert item["layer"] != "standing" or item["rot"] == 0
            props_here.append({"id": item["id"], "layer": item["layer"], "position": local(m, item["x"], item["y"]),
                               "turns": (item["rot"] // 90) % 4, "spot": SPOT_OF_TAG.get(item["tag"], "")})
        fixtures = [{"point": local(m, f["pos"][0], f["pos"][1]), "reach_m": f["reach_m"], "tint": f["tint"],
                     "circuit": f["circuit"]} for f in bs.LIGHT_FIXTURES[m]]
        windows = [[w["rect"][0] - ox, w["rect"][1] - oy, w["rect"][2], w["rect"][3]]
                   for w in bs.ROOF_WINDOWS if w["module"] == m]
        outside = []
        for e in bs.EXTERIOR_LIGHTS:
            owner = "docking_hub" if e["port"].startswith("docking_hub") else None
            x, y = e["pos"]
            if owner is None:
                for cand in ORDER:
                    rx, ry, rw, rh = rects[cand]
                    if rx <= x < rx + rw and ry <= y < ry + rh:
                        owner = cand
                        break
            if owner != m:
                continue
            port = ""
            if e["port"] != "none":
                port = PORT_NAMES[("docking_hub", e["port"].split(":")[1])]
            outside.append({"point": local(m, x, y), "kind": e["kind"], "port": port})
        doors = []
        if m == "eva_prep":
            # The airlock's inner door: its leaves meet at (856, 310) and it's walked through up and down.
            doors.append({"name": "airlock", "point": local(m, 856, 310), "face": [0, -1]})
        entry = {"id": m, "display_name": DISPLAY[m], "canvas": [rects[m][2], rects[m][3]], "ports": ports,
                 "floors": floors, "props": props_here, "fixtures": fixtures, "windows": windows,
                 "outside_lights": outside, "doors": doors}
        if m in BOLTS:
            entry["bolts_to_module"] = ORDER.index(BOLTS[m][0])
            entry["bolts_to_port"] = BOLTS[m][1]
            entry["own_port"] = BOLTS[m][2]
        modules.append(entry)

    prop_info = {}
    for pid, (w, h) in sizes.items():
        info = {"size": [w, h]}
        if pid in FOOTPRINT:
            fw, fh = FOOTPRINT[pid]
            info["layer"] = "standing"
            info["footprint"] = [0, 0, fw, fh]
            info["lip"] = h - fh
        prop_info[pid] = info
    for pid in ("scanner_arch", "pipe_run", "pipe_bend", "cable_tray", "light_panel", "beam"):
        prop_info[pid]["layer"] = "overhead"
    for pid in ("cable_run", "hazard_stripe", "grate", "lane_arrow"):
        prop_info[pid]["layer"] = "floor"
    out = {"standin": True, "modules": modules, "props": prop_info,
           "legacy_ports": ["dock_s", "dock_e", "dock_w", "dock_s"], "home_port": "dock_s"}
    with open(os.path.join(ART, "kapteyn_3_standin.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", len(ORDER) * 3, "layer PNGs,", len(sizes), "prop PNGs, and the JSON")


main()
