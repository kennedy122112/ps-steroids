<#
  ps-cli.ps1 - puente local entre el agente y Adobe Photoshop en Windows (API COM + ExtendScript).
  Sin MCP, sin nube. En macOS el puente equivalente es ps-cli.sh; ambos ejecutan los mismos jsx/*.jsx.

  Uso:
    ps-cli.ps1 status                              # ¿Photoshop instalado/abierto? ¿qué documentos?
    ps-cli.ps1 open    -Path <imagen|psd> [-Launch] # abre un archivo
    ps-cli.ps1 read    [-Depth 4]                  # documento activo: tamaño, capas, textos, fuentes
    ps-cli.ps1 fonts   -Query <texto>              # busca fuentes instaladas (nombre PostScript)
    ps-cli.ps1 build   -Spec <spec.json> [-Launch] # crea un diseño por capas (documento nuevo o el activo)
    ps-cli.ps1 preview -Path <salida.png> [-MaxSize 1200]   # vista plana reducida para revisar
    ps-cli.ps1 export  -Path <salida.png|jpg|psd> [-Quality 90]
    ps-cli.ps1 jsx     -Script <archivo.jsx>       # ejecuta ExtendScript con los helpers de ps-cli
    ps-cli.ps1 inspect -Path <archivo.psd> [-Preview <salida.png>] [-Depth 4]  # lee un PSD SIN Photoshop (Python + psd-tools)

  -DryRun (comandos de Photoshop) escribe el ExtendScript generado en stdout sin tocar Photoshop.
  Toda salida es JSON por stdout.
#>
param(
  [Parameter(Position = 0)][string]$Command = 'status',
  [string]$Path,
  [string]$Spec,
  [string]$Script,
  [string]$Query,
  [string]$Preview,
  [int]$Depth = 4,
  [int]$Quality = 90,
  [int]$MaxSize = 1200,
  [switch]$Launch,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$JsxDir = Join-Path $PSScriptRoot 'jsx'

function Out-Json($obj) { ConvertTo-Json -InputObject $obj -Depth 12 }
function Fail($msg) { Out-Json @{ ok = $false; error = $msg }; exit 1 }
function Js-Str([string]$s) { ConvertTo-Json -InputObject $s -Compress }
function Read-Utf8($p) { [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) }

# Instalaciones de Photoshop registradas (no hace falta que esté abierto).
function Get-Installed {
  $found = @()
  foreach ($k in Get-ChildItem 'HKLM:\SOFTWARE\Adobe\Photoshop' -ErrorAction SilentlyContinue) {
    $p = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).ApplicationPath
    if ($p) {
      $exe = Join-Path $p 'Photoshop.exe'
      $ver = if (Test-Path $exe) { (Get-Item $exe).VersionInfo.ProductVersion } else { $null }
      $found += [ordered]@{ key = $k.PSChildName; path = $p; exists = (Test-Path $exe); version = $ver }
    }
  }
  if (-not $found) {
    foreach ($exe in Get-ChildItem 'C:\Program Files\Adobe\*\Photoshop.exe' -ErrorAction SilentlyContinue) {
      $found += [ordered]@{ key = $exe.Directory.Name; path = $exe.DirectoryName; exists = $true; version = $exe.VersionInfo.ProductVersion }
    }
  }
  return ,$found
}

function Get-App([switch]$Soft) {
  try { return [System.Runtime.InteropServices.Marshal]::GetActiveObject('Photoshop.Application') } catch { }
  if ($Launch) {
    try { return New-Object -ComObject 'Photoshop.Application' }
    catch { Fail "No se pudo iniciar Photoshop por COM: $($_.Exception.Message)" }
  }
  if ($Soft) { return $null }
  Fail 'Photoshop no está abierto. Ábrelo (o repite el comando con -Launch).'
}

function Invoke-Jsx($app, [string]$code) {
  $raw = $app.DoJavaScript($code)
  try { $null = $raw | ConvertFrom-Json; $raw } catch { Out-Json @{ ok = $false; error = 'Respuesta no válida de Photoshop'; raw = "$raw" } }
}
# Arma el código: variables de entrada + lib.jsx + el jsx del comando.
function Get-Code([string]$vars, [string]$name) {
  $vars + "`n" + (Read-Utf8 (Join-Path $JsxDir 'lib.jsx')) + "`n" + (Read-Utf8 (Join-Path $JsxDir "$name.jsx"))
}
function Run-Jsx([string]$vars, [string]$name) {
  $code = Get-Code $vars $name
  if ($DryRun) { $code; return }
  Invoke-Jsx (Get-App) $code
}
function Need-Path { if (-not $Path) { Fail "Falta -Path." } }

switch ($Command) {
  'status' {
    $inst = Get-Installed
    $app = if ($DryRun) { $null } else { Get-App -Soft }
    if ($DryRun) { Get-Code '' 'status'; break }
    if (-not $app) { Out-Json ([ordered]@{ ok = $true; running = $false; installed = $inst }); break }
    $o = (Invoke-Jsx $app (Get-Code '' 'status')) | ConvertFrom-Json
    $o | Add-Member running $true; $o | Add-Member installed $inst
    Out-Json $o
  }
  'open' {
    Need-Path
    $full = (Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue).Path
    if (-not $full) { Fail "No existe el archivo: $Path" }
    Run-Jsx "var P = $(Js-Str $full);" 'open'
  }
  'read' { Run-Jsx "var DEPTH = $Depth;" 'read' }
  'fonts' { Run-Jsx "var Q = $(Js-Str ([string]$Query).ToLower());" 'fonts' }
  'build' {
    if (-not $Spec) { Fail 'Falta -Spec <archivo.json>.' }
    if (-not (Test-Path -LiteralPath $Spec)) { Fail "No existe el spec: $Spec" }
    $specFull = (Resolve-Path -LiteralPath $Spec).Path
    $json = Read-Utf8 $specFull
    try { $null = $json | ConvertFrom-Json } catch { Fail "El spec no es JSON válido: $($_.Exception.Message)" }
    $json = $json -replace "[\u2028\u2029]", ' '
    Run-Jsx "var SPEC = $json;`nvar SPEC_DIR = $(Js-Str ((Split-Path -Parent $specFull) -replace '\\', '/'));" 'build'
  }
  'preview' {
    Need-Path
    Run-Jsx "var OUT = $(Js-Str ([IO.Path]::GetFullPath($Path))), MAX = $MaxSize;" 'preview'
  }
  'export' {
    Need-Path
    $out = [IO.Path]::GetFullPath($Path)
    $fmt = [IO.Path]::GetExtension($out).TrimStart('.').ToLower()
    if ($fmt -notin 'png', 'jpg', 'jpeg', 'psd') { Fail "Formato no soportado: .$fmt (usa png, jpg o psd)." }
    if (-not $DryRun) { New-Item -ItemType Directory -Force (Split-Path -Parent $out) | Out-Null }
    Run-Jsx "var OUT = $(Js-Str $out), FMT = '$fmt', Q = $Quality;" 'export'
  }
  'jsx' {
    if (-not $Script) { Fail 'Falta -Script <archivo.jsx>.' }
    if (-not (Test-Path -LiteralPath $Script)) { Fail "No existe el script: $Script" }
    $code = (Read-Utf8 (Join-Path $JsxDir 'lib.jsx')) + "`n" + (Read-Utf8 (Resolve-Path -LiteralPath $Script).Path)
    if ($DryRun) { $code } else { Invoke-Jsx (Get-App) $code }
  }
  'inspect' {
    Need-Path
    $py = Get-Command python, py -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $py) { Fail 'inspect necesita Python 3 (python.org o la Microsoft Store) y psd-tools: pip install psd-tools' }
    $a = @((Join-Path $PSScriptRoot 'psd_read.py'), $Path, '--depth', $Depth)
    if ($Preview) { $a += @('--preview', $Preview) }
    & $py.Source @a
    exit $LASTEXITCODE
  }
  default { Fail "Comando desconocido: $Command (status, open, read, fonts, build, preview, export, jsx, inspect)" }
}
