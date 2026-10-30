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
- 🔍 **Lee y audita** PSD: capas, textos, fuentes que faltan, problemas.
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

`bin/ps-cli.ps1` es un puente PowerShell sin dependencias. Habla con Photoshop por su API COM
(`Photoshop.Application`) y ejecuta ExtendScript dentro de Photoshop. El agente describe el diseño
en un **spec JSON** (capas de abajo hacia arriba) y `ps-cli build` lo construye.

```
ps-cli status | open | read | fonts | build | preview | export | jsx
```

Ejemplo de spec: [examples/post-evento/spec.json](examples/post-evento/spec.json).

## 📦 Instalación

Requisitos: Windows, Adobe Photoshop 2021 (v22) o posterior.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

Abre una sesión nueva en tu agente y pídele: «conecta con Photoshop».

## Límites

- No genera fotos ni ilustraciones nuevas: compone con tus imágenes, formas, degradados y tipografía.
- Generative Fill y otras funciones de Firefly no se pueden usar desde ExtendScript.
- Usa las fuentes instaladas en tu PC; si falta una, avisa y la sustituye.

Licencia MIT.
