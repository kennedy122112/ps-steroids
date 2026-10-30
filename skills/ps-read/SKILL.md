---
name: ps-read
description: Lee un documento de Adobe Photoshop (PSD o imagen) para explicarlo, auditarlo o documentarlo - tamaño, resolución, capas y grupos, textos, fuentes usadas y faltantes, capas ocultas. Funciona con Photoshop abierto o sin Photoshop (Python + psd-tools). Úsala cuando el usuario diga "qué tiene este PSD", "revisa este diseño", "qué fuentes usa", "documenta esta plantilla", "audita este archivo de Photoshop", "lista los textos".
---

# Leer en Photoshop

**ps-cli** está definido en `ps-setup`.

## Con Photoshop o sin él
- **Photoshop abierto** (lectura exacta, también de .jpg/.png/.tif): `ps-cli open -Path <archivo>` y
  `ps-cli read [-Depth 6]`; vista previa con `ps-cli preview -Path <...>.png`.
- **Sin Photoshop** (solo .psd/.psb; en cualquier PC o Mac, más rápido para auditar varios archivos):
  `ps-cli inspect -Path <archivo.psd> [-Depth 6] [-Preview <...>.png]`. Si falla por psd-tools, ver `ps-setup` paso 4.
  La vista previa es aproximada (no reproduce todos los efectos); dilo si la usas para opinar del aspecto.

Si Photoshop está cerrado y el archivo es PSD, usa `inspect` sin preguntar; abre Photoshop solo si
hace falta algo que `inspect` no da.

## Qué devuelve
Documento (`active`: medidas, resolución, modo, número de capas) y árbol de capas de arriba hacia abajo:
`name`, `kind` (group, pixel/normal, type/text, smartobject, shape, solidfill, gradientfill, adjustment…),
`visible`, `opacity`, `blend`, `bounds` [izq, arriba, der, abajo], `clipped`; en textos, `text`,
`font`, `size`, `color`. `inspect` añade `fonts` (fuentes usadas y en cuántas capas).
Mira también la vista previa: la lectura dice qué hay; la imagen, cómo se ve.

## Qué reportar
- Ficha: medidas, resolución, modo de color, número de capas.
- Estructura: grupos principales y para qué sirve cada uno.
- Textos: lista de capas de texto con su contenido (útil para plantillas).
- Fuentes: cuáles usa y cuáles no están instaladas (con Photoshop: `ps-cli fonts -Query <nombre>`).
- Problemas: capas ocultas o vacías, nombres genéricos ("Capa 12"), textos fuera del lienzo
  (`bounds` fuera de 0..ancho/alto), resolución inadecuada para el uso (72 ppp para imprimir, etc.),
  texto menor de 24 px en piezas para redes, contraste bajo visible en la vista previa.

Si el usuario pide un documento con el resultado, escríbelo en Markdown junto al PSD (`<nombre>-ficha.md`).

No le muestres comandos ni JSON al usuario salvo que lo pida.
