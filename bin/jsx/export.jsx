// Entrada: OUT (ruta de salida), FMT (png, jpg, jpeg o psd), Q (calidad JPG 1-100).
__main(function(){
  if (!app.documents.length) throw new Error('No hay ningún documento abierto.');
  var d = app.activeDocument, f = new File(OUT), o;
  if (FMT === 'psd') { o = new PhotoshopSaveOptions(); o.layers = true; o.embedColorProfile = true; d.saveAs(f, o, false, Extension.LOWERCASE); }
  else if (FMT === 'png') { o = new PNGSaveOptions(); o.compression = 6; d.saveAs(f, o, true, Extension.LOWERCASE); }
  else { o = new JPEGSaveOptions(); o.quality = Math.max(0, Math.min(12, Math.round(Q / 100 * 12))); o.embedColorProfile = true; d.saveAs(f, o, true, Extension.LOWERCASE); }
  return { path: OUT, format: FMT, document: __docInfo(d) };
});
