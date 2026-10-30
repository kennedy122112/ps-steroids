---
name: ps-edit
description: Edita imágenes y PSD existentes en Adobe Photoshop - recortar, redimensionar, quitar el fondo, ajustar color y luz, cambiar textos de una plantilla, poner logo o marca de agua, y sacar la misma pieza en varios tamaños. Úsala cuando el usuario diga "edita esta foto", "quítale el fondo", "recórtala", "cambia el texto de la plantilla", "ponle mi logo", "hazla más clara", "sácala en formato story", "redimensiona estas imágenes".
---

# Editar en Photoshop

Requiere conexión activa (`ps-connect`). **ps-cli** está definido en `ps-setup`.

## Flujo
1. Copia el archivo del usuario a `<carpeta>/entrada/` y ábrelo: `ps-cli open -Path <copia>`.
2. `ps-cli read` para ver tamaño, resolución y capas (en un PSD: nombres de las capas de texto).
3. Haz el cambio: con `build` (`"target": "active"`) si es añadir capas, o con un `.jsx` (abajo).
4. `ps-cli preview -Path <...>-preview.png`, léelo y compáralo con el original.
5. Exporta a un archivo **nuevo** (`ps-cli export -Path <carpeta>/nombre-editado.png|jpg|psd`).

## Añadir sobre la imagen (build con target active)
```json
{ "target": "active", "layers": [
  { "type": "gradient", "name": "Oscurecer", "stops": [{"color":"#000000","pos":0,"opacity":0},{"color":"#000000","pos":1,"opacity":70}], "angle": 90 },
  { "type": "image", "name": "Logo", "src": "entrada/logo.png", "x": 900, "y": 960, "w": 140, "h": 80, "fit": "contain", "opacity": 85 },
  { "type": "text", "name": "Marca de agua", "text": "© Mi marca", "x": 40, "y": 1030, "w": 400, "h": 40, "font": "ArialMT", "size": 24, "color": "#ffffff", "opacity": 60 }
] }
```

## Operaciones con jsx
`ps-cli jsx -Script <archivo.jsx>` ejecuta ExtendScript con los helpers de ps-cli (`__main`, `__b`,
`__color`, `__docInfo`, `cTID`, `sTID`, `W` para avisos). Las medidas son píxeles. El script debe terminar en
`__main(function(){ ...; return { ... }; });`. Guarda cada `.jsx` junto al trabajo, no en temporales.

```js
// Recortar a una caja y redimensionar
__main(function(){ var d = app.activeDocument;
  d.crop([100, 50, 1180, 1130]);                       // izquierda, arriba, derecha, abajo
  d.resizeImage(1080, 1080, null, ResampleMethod.BICUBICAUTOMATIC);
  return { document: __docInfo(d) }; });

// Lienzo de otro formato sin deformar (añade bandas del color de fondo)
__main(function(){ var d = app.activeDocument; app.backgroundColor = __color('#ffffff');
  d.resizeCanvas(1080, 1920, AnchorPosition.MIDDLECENTER); return { document: __docInfo(d) }; });

// Quitar el fondo a la capa activa (Photoshop 2021+) — crea máscara
__main(function(){ executeAction(sTID('removeBackground'), new ActionDescriptor(), DialogModes.NO); return {}; });

// Seleccionar el sujeto (para máscaras propias)
__main(function(){ var d = new ActionDescriptor(); d.putBoolean(sTID('sampleAllLayers'), false);
  executeAction(sTID('autoCutout'), d, DialogModes.NO); return {}; });

// Cambiar textos de una plantilla por nombre de capa (busca también dentro de grupos)
var CAMBIOS = { 'Título': 'Nuevo título', 'Fecha': '15 de noviembre' };
function walk(c){ for (var i = 0; i < c.length; i++) { var l = c[i];
  if (l.typename === 'LayerSet') walk(l.layers);
  else if (l.kind === LayerKind.TEXT && CAMBIOS.hasOwnProperty(l.name)) { l.textItem.contents = CAMBIOS[l.name]; delete CAMBIOS[l.name]; } } }
__main(function(){ walk(app.activeDocument.layers); for (var k in CAMBIOS) W.push('No encontré la capa: ' + k); return {}; });

// Reemplazar el contenido de un objeto inteligente (mockups) — capa activa
var NUEVO = 'C:/ruta/imagen.png';   // en macOS: '/Users/ana/ruta/imagen.png'
__main(function(){ var d = new ActionDescriptor(); d.putPath(cTID('null'), new File(NUEVO));
  executeAction(sTID('placedLayerReplaceContents'), d, DialogModes.NO); return {}; });

// Ajustes rápidos en una capa de píxeles (destructivo: hazlo sobre una copia)
__main(function(){ var l = app.activeDocument.activeLayer;
  l.adjustBrightnessContrast(10, 15); l.autoLevels(); return {}; });
```
Para seleccionar una capa por nombre antes de operar: `app.activeDocument.activeLayer = app.activeDocument.layers.getByName('Foto');`.

## Varios tamaños de una misma pieza
No estires: por cada formato, vuelve a hacer el spec con las medidas nuevas y recoloca los bloques
(título, foto, llamada a la acción) según el formato (ver tabla en `ps-design`). Exporta
`nombre-1080x1080.png`, `nombre-1080x1920.png`, etc.

## Lote de imágenes
Para muchas fotos (redimensionar, marca de agua, convertir a JPG): un `.jsx` que recorra la carpeta con
`new Folder(ruta).getFiles(/\.(jpe?g|png|tif)$/i)`, abra cada una, aplique el cambio, guarde con
`saveAs(..., true)` en `salida/` y la cierre con `SaveOptions.DONOTSAVECHANGES`. Prueba antes con una
sola imagen y enséñale el resultado al usuario.

No sobrescribas los originales. No le muestres comandos al usuario salvo que lo pida.
