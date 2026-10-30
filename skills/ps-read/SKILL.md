---
name: ps-read
description: Lee un documento de Adobe Photoshop (PSD o imagen abierta) para explicarlo, auditarlo o documentarlo - tamaño, resolución, capas y grupos, textos, fuentes usadas y faltantes, capas ocultas. Úsala cuando el usuario diga "qué tiene este PSD", "revisa este diseño", "qué fuentes usa", "documenta esta plantilla", "audita este archivo de Photoshop", "lista los textos".
---

# Leer en Photoshop

Requiere conexión activa (`ps-connect`). **ps-cli** está definido en `ps-setup`.

## Flujo
1. Abre el archivo si no está abierto: `ps-cli open -Path <archivo.psd>`.
2. `ps-cli read [-Depth 6]` → documento (`active`) y árbol de capas: `name`, `kind` (group, normal,
   text, solidfill, gradientfill, smartobject, …), `visible`, `opacity`, `blend`, `bounds`
   [izq, arriba, der, abajo], `clipped`; en textos, `text`, `font`, `size`, `color`.
3. `ps-cli preview -Path <...>.png` y míralo: la lectura dice qué hay; la imagen, cómo se ve.

## Qué reportar
- Ficha: medidas, resolución, modo de color, número de capas, si está guardado.
- Estructura: grupos principales y para qué sirve cada uno.
- Textos: lista de capas de texto con su contenido (útil para plantillas).
- Fuentes: cuáles usa y cuáles no están instaladas (`ps-cli fonts -Query <nombre>`).
- Problemas: capas ocultas o vacías, nombres genéricos ("Capa 12"), textos fuera del lienzo
  (`bounds` fuera de 0..ancho/alto), resolución inadecuada para el uso (72 ppp para imprimir, etc.),
  texto menor de 24 px en piezas para redes, contraste bajo visible en el preview.

Si el usuario pide un documento con el resultado, escríbelo en Markdown junto al PSD (`<nombre>-ficha.md`).

No le muestres comandos ni JSON al usuario salvo que lo pida.
