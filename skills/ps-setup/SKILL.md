---
name: ps-setup
description: Primer arranque de ps-steroids. Comprueba que esta PC o Mac puede controlar Adobe Photoshop (Photoshop instalado, versión, puente ps-cli por COM en Windows o AppleScript en macOS) y que responde. Úsala la primera vez, cuando el usuario diga "configura Photoshop", "prepara Photoshop", "set up Photoshop", "no conecta con Photoshop", o cuando ps-cli falle.
---

# Preparar Photoshop (ps-steroids)

ps-steroids controla **Adobe Photoshop** en local ejecutando ExtendScript dentro de Photoshop:
en **Windows** por su API COM (`Photoshop.Application`) y en **macOS** por AppleScript (`do javascript`).
No usa MCP, ni API key, ni nube. Los dos puentes tienen los mismos comandos y opciones y ejecutan los
mismos scripts (`bin/jsx/*.jsx`):

En el resto de las skills de Photoshop, **ps-cli** significa:
- **Windows**: `powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.ps-steroids\bin\ps-cli.ps1" <comando> ...`
  (desde bash/Git Bash: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE/.ps-steroids/bin/ps-cli.ps1" <comando> ...`)
- **macOS**: `bash ~/.ps-steroids/bin/ps-cli.sh <comando> ...`

Toda salida es JSON por stdout. Las rutas, en el formato del sistema (`C:\...` o `/Users/...`).

## 1. ¿Está instalado Photoshop?
`ps-cli status` → el campo `installed` lista las versiones encontradas (ruta y versión).
- Vacío → dile al usuario que instale Photoshop desde Creative Cloud (2021 / v22 o posterior;
  "Quitar fondo" y otras acciones rápidas lo necesitan) y espera.

## 2. ¿Responde?
- `running: false` → Photoshop está cerrado. Pide al usuario que lo abra, o repite el comando que
  necesites con `-Launch` (lo inicia; la primera vez tarda hasta un minuto y puede pedir iniciar sesión en Adobe).
- `running: true` → listo; informa la versión (`version`) y los documentos abiertos.
- **macOS, primera vez**: el sistema pregunta si la terminal o el agente puede controlar Photoshop.
  Dile al usuario que pulse **Aceptar**. Si lo rechazó, se activa en Ajustes del Sistema > Privacidad y
  seguridad > Automatización (marcar Adobe Photoshop bajo la terminal o el agente).

## 3. Prueba rápida
`ps-cli fonts -Query arial` debe devolver fuentes. Si funciona, el puente ejecuta ExtendScript.

## 4. Lectura sin Photoshop (opcional)
`ps-cli inspect` lee PSD sin Photoshop. Necesita Python 3 y psd-tools:
- Windows: `python -m pip install --user psd-tools` (Python desde python.org o la Microsoft Store).
- macOS: `python3 -m pip install --user psd-tools` (si no hay `python3`, `xcode-select --install`).
Pide permiso al usuario antes de instalar nada.

## Problemas frecuentes
- **Se queda colgado o no responde**: Photoshop tiene un diálogo abierto (inicio de sesión, novedades,
  perfil de color, "fuentes que faltan"). Pide al usuario que lo cierre y repite.
- **Windows, "no está abierto" con Photoshop visible**: uno se abrió como administrador y el otro no. Que lo abra normal.
- **Windows, error 80080005 al usar -Launch**: Photoshop está arrancando o Creative Cloud lo está actualizando; espera y reintenta.
- **macOS, error -1743 / "not authorized"**: falta el permiso de Automatización (paso 2).
- **El agente corre en un sandbox** (Codex por defecto) y no llega a Photoshop: vuelve a ejecutar ps-cli
  pidiendo permiso para salir del sandbox en vez de buscar otra vía.

No le muestres comandos al usuario. Ejecútalos tú y cuéntale el resultado en lenguaje sencillo.
