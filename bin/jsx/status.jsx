__main(function(){
  var list = []; for (var i = 0; i < app.documents.length; i++) list.push(app.documents[i].name);
  return { version: app.version, os: $.os, documents: list, active: app.documents.length ? __docInfo(app.activeDocument) : null };
});
