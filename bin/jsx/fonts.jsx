// Entrada: Q (texto a buscar, en minúsculas; vacío = todas).
__main(function(){
  var out = [], f;
  for (var i = 0; i < app.fonts.length && out.length < 60; i++) { f = app.fonts[i];
    if (!Q || (f.name + ' ' + f.postScriptName + ' ' + f.family).toLowerCase().indexOf(Q) >= 0)
      out.push({ postScriptName: f.postScriptName, family: f.family, style: f.style }); }
  return { total: app.fonts.length, matches: out };
});
