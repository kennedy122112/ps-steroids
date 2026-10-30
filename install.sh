#!/usr/bin/env bash
# Instala (o reinstala) ps-steroids en los agentes de este Mac.
# Las skills viven una sola vez en ~/.ps-steroids/skills y cada agente las ve por un enlace
# simbólico, así que editarlas o actualizarlas aquí las cambia en todos.
#
# Sin clonar nada (descarga ps-steroids en ~/.ps-steroids o lo actualiza):
#   curl -fsSL https://raw.githubusercontent.com/kennedy122112/ps-steroids/main/install.sh | bash
#
# Desde una copia del repositorio:
#   bash install.sh
#   bash install.sh --uninstall   quita los enlaces (no borra los archivos)
set -e
REPO="https://github.com/kennedy122112/ps-steroids"
CASA="$HOME/.ps-steroids"
UNINSTALL=0; [ "${1:-}" = "--uninstall" ] && UNINSTALL=1

# Ejecutado con "curl … | bash": no hay archivo, así que se trae el repositorio y se instala desde ahí.
SRC="${BASH_SOURCE[0]:-}"
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
  if [ -f "$CASA/install.sh" ]; then
    if [ -d "$CASA/.git" ]; then git -C "$CASA" pull -q --ff-only; else echo "Ya existe $CASA (sin git): se reinstala tal como está."; fi
  elif [ -e "$CASA" ]; then
    echo "$CASA existe y no es ps-steroids: muévelo o bórralo antes de instalar." >&2; exit 1
  elif command -v git >/dev/null; then
    git clone -q "$REPO.git" "$CASA"
  else
    tmp="$(mktemp -d)"; curl -fsSL "$REPO/archive/refs/heads/main.tar.gz" | tar -xz -C "$tmp"
    mv "$tmp/ps-steroids-main" "$CASA"; rm -rf "$tmp"
  fi
  exec bash "$CASA/install.sh"
fi

ROOT="$(cd "$(dirname "$SRC")" && pwd -P)"

# Las skills llaman al puente por ~/.ps-steroids: si el repositorio está en otra carpeta,
# ~/.ps-steroids es un enlace hacia él.
if [ "$UNINSTALL" = 0 ] && [ "$(cd "$CASA" 2>/dev/null && pwd -P)" != "$ROOT" ]; then
  if [ -e "$CASA" ] && [ ! -L "$CASA" ]; then echo "$CASA existe y es una carpeta real: muévela o bórrala antes de instalar." >&2; exit 1; fi
  rm -f "$CASA"; ln -s "$ROOT" "$CASA"; echo "~/.ps-steroids             -> $ROOT"
fi
chmod +x "$ROOT/bin/ps-cli.sh" 2>/dev/null || true

instalar() { # $1 nombre del agente, $2 carpeta base, $3 carpeta de skills
  if [ ! -d "$2" ]; then printf '%-24s no instalado, se omite\n' "$1"; return; fi
  [ "$UNINSTALL" = 1 ] || mkdir -p "$3"
  local n=0
  for s in "$ROOT"/skills/*/; do
    s="${s%/}"; link="$3/$(basename "$s")"
    if [ -e "$link" ] && [ ! -L "$link" ]; then printf '%-24s %s: existe una carpeta real, no se toca\n' "$1" "$(basename "$s")"; continue; fi
    rm -f "$link"   # quita solo el enlace, nunca el contenido
    [ "$UNINSTALL" = 1 ] || { ln -s "$s" "$link"; n=$((n + 1)); }
  done
  if [ "$UNINSTALL" = 1 ]; then printf '%-24s enlaces quitados (%s)\n' "$1" "$3"; else printf '%-24s %s skills enlazadas (%s)\n' "$1" "$n" "$3"; fi
}
instalar 'Claude Code'             "$HOME/.claude"             "$HOME/.claude/skills"
instalar 'Codex y otros (.agents)' "$HOME/.agents"             "$HOME/.agents/skills"
instalar 'OpenCode'                "$HOME/.config/opencode"    "$HOME/.config/opencode/skills"
instalar 'Antigravity'             "$HOME/.gemini/antigravity" "$HOME/.gemini/antigravity/skills"
[ "$UNINSTALL" = 1 ] || echo "ps-steroids instalado. Abre una sesión nueva en tu agente y pídele: «conecta con Photoshop»."
