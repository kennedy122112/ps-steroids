# ps-steroids

**Cuéntale tu idea o pásale tus fotos. Tu agente de IA diseña en Adobe Photoshop: documentos reales, por capas y editables.**
Gratis y de código abierto. Local, sin MCP y sin API key.

<sub>Proyecto independiente, no afiliado a Adobe. Adobe y Photoshop son marcas de sus respectivos titulares.</sub>

---

## ✨ Qué es

**ps-steroids** es un conjunto de *skills* que le enseñan a tu asistente de IA (Claude Code, Codex,
OpenCode, Antigravity) a trabajar en **Adobe Photoshop** abierto en tu PC:

- 🎨 **Diseña** posts, stories, banners, flyers y portadas a partir de lo que describes por chat.
- 🖼️ **Compone con tus imágenes**: las coloca como objetos inteligentes, recorta, quita el fondo, ajusta color.
- ✏️ **Edita** fotos y plantillas PSD: cambia textos por nombre de capa, pone logo o marca de agua y saca la pieza en varios tamaños.
- 🔍 **Lee y audita** PSD: capas, textos, fuentes que faltan, problemas. También **sin Photoshop** (Python + psd-tools).
- 👀 **Revisa su propio trabajo**: saca una vista previa, la mira y corrige antes de entregártelo.

Todo queda en capas con nombre (formas vectoriales, texto editable, objetos inteligentes, capas de ajuste),
y cada diseño es un paso del historial: Ctrl+Z lo deshace.

## 🧩 Skills

| Skill | Para qué |
|---|---|
| `ps-setup` | Primer arranque: comprueba Photoshop, la versión y el puente COM |
| `ps-connect` | Conecta con Photoshop abierto y fija el documento de trabajo |
| `ps-design` | Diseña piezas nuevas desde una idea o desde tus imágenes |
| `ps-edit` | Edita imágenes y plantillas existentes |
| `ps-read` | Lee, explica y audita un PSD |

## ⚙️ Cómo funciona

El agente describe el diseño en un **spec JSON** (capas de abajo hacia arriba) y `ps-cli build` lo
construye dentro de Photoshop con ExtendScript. El trabajo lo hacen los scripts de `bin/jsx/`,
iguales en los dos sistemas; cambia solo el puente, y ninguno necesita instalar nada:

| Sistema | Puente | Cómo habla con Photoshop |
|---|---|---|
| Windows | `bin/ps-cli.ps1` (PowerShell) | API COM `Photoshop.Application` |
| macOS | `bin/ps-cli.sh` (bash) | AppleScript `do javascript` (`osascript`) |

```
ps-cli status | open | read | fonts | build | preview | export | jsx | inspect
```

`inspect` lee PSD sin Photoshop (`bin/psd_read.py`, requiere Python 3 y `pip install psd-tools`).

Ejemplo de spec: [examples/post-evento/spec.json](examples/post-evento/spec.json).

## 📦 Instalación

Requisitos: Adobe Photoshop 2021 (v22) o posterior, en Windows o macOS.

**Windows** (PowerShell):
```powershell
irm https://raw.githubusercontent.com/kennedy122112/ps-steroids/main/install.ps1 | iex
```

**macOS** (Terminal):
```bash
curl -fsSL https://raw.githubusercontent.com/kennedy122112/ps-steroids/main/install.sh | bash
```

Abre una sesión nueva en tu agente y pídele: «conecta con Photoshop». En Mac, la primera vez el sistema
pregunta si el agente puede controlar Photoshop: responde **Aceptar**.

## Límites

- No genera fotos ni ilustraciones nuevas: compone con tus imágenes, formas, degradados y tipografía.
- Generative Fill y otras funciones de Firefly no se pueden usar desde ExtendScript.
- Usa las fuentes instaladas en tu PC; si falta una, avisa y la sustituye.

Licencia MIT.
