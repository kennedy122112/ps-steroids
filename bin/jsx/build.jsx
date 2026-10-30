// Entrada: SPEC (objeto del spec JSON), SPEC_DIR (carpeta del spec, para rutas relativas de imágenes).
(function fix(list){ for (var i = 0; list && i < list.length; i++) { var L = list[i];
  if (L.src && !/^([a-zA-Z]:|\\\\|\/|~)/.test(L.src)) L.src = SPEC_DIR + '/' + L.src.replace(/\\/g, '/');
  if (L.layers) fix(L.layers); } })(SPEC.layers);
var S = SPEC, doc, __fonts = null;
function __font(n){
  if (!n) return null;
  if (!__fonts) { __fonts = {}; for (var i = 0; i < app.fonts.length; i++) { var f = app.fonts[i];
    __fonts[f.postScriptName.toLowerCase()] = f.postScriptName; if (!__fonts[f.name.toLowerCase()]) __fonts[f.name.toLowerCase()] = f.postScriptName; } }
  var hit = __fonts[String(n).toLowerCase()];
  if (!hit) { W.push('Fuente no instalada: ' + n + ' (se usa ArialMT)'); return 'ArialMT'; }
  return hit;
}
function __blend(b){
  var k = String(b).toUpperCase().replace(/[\s_-]/g, '');
  if (k === 'COLOR') k = 'COLORBLEND';
  if (!BlendMode[k]) { W.push('Modo de fusión desconocido: ' + b); return BlendMode.NORMAL; }
  return BlendMode[k];
}
function __select(x, y, w, h){ doc.selection.select([[x,y],[x+w,y],[x+w,y+h],[x,y+h]]); }
function __maskFromSelection(){
  var d = new ActionDescriptor(); d.putClass(cTID('Nw  '), cTID('Chnl'));
  var r = new ActionReference(); r.putEnumerated(cTID('Chnl'), cTID('Chnl'), cTID('Msk '));
  d.putReference(cTID('At  '), r); d.putEnumerated(cTID('Usng'), cTID('UsrM'), cTID('RvlS'));
  executeAction(cTID('Mk  '), d, DialogModes.NO);
}
// Capa de relleno (color o degradado). Con selección activa queda enmascarada a esa caja.
function __fillLayer(typeDesc, typeKey){
  var d = new ActionDescriptor(), r = new ActionReference(); r.putClass(sTID('contentLayer')); d.putReference(cTID('null'), r);
  var d2 = new ActionDescriptor(); d2.putObject(cTID('Type'), sTID(typeKey), typeDesc);
  d.putObject(cTID('Usng'), sTID('contentLayer'), d2);
  executeAction(cTID('Mk  '), d, DialogModes.NO);
  return doc.activeLayer;
}
function __solidDesc(h){ var d = new ActionDescriptor(); d.putObject(cTID('Clr '), cTID('RGBC'), __rgbDesc(h)); return d; }
function __gradDesc(L){
  var stops = L.stops, i;
  if (!stops) { stops = []; var cs = L.colors || ['#000000', '#ffffff'];
    for (i = 0; i < cs.length; i++) stops.push({ color: cs[i], pos: cs.length > 1 ? i / (cs.length - 1) : 0 }); }
  var g = new ActionDescriptor();
  g.putUnitDouble(cTID('Angl'), cTID('#Ang'), L.angle == null ? 90 : L.angle);
  g.putEnumerated(cTID('Type'), cTID('GrdT'), L.style === 'radial' ? cTID('Rdl ') : cTID('Lnr '));
  var grd = new ActionDescriptor(); grd.putString(cTID('Nm  '), 'ps-steroids');
  grd.putEnumerated(cTID('GrdF'), cTID('GrdF'), cTID('CstS')); grd.putDouble(cTID('Intr'), 4096);
  var cl = new ActionList(), tl = new ActionList();
  for (i = 0; i < stops.length; i++) {
    var s = new ActionDescriptor(); s.putObject(cTID('Clr '), cTID('RGBC'), __rgbDesc(stops[i].color));
    s.putEnumerated(cTID('Type'), cTID('Clry'), cTID('UsrS'));
    s.putInteger(cTID('Lctn'), Math.round(stops[i].pos * 4096)); s.putInteger(cTID('Mdpn'), 50);
    cl.putObject(cTID('Clrt'), s);
    var t = new ActionDescriptor();
    t.putUnitDouble(cTID('Opct'), cTID('#Prc'), stops[i].opacity == null ? 100 : stops[i].opacity);
    t.putInteger(cTID('Lctn'), Math.round(stops[i].pos * 4096)); t.putInteger(cTID('Mdpn'), 50);
    tl.putObject(cTID('TrnS'), t);
  }
  grd.putList(cTID('Clrs'), cl); grd.putList(cTID('Trns'), tl);
  g.putObject(cTID('Grad'), cTID('Grdn'), grd);
  return g;
}
// Forma vectorial editable (rect con radio opcional, o elipse).
function __shape(L){
  var d = new ActionDescriptor(), r = new ActionReference(); r.putClass(sTID('contentLayer')); d.putReference(cTID('null'), r);
  var d2 = new ActionDescriptor(); d2.putObject(cTID('Type'), sTID('solidColorLayer'), __solidDesc(L.color || '#cccccc'));
  var sh = new ActionDescriptor(), px = cTID('#Pxl');
  sh.putUnitDouble(cTID('Top '), px, L.y); sh.putUnitDouble(cTID('Left'), px, L.x);
  sh.putUnitDouble(cTID('Btom'), px, L.y + L.h); sh.putUnitDouble(cTID('Rght'), px, L.x + L.w);
  if (L.type === 'rect' && L.radius) {
    sh.putUnitDouble(sTID('topLeft'), px, L.radius); sh.putUnitDouble(sTID('topRight'), px, L.radius);
    sh.putUnitDouble(sTID('bottomLeft'), px, L.radius); sh.putUnitDouble(sTID('bottomRight'), px, L.radius);
  }
  d2.putObject(cTID('Shp '), L.type === 'ellipse' ? cTID('Elps') : cTID('Rctn'), sh);
  d.putObject(cTID('Usng'), sTID('contentLayer'), d2);
  executeAction(cTID('Mk  '), d, DialogModes.NO);
  return doc.activeLayer;
}
function __text(L){
  var lyr = doc.artLayers.add(); lyr.kind = LayerKind.TEXT;
  var ti = lyr.textItem;
  ti.contents = String(L.text || '').replace(/\n/g, '\r');
  if (L.w) { ti.kind = TextType.PARAGRAPHTEXT; ti.position = [L.x, L.y]; ti.width = L.w; ti.height = L.h || (__px(doc.height) - L.y); }
  else ti.position = [L.x, L.y];
  var f = __font(L.font); if (f) ti.font = f;
  ti.size = L.size || 32;
  ti.color = __color(L.color || '#111111');
  if (L.align) ti.justification = { left: Justification.LEFT, center: Justification.CENTER, right: Justification.RIGHT, justify: Justification.LEFTJUSTIFIED }[L.align] || Justification.LEFT;
  if (L.leading) { ti.useAutoLeading = false; ti.leading = L.leading; }
  if (L.tracking != null) ti.tracking = L.tracking;
  if (L.caps) ti.capitalization = TextCase.ALLCAPS;
  return lyr;
}
function __placeFile(p){
  var f = new File(p); if (!f.exists) throw new Error('No existe la imagen: ' + p);
  var d = new ActionDescriptor(); d.putPath(cTID('null'), f);
  d.putEnumerated(cTID('FTcs'), cTID('QCSt'), cTID('Qcsa'));
  var o = new ActionDescriptor(); o.putUnitDouble(cTID('Hrzn'), cTID('#Pxl'), 0); o.putUnitDouble(cTID('Vrtc'), cTID('#Pxl'), 0);
  d.putObject(cTID('Ofst'), cTID('Ofst'), o);
  executeAction(cTID('Plc '), d, DialogModes.NO);
  return doc.activeLayer;
}
function __image(L){
  var lyr = __placeFile(L.src), b = __b(lyr), bw = b[2] - b[0], bh = b[3] - b[1];
  if (L.w && L.h) {
    var fit = L.fit || 'cover', sx, sy;
    if (fit === 'stretch') { sx = L.w / bw; sy = L.h / bh; }
    else { sx = sy = (fit === 'contain') ? Math.min(L.w / bw, L.h / bh) : Math.max(L.w / bw, L.h / bh); }
    lyr.resize(sx * 100, sy * 100, AnchorPosition.MIDDLECENTER);
    b = __b(lyr);
    lyr.translate((L.x + L.w / 2) - (b[0] + b[2]) / 2, (L.y + L.h / 2) - (b[1] + b[3]) / 2);
  } else if (L.x != null) {
    if (L.scale) { lyr.resize(L.scale * 100, L.scale * 100, AnchorPosition.TOPLEFT); b = __b(lyr); }
    lyr.translate(L.x - b[0], (L.y || 0) - b[1]);
  }
  if (L.removeBackground) {
    doc.activeLayer = lyr;
    try { executeAction(sTID('removeBackground'), new ActionDescriptor(), DialogModes.NO); }
    catch (e) { W.push('No se pudo quitar el fondo de ' + (L.name || L.src) + ' (requiere Photoshop 2021+): ' + e.message); }
  } else if (L.w && L.h && (L.fit || 'cover') === 'cover' && L.mask !== false && !L.clip) {
    __select(L.x, L.y, L.w, L.h); doc.activeLayer = lyr; __maskFromSelection(); doc.selection.deselect();
  }
  return lyr;
}
function __adjust(lyr, A){
  function mk(typeKey, desc){
    doc.activeLayer = lyr;
    var d = new ActionDescriptor(), r = new ActionReference(); r.putClass(cTID('AdjL')); d.putReference(cTID('null'), r);
    var d2 = new ActionDescriptor(); d2.putBoolean(cTID('Grup'), true); d2.putObject(cTID('Type'), typeKey, desc);
    d.putObject(cTID('Usng'), cTID('AdjL'), d2);
    executeAction(cTID('Mk  '), d, DialogModes.NO);
  }
  if (A.brightness || A.contrast) {
    var bc = new ActionDescriptor(); bc.putInteger(cTID('Brgh'), A.brightness || 0); bc.putInteger(cTID('Cntr'), A.contrast || 0);
    bc.putBoolean(sTID('useLegacy'), false); mk(cTID('BrgC'), bc);
  }
  if (A.hue || A.saturation || A.lightness) {
    var hs = new ActionDescriptor(); hs.putBoolean(cTID('Clrz'), false);
    var l = new ActionList(), a = new ActionDescriptor();
    a.putInteger(cTID('H   '), A.hue || 0); a.putInteger(cTID('Strt'), A.saturation || 0); a.putInteger(cTID('Lght'), A.lightness || 0);
    l.putObject(cTID('Hst2'), a); hs.putList(cTID('Adjs'), l); mk(cTID('HStr'), hs);
  }
}
function __fx(lyr, L){
  doc.activeLayer = lyr;
  var d = new ActionDescriptor(), r = new ActionReference();
  r.putProperty(cTID('Prpr'), cTID('Lefx')); r.putEnumerated(cTID('Lyr '), cTID('Ordn'), cTID('Trgt'));
  d.putReference(cTID('null'), r);
  var fx = new ActionDescriptor(); fx.putUnitDouble(cTID('Scl '), cTID('#Prc'), 100);
  if (L.shadow) { var s = L.shadow === true ? {} : L.shadow, ds = new ActionDescriptor();
    ds.putBoolean(cTID('enab'), true); ds.putEnumerated(cTID('Md  '), cTID('BlnM'), cTID('Mltp'));
    ds.putObject(cTID('Clr '), cTID('RGBC'), __rgbDesc(s.color || '#000000'));
    ds.putUnitDouble(cTID('Opct'), cTID('#Prc'), s.opacity == null ? 35 : s.opacity);
    ds.putBoolean(cTID('uglg'), false); ds.putUnitDouble(cTID('lagl'), cTID('#Ang'), s.angle == null ? 90 : s.angle);
    ds.putUnitDouble(cTID('Dstn'), cTID('#Pxl'), s.distance == null ? 8 : s.distance);
    ds.putUnitDouble(cTID('Ckmt'), cTID('#Pxl'), s.spread || 0);
    ds.putUnitDouble(cTID('blur'), cTID('#Pxl'), s.size == null ? 24 : s.size);
    fx.putObject(cTID('DrSh'), cTID('DrSh'), ds); }
  if (L.stroke) { var k = L.stroke, st = new ActionDescriptor();
    st.putBoolean(cTID('enab'), true);
    st.putEnumerated(cTID('Styl'), cTID('FStl'), { inside: cTID('InsF'), center: cTID('CtrF') }[k.position] || cTID('OutF'));
    st.putEnumerated(cTID('PntT'), cTID('FrFl'), cTID('SClr')); st.putEnumerated(cTID('Md  '), cTID('BlnM'), cTID('Nrml'));
    st.putUnitDouble(cTID('Opct'), cTID('#Prc'), k.opacity == null ? 100 : k.opacity);
    st.putUnitDouble(cTID('Sz  '), cTID('#Pxl'), k.size || 2);
    st.putObject(cTID('Clr '), cTID('RGBC'), __rgbDesc(k.color || '#000000'));
    fx.putObject(cTID('FrFX'), cTID('FrFX'), st); }
  d.putObject(cTID('T   '), cTID('Lefx'), fx);
  executeAction(cTID('setd'), d, DialogModes.NO);
}
// Coloca la capa arriba del todo dentro de su contenedor: el orden del spec es de abajo hacia arriba.
function __top(lyr, parent){
  if (parent === doc) { if (doc.layers[0] !== lyr) lyr.move(doc.layers[0], ElementPlacement.PLACEBEFORE); }
  else lyr.move(parent, ElementPlacement.PLACEATBEGINNING);
}
function __replace(name, parent){
  var c = parent === doc ? doc.layers : parent.layers;
  for (var i = c.length - 1; i >= 0; i--) if (c[i].name === name) { c[i].remove(); W.push('Capa reemplazada: ' + name); }
}
var __made = [];
function __layers(list, parent){ for (var i = 0; i < list.length; i++) __layer(list[i], parent); }
function __layer(L, parent){
  var t = L.type, lyr;
  if (L.name && S.target === 'active') __replace(L.name, parent);
  if (t === 'group') {
    lyr = (parent === doc ? doc : parent).layerSets.add();
    __top(lyr, parent); if (L.name) lyr.name = L.name;
    __layers(L.layers || [], lyr);
  } else {
    if (t === 'rect' || t === 'ellipse') lyr = __shape(L);
    else if (t === 'fill' || t === 'gradient') {
      if (L.w && L.h) __select(L.x || 0, L.y || 0, L.w, L.h);
      lyr = t === 'fill' ? __fillLayer(__solidDesc(L.color || '#ffffff'), 'solidColorLayer') : __fillLayer(__gradDesc(L), 'gradientLayer');
      if (L.w && L.h) doc.selection.deselect();
    }
    else if (t === 'text') lyr = __text(L);
    else if (t === 'image') lyr = __image(L);
    else throw new Error('Tipo de capa desconocido: ' + t);
    __top(lyr, parent);
    if (L.name) lyr.name = L.name;
    if (L.clip) lyr.grouped = true;
  }
  if (L.opacity != null) lyr.opacity = L.opacity;
  if (L.blend) lyr.blendMode = __blend(L.blend);
  if (L.rotate) lyr.rotate(L.rotate, AnchorPosition.MIDDLECENTER);
  if (L.shadow || L.stroke) __fx(lyr, L);
  if (L.adjust) __adjust(lyr, L.adjust);
  if (L.visible === false) lyr.visible = false;
  __made.push({ name: lyr.name, type: t, bounds: t === 'group' ? null : __b(lyr) });
}
var __err = null, __initial = null;
function __buildLayers(){ try { __layers(S.layers || [], doc); } catch (e) { __err = e; } }
__main(function(){
  var D = S.document || {}, res;
  if (S.target === 'active') {
    if (!app.documents.length) throw new Error('No hay ningún documento abierto en Photoshop.');
    doc = app.activeDocument; res = doc.resolution;
  } else {
    if (!D.width || !D.height) throw new Error('document.width y document.height son obligatorios.');
    res = D.resolution || 72;
    doc = app.documents.add(D.width, D.height, 72, D.name || 'Diseño', NewDocumentMode.RGB, DocumentFill.TRANSPARENT);
    __initial = doc.layers[0];
    if (D.background && D.background !== 'transparent') S.layers = [{ type: 'fill', name: 'Fondo', color: D.background }].concat(S.layers || []);
  }
  // Las formas y el texto se miden bien a 72 ppp: se trabaja ahí y se restaura sin remuestrear.
  if (doc.resolution !== 72) doc.resizeImage(null, null, 72, ResampleMethod.NONE);
  doc.suspendHistory('ps-steroids: ' + (D.name || 'build'), '__buildLayers()');
  if (__initial && doc.layers.length > 1) { try { __initial.remove(); } catch (e) {} }
  if (res !== 72) doc.resizeImage(null, null, res, ResampleMethod.NONE);
  if (__err) throw __err;
  return { document: __docInfo(doc), layers: __made };
});
