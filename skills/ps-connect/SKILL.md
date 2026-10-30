---
name: ps-connect
description: Conecta el agente con Adobe Photoshop abierto en esta PC (API COM, sin MCP) y fija el documento de trabajo. Úsala cuando el usuario diga "conecta con Photoshop", "trabaja en mi Photoshop", "abre esta imagen en Photoshop", cuando un comando ps-cli falle por conexión, o antes de cualquier tarea de diseño o edición en Photoshop.
---

# Conectar con Photoshop

Si es la primera vez o ps-cli no existe, sigue antes `ps-setup` (allí se define **ps-cli**).

## 1. Estado
`ps-cli status` → `running: true`. Si no, ver `ps-setup`.

## 2. Documento de trabajo
- Documento nuevo (diseñar desde cero): lo crea `build`; no hace falta nada más.
- Archivo del usuario: `ps-cli open -Path "C:\ruta\imagen.jpg"` (también .psd, .png, .tif, .webp).
- Lo que ya está abierto: ps-cli siempre trabaja sobre el **documento activo**. Si hay varios abiertos,
  dile al usuario cuál vas a tocar (`status` → `active.name`) antes de cambiar nada.

## 3. Imágenes que manda el usuario
Una imagen pegada en el chat la puedes **ver**, pero Photoshop necesita un **archivo en disco**.
Pide la ruta o que la guarde en la carpeta del trabajo (`entrada/`). Nunca trabajes sobre el original:
cópialo a `entrada/` y edita la copia.

## 4. Reglas de trabajo
- Cada `build` queda como **un solo paso del historial**: el usuario lo deshace con Ctrl+Z.
- `build` con `"target": "active"` **reemplaza las capas con el mismo nombre** del nivel donde escribe.
  En un documento que no creaste tú, lee primero (`ps-cli read`) y avisa qué capas vas a reemplazar.
- No cierres documentos del usuario sin guardar ni sobrescribas sus archivos: exporta a archivos nuevos.
- Nada de borrar capas o archivos del usuario sin su confirmación explícita.

No le muestres comandos al usuario. Ejecútalos tú e informa en lenguaje sencillo.
