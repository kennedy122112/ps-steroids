// Helpers comunes de ps-steroids (ExtendScript ES3: sin JSON nativo). Cada comando termina en __main(function(){...}).
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
