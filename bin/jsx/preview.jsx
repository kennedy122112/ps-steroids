// Entrada: OUT (ruta del PNG), MAX (lado mayor en px).
__main(function(){
  if (!app.documents.length) throw new Error('No hay ningún documento abierto.');
  var d = app.activeDocument, dup = d.duplicate('ps-preview', true);
  var w = __px(dup.width), h = __px(dup.height), s = Math.min(1, MAX / Math.max(w, h));
  if (s < 1) dup.resizeImage(Math.round(w * s), Math.round(h * s), null, ResampleMethod.BICUBIC);
  var o = new PNGSaveOptions(); dup.saveAs(new File(OUT), o, true, Extension.LOWERCASE);
  dup.close(SaveOptions.DONOTSAVECHANGES); app.activeDocument = d;
  return { path: OUT, width: Math.round(w * s), height: Math.round(h * s) };
});
