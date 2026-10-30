#!/usr/bin/env bash
# ps-cli.sh - puente local entre el agente y Adobe Photoshop en macOS (AppleScript "do javascript" + ExtendScript).
# Sin MCP, sin nube. Mismos comandos y opciones que ps-cli.ps1 (Windows); ambos ejecutan bin/jsx/*.jsx.
#
#   ps-cli.sh status | open -Path <archivo> [-Launch] | read [-Depth 4] | fonts -Query <texto>
#   ps-cli.sh build -Spec <spec.json> [-Launch] | preview -Path <png> [-MaxSize 1200]
#   ps-cli.sh export -Path <png|jpg|psd> [-Quality 90] | jsx -Script <archivo.jsx>
#   ps-cli.sh inspect -Path <archivo.psd> [-Preview <png>] [-Depth 4]   # sin Photoshop (Python + psd-tools)
#
# -DryRun escribe el ExtendScript generado en stdout sin tocar Photoshop. Toda salida es JSON por stdout.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSX="$DIR/jsx"
PSID="com.adobe.Photoshop"

CMD="${1:-status}"; [ $# -gt 0 ] && shift
P_PATH=""; P_SPEC=""; P_SCRIPT=""; P_QUERY=""; P_PREVIEW=""; DEPTH=4; QUALITY=90; MAXSIZE=1200; LAUNCH=0; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    -Path|--path) P_PATH="$2"; shift 2 ;;
    -Spec|--spec) P_SPEC="$2"; shift 2 ;;
    -Script|--script) P_SCRIPT="$2"; shift 2 ;;
    -Query|--query) P_QUERY="$2"; shift 2 ;;
    -Preview|--preview) P_PREVIEW="$2"; shift 2 ;;
    -Depth|--depth) DEPTH="$2"; shift 2 ;;
    -Quality|--quality) QUALITY="$2"; shift 2 ;;
    -MaxSize|--max-size) MAXSIZE="$2"; shift 2 ;;
    -Launch|--launch) LAUNCH=1; shift ;;
    -DryRun|--dry-run) DRY=1; shift ;;
    *) shift ;;
  esac
done

esc() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/}"; s="${s//$'\t'/\\t}"; printf '"%s"' "$s"; }
fail() { printf '{"ok":false,"error":%s}\n' "$(esc "$1")"; exit 1; }
abspath() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$(pwd)" "${1#./}" ;; esac; }
need_path() { [ -n "$P_PATH" ] || fail "Falta -Path."; }

installed() {
  local out="" app ver
  for app in /Applications/Adobe\ Photoshop*/Adobe\ Photoshop*.app; do
    [ -d "$app" ] || continue
    ver="$(defaults read "$app/Contents/Info" CFBundleShortVersionString 2>/dev/null)"
    out="$out${out:+,}{\"path\":$(esc "$app"),\"version\":$(esc "$ver")}"
  done
  printf '[%s]' "$out"
}
running() { [ "$(osascript -e "application id \"$PSID\" is running" 2>/dev/null)" = "true" ]; }
ensure_app() {
  command -v osascript >/dev/null || fail "ps-cli.sh es para macOS (no hay osascript). En Windows usa ps-cli.ps1."
  if ! running; then
    [ "$LAUNCH" = 1 ] || fail "Photoshop no está abierto. Ábrelo (o repite el comando con -Launch)."
    osascript -e "tell application id \"$PSID\" to launch" >/dev/null 2>&1 || fail "No se pudo iniciar Photoshop."
    for _ in $(seq 1 90); do running && break; sleep 1; done
  fi
}
# Ejecuta: variables de entrada + lib.jsx + jsx del comando (o un script del usuario).
run_jsx() {
  local vars="$1" file="$2" tmp out
  tmp="$(mktemp "${TMPDIR:-/tmp}/ps-cli.XXXXXX")"
  { printf '%s\n' "$vars"; cat "$JSX/lib.jsx"; printf '\n'; cat "$file"; } > "$tmp"
  if [ "$DRY" = 1 ]; then cat "$tmp"; rm -f "$tmp"; return; fi
  ensure_app
  out="$(osascript -e "tell application id \"$PSID\" to do javascript (read (POSIX file \"$tmp\") as «class utf8»)" 2>&1)" \
    || { rm -f "$tmp"; fail "Photoshop no respondió: $out (¿permiso de Automatización? Ajustes del Sistema > Privacidad y seguridad > Automatización)"; }
  rm -f "$tmp"
  case "$out" in "{"*) printf '%s\n' "$out" ;; *) printf '{"ok":false,"error":"Respuesta no válida de Photoshop","raw":%s}\n' "$(esc "$out")" ;; esac
}

case "$CMD" in
  status)
    if [ "$DRY" = 1 ]; then run_jsx "" "$JSX/status.jsx"; exit 0; fi
    inst="$(installed)"
    if ! command -v osascript >/dev/null || ! running; then printf '{"ok":true,"running":false,"installed":%s}\n' "$inst"; exit 0; fi
    out="$(run_jsx "" "$JSX/status.jsx")"
    printf '%s,"running":true,"installed":%s}\n' "${out%\}}" "$inst" ;;
  open)
    need_path; [ -e "$P_PATH" ] || fail "No existe el archivo: $P_PATH"
    run_jsx "var P = $(esc "$(abspath "$P_PATH")");" "$JSX/open.jsx" ;;
  read) run_jsx "var DEPTH = $DEPTH;" "$JSX/read.jsx" ;;
  fonts) run_jsx "var Q = $(esc "$(printf '%s' "$P_QUERY" | tr '[:upper:]' '[:lower:]')");" "$JSX/fonts.jsx" ;;
  build)
    [ -n "$P_SPEC" ] || fail "Falta -Spec <archivo.json>."
    [ -f "$P_SPEC" ] || fail "No existe el spec: $P_SPEC"
    spec="$(abspath "$P_SPEC")"
    if command -v python3 >/dev/null; then python3 -I -c 'import json,sys; json.load(open(sys.argv[1],encoding="utf-8"))' "$spec" 2>/dev/null || fail "El spec no es JSON válido."; fi
    run_jsx "var SPEC = $(cat "$spec");
var SPEC_DIR = $(esc "$(dirname "$spec")");" "$JSX/build.jsx" ;;
  preview) need_path; run_jsx "var OUT = $(esc "$(abspath "$P_PATH")"), MAX = $MAXSIZE;" "$JSX/preview.jsx" ;;
  export)
    need_path; out="$(abspath "$P_PATH")"; fmt="$(printf '%s' "${out##*.}" | tr '[:upper:]' '[:lower:]')"
    case "$fmt" in png|jpg|jpeg|psd) ;; *) fail "Formato no soportado: .$fmt (usa png, jpg o psd)." ;; esac
    [ "$DRY" = 1 ] || mkdir -p "$(dirname "$out")"
    run_jsx "var OUT = $(esc "$out"), FMT = '$fmt', Q = $QUALITY;" "$JSX/export.jsx" ;;
  jsx)
    [ -n "$P_SCRIPT" ] || fail "Falta -Script <archivo.jsx>."
    [ -f "$P_SCRIPT" ] || fail "No existe el script: $P_SCRIPT"
    run_jsx "" "$P_SCRIPT" ;;
  inspect)
    need_path; command -v python3 >/dev/null || fail "inspect necesita Python 3 (xcode-select --install o python.org) y psd-tools: pip3 install psd-tools"
    if [ -n "$P_PREVIEW" ]; then exec python3 "$DIR/psd_read.py" "$P_PATH" --depth "$DEPTH" --preview "$P_PREVIEW"
    else exec python3 "$DIR/psd_read.py" "$P_PATH" --depth "$DEPTH"; fi ;;
  *) fail "Comando desconocido: $CMD (status, open, read, fonts, build, preview, export, jsx, inspect)" ;;
esac
