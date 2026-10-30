---
name: ps-design
description: Diseña piezas gráficas reales y editables por capas en Adobe Photoshop a partir de una idea contada por chat o de imágenes que pasa el usuario - posts y stories para redes, banners, flyers, portadas, miniaturas, invitaciones, piezas institucionales. Úsala cuando el usuario diga "diseña en Photoshop", "hazme un post / banner / flyer / portada", "arma una pieza con esta foto", "crea una imagen para redes", "diseña algo con esta idea".
---

# Diseñar en Photoshop

Requiere conexión activa (`ps-connect`). **ps-cli** está definido en `ps-setup`.

## Flujo
1. **Brief.** Saca del mensaje: formato y medidas (tabla abajo), objetivo, texto exacto, marca
   (colores, fuentes, logo), y qué imágenes hay. Si falta algo que cambia el diseño (formato o texto
   principal), pregúntalo en una sola pregunta; lo demás decídelo tú y dilo.
2. **Mira las imágenes** del usuario antes de diseñar (léelas): dónde está el sujeto, colores
   dominantes, zonas libres para texto. Elige la paleta a partir de ellas o de la marca.
3. **Fuentes.** `ps-cli fonts -Query <familia>` para confirmar el nombre PostScript de cada fuente.
   Si no está instalada, usa una que sí esté y díselo al usuario.
4. **Spec.** Escribe el spec JSON (UTF-8) y ejecuta `ps-cli build -Spec <archivo.json>`.
5. **Revisa el resultado**, siempre: `ps-cli preview -Path <carpeta>/NN-nombre-preview.png` y lee el PNG.
   Busca texto cortado o desbordado, poco contraste, elementos pegados al borde, foto mal recortada.
   Corrige el spec y vuelve a hacer `build` (crea un documento nuevo; cierra o ignora el anterior).
   Máximo 3 vueltas; luego muéstraselo al usuario.
6. **Entrega.** `ps-cli export -Path <carpeta>/NN-nombre.psd` (editable) y `.png` o `.jpg` (para publicar).
   Cuéntale qué hiciste, qué decidiste tú y qué puede pedir cambiar.

## Carpeta del trabajo
Pregunta dónde guardar si no lo dijo; nunca solo en carpetas temporales.
```
<carpeta>/entrada/            copias de las imágenes del usuario
<carpeta>/NN-nombre.json      spec (la fuente del diseño: rehacerlo es volver a correr build)
<carpeta>/NN-nombre.psd       editable
<carpeta>/NN-nombre.png|jpg   final
```
Las rutas `src` relativas se resuelven contra la carpeta del spec.

## Spec JSON
Las capas van **de abajo hacia arriba** (la primera queda al fondo). Medidas en píxeles.
```json
{
  "document": { "name": "Post evento", "width": 1080, "height": 1080, "resolution": 72, "background": "#0f1b3d" },
  "layers": [
    { "type": "gradient", "name": "Brillo", "colors": ["#1f4fd1", "#0f1b3d"], "angle": 135, "style": "radial", "opacity": 70 },
    { "type": "ellipse", "name": "Marco", "x": 560, "y": 300, "w": 440, "h": 440, "color": "#ffffff" },
    { "type": "image", "name": "Foto", "src": "entrada/foto.jpg", "x": 560, "y": 300, "w": 440, "h": 440, "fit": "cover", "clip": true },
    { "type": "group", "name": "Textos", "layers": [
      { "type": "text", "name": "Título", "text": "IA aplicada\nal trabajo", "x": 80, "y": 190, "w": 480, "h": 300,
        "font": "Montserrat-ExtraBold", "size": 76, "leading": 84, "color": "#ffffff" },
      { "type": "rect", "name": "Botón", "x": 80, "y": 840, "w": 360, "h": 96, "radius": 48, "color": "#ffb703", "shadow": true }
    ] }
  ]
}
```
Ejemplo completo: `~/.ps-steroids/examples/post-evento/spec.json`.

| `type` | Campos | Notas |
|---|---|---|
| `fill` | `color`, opcional `x y w h` | Capa de relleno de color; con caja queda enmascarada a ella |
| `gradient` | `colors` o `stops` [`{color, pos 0-1, opacity}`], `angle`, `style` linear/radial, opcional caja | Capa de relleno de degradado |
| `rect` | `x y w h color`, `radius` | Forma vectorial editable |
| `ellipse` | `x y w h color` | Forma vectorial; base ideal para fotos circulares con `clip` |
| `text` | `text` (`\n` = salto), `x y w h`, `font` (PostScript), `size` px, `color`, `align` left/center/right/justify, `leading` px, `tracking`, `caps` | Con `w` es texto de párrafo y `x,y` es la esquina superior izquierda de la caja. Sin `w`, `y` es la línea base |
| `image` | `src`, `x y w h`, `fit` cover/contain/stretch, `mask` false, `removeBackground` true, o `x y scale` | Objeto inteligente (no pierde calidad). `cover` recorta con máscara a la caja |
| `group` | `layers` | Carpeta de capas |

Comunes a todas: `name` (ponlo siempre, en el idioma del usuario), `opacity` 0-100, `blend`
(multiply, screen, overlay, soft light…), `rotate` grados, `visible`, `clip` (máscara de recorte con
la capa de abajo), `shadow` (`true` o `{color, opacity, angle, distance, size, spread}`),
`stroke` (`{size, color, position outside/inside/center, opacity}`),
`adjust` (`{brightness, contrast, hue, saturation, lightness}`, crea capas de ajuste recortadas a esa capa).

`"target": "active"` en vez de `document` añade las capas al documento abierto (para trabajar sobre una
foto del usuario). `"resolution": 300` para impresión: el diseño se arma igual en píxeles.

## Formatos frecuentes
| Pieza | Medidas (px) |
|---|---|
| Post Instagram / Facebook cuadrado | 1080 × 1080 |
| Post vertical Instagram | 1080 × 1350 |
| Story / Reel / TikTok | 1080 × 1920 (deja libres 250 px arriba y abajo) |
| Portada YouTube / miniatura | 1280 × 720 |
| Banner LinkedIn | 1584 × 396 |
| Post LinkedIn / X | 1200 × 627 |
| Flyer A4 impresión | 2480 × 3508 a 300 ppp |
| Diapositiva 16:9 | 1920 × 1080 |

## Criterios de diseño
- **Una sola idea por pieza** y jerarquía clara: título (lo que se lee a 1 m) > dato clave > detalle > llamada a la acción.
- **Márgenes de seguridad** de al menos 6 % del lado menor (≈ 64 px en 1080). Nada importante pegado al borde.
- **Máximo 2 familias tipográficas**; el título entre 6 % y 10 % del ancho del lienzo; el texto menor nunca por debajo de 24 px en redes.
- **Contraste**: texto sobre foto solo con una capa de oscurecimiento (`fill` negro al 35-55 % o un
  degradado) o sobre una forma sólida. Comprueba en el preview que se lee.
- **Paleta**: 1 color dominante, 1 de acento para la llamada a la acción, neutros. Sácala de la marca o de la foto.
- **Fotos**: `cover` para fondos y marcos; `removeBackground` para recortar a la persona/producto y ponerla sobre color.
- Alinea a una rejilla: mismas `x` para los bloques de texto, espacios repetidos (múltiplos de 8).
- Texto en el idioma del usuario y con ortografía revisada; no inventes datos (fechas, precios, contactos):
  si faltan, pon un marcador visible como `[fecha]` y avísale.
- Piezas institucionales (MEF, SIAF-RP u otra marca con manual): usa sus colores y fuentes del manual;
  si el usuario tiene la skill de esa marca, léela antes.

## Lo que el agente no hace
No genera fotografías ni ilustraciones nuevas: compone con las imágenes que da el usuario, formas,
degradados y tipografía. Si la idea necesita una imagen que no existe, pídela (o sugiere un banco
de imágenes libre) o resuélvela con un diseño tipográfico/geométrico.

No le muestres comandos ni JSON al usuario salvo que lo pida.
