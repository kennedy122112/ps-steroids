"""Lee un PSD sin Photoshop (Windows, macOS o Linux) y devuelve JSON por stdout.

Uso: python psd_read.py <archivo.psd> [--depth 4] [--preview salida.png] [--max-size 1200]

Misma forma que `ps-cli read` (active + layers) para que las skills traten igual ambas lecturas,
más `fonts` (fuentes usadas por las capas de texto). Requiere psd-tools: pip install psd-tools
"""
import argparse
import json
import os
import sys


def out(obj, code=0):
    sys.stdout.reconfigure(encoding="utf-8")
    print(json.dumps(obj, ensure_ascii=False, indent=2))
    sys.exit(code)


try:
    from psd_tools import PSDImage
    from psd_tools.constants import Resource
except ImportError:
    out({"ok": False, "error": "Falta psd-tools. Instálalo con: pip install psd-tools"}, 1)


def val(x):
    """Desenvuelve los tipos de psd-tools (String, Integer, Float...) a valores de Python."""
    x = getattr(x, "value", x)
    if isinstance(x, bytes):
        x = x.decode("utf-8", "replace")
    if isinstance(x, str):
        x = x.strip("\x00").strip("'\"")
    return x


def text_info(layer, fonts):
    o = {"text": (layer.text or "").replace("\r", "\n")}
    try:
        fontset = [val(f["Name"]) for f in layer.resource_dict["FontSet"]]
        scale = abs(layer.transform[3]) if layer.transform else 1.0
        runs = layer.engine_dict["StyleRun"]["RunArray"]
        used, sizes, colors = [], [], []
        for r in runs:
            ss = r["StyleSheet"]["StyleSheetData"]
            if "Font" in ss:
                name = fontset[int(val(ss["Font"]))]
                if name not in used:
                    used.append(name)
            if "FontSize" in ss:
                sizes.append(round(float(val(ss["FontSize"])) * scale))
            if "FillColor" in ss:
                a, r_, g, b = [float(val(v)) for v in ss["FillColor"]["Values"]]
                colors.append("#%02x%02x%02x" % (round(r_ * 255), round(g * 255), round(b * 255)))
        used = [f for f in used if f != "AdobeInvisFont"]
        if used:
            o["font"] = used[0]
            if len(used) > 1:
                o["fonts"] = used
        if sizes:
            o["size"] = max(set(sizes), key=sizes.count)
        if colors:
            o["color"] = colors[0]
        for f in used:
            fonts.setdefault(f, 0)
            fonts[f] += 1
    except Exception as e:  # el formato del motor de texto varía entre versiones de Photoshop
        o["textWarning"] = f"No se pudo leer el estilo del texto: {e}"
    return o


def walk(group, depth, fonts):
    res = []
    for layer in reversed(list(group)):  # de arriba hacia abajo, como el panel de capas
        o = {
            "name": layer.name,
            "kind": "group" if layer.is_group() else layer.kind,
            "visible": layer.visible,
            "opacity": round(layer.opacity * 100 / 255),
            "blend": str(getattr(layer.blend_mode, "name", layer.blend_mode)).lower(),
        }
        if layer.is_group():
            if depth > 1:
                o["layers"] = walk(layer, depth - 1, fonts)
            else:
                o["children"] = len(layer)
        else:
            o["bounds"] = list(layer.bbox)
            if getattr(layer, "clipping", False):
                o["clipped"] = True
            if layer.kind == "type":
                o.update(text_info(layer, fonts))
            if layer.kind == "smartobject":
                try:
                    o["linkedFile"] = layer.smart_object.filename
                except Exception:
                    pass
        res.append(o)
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--depth", type=int, default=4)
    ap.add_argument("--preview")
    ap.add_argument("--max-size", type=int, default=1200)
    a = ap.parse_args()
    if not os.path.isfile(a.path):
        out({"ok": False, "error": f"No existe el archivo: {a.path}"}, 1)
    try:
        psd = PSDImage.open(a.path)
    except Exception as e:
        out({"ok": False, "error": f"No se pudo abrir como PSD/PSB: {e}"}, 1)

    resolution = None
    try:
        info = psd.image_resources.get_data(Resource.RESOLUTION_INFO)
        resolution = round(float(info.horizontal_res), 2)
    except Exception:
        pass
    fonts = {}
    res = {
        "ok": True,
        "offline": True,
        "active": {
            "name": os.path.basename(a.path),
            "width": psd.width,
            "height": psd.height,
            "resolution": resolution,
            "mode": str(getattr(psd.color_mode, "name", psd.color_mode)),
            "depth": psd.depth,
            "layers": len(psd),
            "path": os.path.abspath(a.path),
        },
        "layers": walk(psd, a.depth, fonts),
    }
    res["fonts"] = [{"postScriptName": f, "layers": n} for f, n in sorted(fonts.items())]
    if a.preview:
        try:
            img = psd.composite()
            img.thumbnail((a.max_size, a.max_size))
            os.makedirs(os.path.dirname(os.path.abspath(a.preview)), exist_ok=True)
            img.save(a.preview)
            res["preview"] = {"path": os.path.abspath(a.preview), "width": img.width, "height": img.height,
                              "note": "Composición aproximada: psd-tools no reproduce todos los efectos de Photoshop."}
        except Exception as e:
            res.setdefault("warnings", []).append(f"No se pudo generar la vista previa: {e}")
    out(res)


if __name__ == "__main__":
    main()
