// Entrada: DEPTH (niveles de grupos a recorrer).
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
