"""Genera el ícono de la app (adaptable de Android + versiones clásicas) a partir del logo de UCSA Prime
(assets/logo.png, hexágono blanco) sobre un degradado del azul de la app.

Uso (desde la raíz del proyecto):  python tool/generar_icono.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
RES = RAIZ / "android/app/src/main/res"
AZUL_CLARO = (70, 102, 255)   # blueAlt  #4666FF
AZUL = (54, 76, 228)          # blueUcsa #364CE4
AZUL_OSCURO = (18, 30, 110)

# 1) El logo de UCSA Prime (hexágono blanco con sus sombreados semitransparentes)
logo = Image.open(RAIZ / "assets/logo.png").convert("RGBA")
logo = logo.crop(logo.getbbox())


def degradado(lado):
    """Degradado diagonal del azul claro (arriba a la izquierda) al azul oscuro."""
    im = Image.new("RGB", (lado, lado))
    d = im.load()
    for y in range(lado):
        for x in range(lado):
            t = (x + y) / (2 * (lado - 1))
            c = [int(AZUL_CLARO[i] + (AZUL_OSCURO[i] - AZUL_CLARO[i]) * t) for i in range(3)]
            d[x, y] = tuple(c)
    return im


def r_blanca(lado, fraccion):
    """Lienzo transparente con el logo centrado, de alto = fraccion · lado."""
    alto = int(lado * fraccion)
    ancho = int(logo.size[0] * alto / logo.size[1])
    capa = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    capa.alpha_composite(logo.resize((ancho, alto), Image.LANCZOS), ((lado - ancho) // 2, (lado - alto) // 2))
    return capa


# 2) Ícono adaptable (Android 8+): fondo + primer plano de 108 dp; zona segura = 66 dp centrales
for carpeta, esc in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
    lado = int(108 * esc)
    (RES / f"mipmap-{carpeta}").mkdir(exist_ok=True)
    degradado(lado).save(RES / f"mipmap-{carpeta}/ic_launcher_background.png")
    r_blanca(lado, 0.56).save(RES / f"mipmap-{carpeta}/ic_launcher_foreground.png")
    # 3) Versión clásica (Android < 8): cuadrado redondeado de 48 dp
    lado_c = int(48 * esc)
    base = degradado(lado_c).convert("RGBA")
    base.alpha_composite(r_blanca(lado_c, 0.66))
    redondeo = Image.new("L", (lado_c, lado_c), 0)
    ImageDraw.Draw(redondeo).rounded_rectangle((0, 0, lado_c - 1, lado_c - 1), radius=int(lado_c * 0.22), fill=255)
    final = Image.new("RGBA", (lado_c, lado_c), (0, 0, 0, 0))
    final.paste(base, (0, 0), redondeo)
    final.save(RES / f"mipmap-{carpeta}/ic_launcher.png")

(RES / "mipmap-anydpi-v26").mkdir(exist_ok=True)
(RES / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
    '    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />\n'
    '</adaptive-icon>\n', encoding="utf-8")

# Vista previa (círculo, como lo recorta el lanzador) para revisarlo
lado = 432
vista = degradado(lado).convert("RGBA")
vista.alpha_composite(r_blanca(lado, 0.56))
circ = Image.new("L", (lado, lado), 0)
ImageDraw.Draw(circ).ellipse((0, 0, lado - 1, lado - 1), fill=255)
out = Image.new("RGBA", (lado, lado), (255, 255, 255, 0))
out.paste(vista, (0, 0), circ)
out.save(RAIZ / "build/vista_icono.png")
print("ok")
