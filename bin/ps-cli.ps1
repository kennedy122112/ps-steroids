<#
  ps-cli.ps1 - puente local entre el agente y Adobe Photoshop (API COM + ExtendScript).
  Sin MCP, sin nube. Requiere Photoshop instalado en esta PC (2021 o posterior recomendado).

  Uso:
    ps-cli.ps1 status                              # ¿Photoshop instalado/abierto? ¿qué documentos?
    ps-cli.ps1 open    -Path <imagen|psd> [-Launch] # abre un archivo
    ps-cli.ps1 read    [-Depth 4]                  # documento activo: tamaño, capas, textos, fuentes
    ps-cli.ps1 fonts   -Query <texto>              # busca fuentes instaladas (nombre PostScript)
    ps-cli.ps1 build   -Spec <spec.json> [-Launch] # crea un diseño por capas (documento nuevo o el activo)
    ps-cli.ps1 preview -Path <salida.png> [-MaxSize 1200]   # vista plana reducida para revisar
    ps-cli.ps1 export  -Path <salida.png|jpg|psd> [-Quality 90]
    ps-cli.ps1 jsx     -Script <archivo.jsx>       # ejecuta ExtendScript con los helpers de ps-cli

  -DryRun (build/jsx) escribe el ExtendScript generado en stdout sin tocar Photoshop.
  Toda salida es JSON por stdout.
#>
param(
  [Parameter(Position = 0)][string]$Command = 'status',
  [string]$Path,
  [string]$Spec,
  [string]$Script,
  [string]$Query,
  [int]$Depth = 4,
  [int]$Quality = 90,
  [int]$MaxSize = 1200,
  [switch]$Launch,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Out-Json($obj) { ConvertTo-Json -InputObject $obj -Depth 12 }
function Fail($msg) { Out-Json @{ ok = $false; error = $msg }; exit 1 }
function Js-Str([string]$s) { ConvertTo-Json -InputObject $s -Compress }

# Instalaciones de Photoshop registradas (no hace falta que esté abierto).
function Get-Installed {
  $found = @()
  foreach ($k in Get-ChildItem 'HKLM:\SOFTWARE\Adobe\Photoshop' -ErrorAction SilentlyContinue) {
    $p = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).ApplicationPath
    if ($p) {
      $exe = Join-Path $p 'Photoshop.exe'
      $ver = if (Test-Path $exe) { (Get-Item $exe).VersionInfo.ProductVersion } else { $null }
      $found += [ordered]@{ key = $k.PSChildName; path = $p; exists = (Test-Path $exe); version = $ver }
    }
  }
  if (-not $found) {
    foreach ($exe in Get-ChildItem 'C:\Program Files\Adobe\*\Photoshop.exe' -ErrorAction SilentlyContinue) {
      $found += [ordered]@{ key = $exe.Directory.Name; path = $exe.DirectoryName; exists = $true; version = $exe.VersionInfo.ProductVersion }
    }
  }
  return ,$found
}

function Get-App([switch]$Soft) {
  try { return [System.Runtime.InteropServices.Marshal]::GetActiveObject('Photoshop.Application') } catch { }
  if ($Launch) {
    try { return New-Object -ComObject 'Photoshop.Application' }
    catch { Fail "No se pudo iniciar Photoshop por COM: $($_.Exception.Message)" }
  }
  if ($Soft) { return $null }
  Fail 'Photoshop no está abierto. Ábrelo (o repite el comando con -Launch).'
}

# Helpers de ExtendScript (ES3: sin JSON nativo). Cada comando termina en __main(function(){...}).
$Lib = @'
function cTID(s){ return charIDToTypeID(s); }
function sTID(s){ return stringIDToTypeID(s); }
function J(v){
  if (v === null || v === undefined) return 'null';
  var t = typeof v;
  if (t === 'number') return isFinite(v) ? String(v) : 'null';
  if (t === 'boolean') return v ? 'true' : 'false';
  if (t === 'string') return '"' + v.replace(/[\\"\x00-\x1f]/g, function(c){
    var m = {'\\':'\\\\','"':'\\"','\n':'\\n','\r':'\\r','\t':'\\t'};
    return m[c] || ('\\u' + ('0000' + c.charCodeAt(0).toString(16)).slice(-4)); }) + '"';
  if (v instanceof Array) { var a = []; for (var i = 0; i < v.length; i++) a.push(J(v[i])); return '[' + a.join(',') + ']'; }
  var o = []; for (var k in v) { if (v.hasOwnProperty(k)) o.push(J(k) + ':' + J(v[k])); }
  return '{' + o.join(',') + '}';
}
var __u, __tu, __dlg, W = [];
function __main(fn){
  var res;
  __u = app.preferences.rulerUnits; __tu = app.preferences.typeUnits; __dlg = app.displayDialogs;
  app.preferences.rulerUnits = Units.PIXELS; app.preferences.typeUnits = TypeUnits.PIXELS;
  app.displayDialogs = DialogModes.NO;
  try { res = fn() || {}; if (res.ok === undefined) res.ok = true; }
  catch (e) { res = { ok: false, error: String(e.message || e) + (e.line ? ' (línea ' + e.line + ')' : '') }; }
  finally { app.preferences.rulerUnits = __u; app.preferences.typeUnits = __tu; app.displayDialogs = __dlg; }
  if (W.length) res.warnings = W;
  return J(res);
}
function __px(u){ return Math.round(u.as('px') * 100) / 100; }
function __b(l){ var b = l.bounds; return [__px(b[0]), __px(b[1]), __px(b[2]), __px(b[3])]; }
function __hex(h){
  h = String(h || '#000000').replace('#', '');
  if (h.length === 3) h = h.charAt(0)+h.charAt(0)+h.charAt(1)+h.charAt(1)+h.charAt(2)+h.charAt(2);
  return { r: parseInt(h.substr(0,2),16), g: parseInt(h.substr(2,2),16), b: parseInt(h.substr(4,2),16) };
}
function __color(h){ var c = __hex(h), s = new SolidColor(); s.rgb.red = c.r; s.rgb.green = c.g; s.rgb.blue = c.b; return s; }
function __rgbDesc(h){ var c = __hex(h), d = new ActionDescriptor();
  d.putDouble(cTID('Rd  '), c.r); d.putDouble(cTID('Grn '), c.g); d.putDouble(cTID('Bl  '), c.b); return d; }
function __toHex(sc){ try { return '#' + sc.rgb.hexValue; } catch (e) { return null; } }
function __docInfo(d){
  var p = null; try { p = d.fullName.fsName; } catch (e) {}
  return { name: d.name, width: __px(d.width), height: __px(d.height), resolution: d.resolution,
           mode: String(d.mode).replace('DocumentMode.', ''), layers: d.layers.length, path: p, saved: d.saved };
}
'@

# ---------- build: spec JSON -> capas ----------
$BuildJsx = @'
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
'@

# ---------- read ----------
$ReadJsx = @'
function __kind(l){ return l.typename === 'LayerSet' ? 'group' : String(l.kind).replace('LayerKind.', '').toLowerCase(); }
function __walk(c, depth){
  var out = [];
  for (var i = 0; i < c.length; i++) {
    var l = c[i], o = { name: l.name, kind: __kind(l), visible: l.visible, opacity: Math.round(l.opacity) };
    try { o.blend = String(l.blendMode).replace('BlendMode.', '').toLowerCase(); } catch (e) {}
    if (l.typename === 'LayerSet') { if (depth > 1) o.layers = __walk(l.layers, depth - 1); else o.children = l.layers.length; }
    else {
      try { o.bounds = __b(l); } catch (e) {}
      if (l.grouped) o.clipped = true;
      if (l.isBackgroundLayer) o.background = true;
      if (l.kind === LayerKind.TEXT) { var t = l.textItem;
        o.text = String(t.contents).replace(/\r/g, '\n');
        try { o.font = t.font; } catch (e) {} try { o.size = Math.round(t.size.as('px')); } catch (e) {}
        try { o.color = __toHex(t.color); } catch (e) {} }
    }
    out.push(o);
  }
  return out;
}
__main(function(){
  if (!app.documents.length) return { documents: [], active: null };
  var d = app.activeDocument, list = [];
  for (var i = 0; i < app.documents.length; i++) list.push(app.documents[i].name);
  return { documents: list, active: __docInfo(d), layers: __walk(d.layers, DEPTH) };
});
'@

function Invoke-Jsx($app, [string]$code) {
  $raw = $app.DoJavaScript($code)
  try { $null = $raw | ConvertFrom-Json; $raw } catch { Out-Json @{ ok = $false; error = 'Respuesta no válida de Photoshop'; raw = "$raw" } }
}
function Run-Jsx([string]$body) {
  $code = $Lib + "`n" + $body
  if ($DryRun) { $code; return }
  $app = Get-App
  Invoke-Jsx $app $code
}
function Need-Path { if (-not $Path) { Fail "Falta -Path." } }

switch ($Command) {
  'status' {
    $inst = Get-Installed
    $app = Get-App -Soft
    if (-not $app) { Out-Json ([ordered]@{ ok = $true; running = $false; installed = $inst }); break }
    $raw = Invoke-Jsx $app ($Lib + @'
__main(function(){
  var list = []; for (var i = 0; i < app.documents.length; i++) list.push(app.documents[i].name);
  return { version: app.version, documents: list, active: app.documents.length ? __docInfo(app.activeDocument) : null };
});
'@)
    $o = $raw | ConvertFrom-Json
    $o | Add-Member running $true; $o | Add-Member installed $inst
    Out-Json $o
  }
  'open' {
    Need-Path
    $full = (Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue).Path
    if (-not $full) { Fail "No existe el archivo: $Path" }
    Run-Jsx ("var P = $(Js-Str $full);`n" + '__main(function(){ var d = app.open(new File(P)); return { document: __docInfo(d) }; });')
  }
  'read' { Run-Jsx ("var DEPTH = $Depth;`n" + $ReadJsx) }
  'fonts' {
    $q = if ($Query) { $Query } else { '' }
    Run-Jsx ("var Q = $(Js-Str $q.ToLower());`n" + @'
__main(function(){
  var out = [], f;
  for (var i = 0; i < app.fonts.length && out.length < 60; i++) { f = app.fonts[i];
    if (!Q || (f.name + ' ' + f.postScriptName + ' ' + f.family).toLowerCase().indexOf(Q) >= 0)
      out.push({ postScriptName: f.postScriptName, family: f.family, style: f.style }); }
  return { total: app.fonts.length, matches: out };
});
'@)
  }
  'build' {
    if (-not $Spec) { Fail 'Falta -Spec <archivo.json>.' }
    if (-not (Test-Path -LiteralPath $Spec)) { Fail "No existe el spec: $Spec" }
    $json = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Spec).Path, [Text.Encoding]::UTF8)
    try { $null = $json | ConvertFrom-Json } catch { Fail "El spec no es JSON válido: $($_.Exception.Message)" }
    # Las rutas de imagen relativas se resuelven contra la carpeta del spec.
    $specDir = Split-Path -Parent (Resolve-Path -LiteralPath $Spec).Path
    $json = $json -replace "[\u2028\u2029]", ' '
    Run-Jsx ("var SPEC = $json;`nvar SPEC_DIR = $(Js-Str $specDir);`n" + @'
(function fix(list){ for (var i = 0; list && i < list.length; i++) { var L = list[i];
  if (L.src && !/^([a-zA-Z]:|\\\\|\/)/.test(L.src)) L.src = SPEC_DIR + '\\' + L.src.replace(/\//g, '\\');
  if (L.layers) fix(L.layers); } })(SPEC.layers);
'@ + $BuildJsx)
  }
  'preview' {
    Need-Path
    $out = [IO.Path]::GetFullPath($Path)
    Run-Jsx ("var OUT = $(Js-Str $out), MAX = $MaxSize;`n" + @'
__main(function(){
  if (!app.documents.length) throw new Error('No hay ningún documento abierto.');
  var d = app.activeDocument, dup = d.duplicate('ps-preview', true);
  var w = __px(dup.width), h = __px(dup.height), s = Math.min(1, MAX / Math.max(w, h));
  if (s < 1) dup.resizeImage(Math.round(w * s), Math.round(h * s), null, ResampleMethod.BICUBIC);
  var o = new PNGSaveOptions(); dup.saveAs(new File(OUT), o, true, Extension.LOWERCASE);
  dup.close(SaveOptions.DONOTSAVECHANGES); app.activeDocument = d;
  return { path: OUT, width: Math.round(w * s), height: Math.round(h * s) };
});
'@)
  }
  'export' {
    Need-Path
    $out = [IO.Path]::GetFullPath($Path)
    $fmt = [IO.Path]::GetExtension($out).TrimStart('.').ToLower()
    if ($fmt -notin 'png', 'jpg', 'jpeg', 'psd') { Fail "Formato no soportado: .$fmt (usa png, jpg o psd)." }
    New-Item -ItemType Directory -Force (Split-Path -Parent $out) | Out-Null
    Run-Jsx ("var OUT = $(Js-Str $out), FMT = '$fmt', Q = $Quality;`n" + @'
__main(function(){
  if (!app.documents.length) throw new Error('No hay ningún documento abierto.');
  var d = app.activeDocument, f = new File(OUT), o;
  if (FMT === 'psd') { o = new PhotoshopSaveOptions(); o.layers = true; o.embedColorProfile = true; d.saveAs(f, o, false, Extension.LOWERCASE); }
  else if (FMT === 'png') { o = new PNGSaveOptions(); o.compression = 6; d.saveAs(f, o, true, Extension.LOWERCASE); }
  else { o = new JPEGSaveOptions(); o.quality = Math.max(0, Math.min(12, Math.round(Q / 100 * 12))); o.embedColorProfile = true; d.saveAs(f, o, true, Extension.LOWERCASE); }
  return { path: OUT, format: FMT, document: __docInfo(d) };
});
'@)
  }
  'jsx' {
    if (-not $Script) { Fail 'Falta -Script <archivo.jsx>.' }
    if (-not (Test-Path -LiteralPath $Script)) { Fail "No existe el script: $Script" }
    Run-Jsx ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $Script).Path, [Text.Encoding]::UTF8))
  }
  default { Fail "Comando desconocido: $Command (status, open, read, fonts, build, preview, export, jsx)" }
}
