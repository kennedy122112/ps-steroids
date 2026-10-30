---
name: ps-setup
description: Primer arranque de ps-steroids. Comprueba que esta PC puede controlar Adobe Photoshop por su API COM (Photoshop instalado, versión, puente ps-cli) y que responde. Úsala la primera vez, cuando el usuario diga "configura Photoshop", "prepara Photoshop", "set up Photoshop", "no conecta con Photoshop", o cuando ps-cli falle.
---

# Preparar Photoshop (ps-steroids)

ps-steroids controla **Adobe Photoshop** en local mediante su API COM (`Photoshop.Application`),
que ejecuta ExtendScript dentro de Photoshop. No usa MCP, ni API key, ni nube. El puente es un
script PowerShell sin dependencias, el mismo para cualquier agente:

`~/.ps-steroids/bin/ps-cli.ps1`

En el resto de las skills de Photoshop, **ps-cli** significa:
`powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.ps-steroids\bin\ps-cli.ps1" <comando> ...`
(desde bash/Git Bash: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE/.ps-steroids/bin/ps-cli.ps1" <comando> ...`).
Toda salida es JSON por stdout.

## 1. ¿Está instalado Photoshop?
`ps-cli status` → el campo `installed` lista las versiones registradas (ruta y versión).
- Vacío → dile al usuario que instale Photoshop desde Creative Cloud (2021 / v22 o posterior;
  "Quitar fondo" y otras acciones rápidas lo necesitan) y espera.
- Photoshop solo existe en 64 bits; no hay que hacer nada especial.

## 2. ¿Responde por COM?
- `running: false` → Photoshop está cerrado. Pide al usuario que lo abra, o repite el comando que
  necesites con `-Launch` (lo inicia; la primera vez tarda hasta un minuto y puede pedir iniciar sesión en Adobe).
- `running: true` → listo; informa la versión (`version`) y los documentos abiertos.

## 3. Prueba rápida
`ps-cli fonts -Query arial` debe devolver fuentes. Si funciona, el puente ejecuta ExtendScript.

## Problemas frecuentes
- **Se queda colgado o no responde**: Photoshop tiene un diálogo abierto (inicio de sesión, novedades,
  perfil de color, "fuentes que faltan"). Pide al usuario que lo cierre y repite.
- **"no está abierto" con Photoshop visible**: uno se abrió como administrador y el otro no. Que lo abra normal.
- **Error 80080005 al usar -Launch**: Photoshop está arrancando o Creative Cloud está actualizándolo; espera y reintenta.
- **El agente corre en un sandbox** (Codex por defecto) y no alcanza el COM: vuelve a ejecutar ps-cli
  pidiendo permiso para salir del sandbox en vez de buscar otra vía.

No le muestres comandos al usuario. Ejecútalos tú y cuéntale el resultado en lenguaje sencillo.
