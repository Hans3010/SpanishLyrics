<#
.SYNOPSIS
    Crea una página (canciones-oficiales.html) con las canciones oficiales y links para buscar su traducción.

.DESCRIPTION
    Usa las planillas "lp_" de la carpeta plantillas (ejecuta antes Crear-Plantillas.ps1).
    Marca como traducidas las canciones que ya tienen planilla en la carpeta traducciones.
#>
param(
    [string]$Plantillas = '',
    [string]$Traducciones = '',
    [string]$Salida = ''
)

$ErrorActionPreference = 'Stop'
if (-not $Plantillas) { $Plantillas = Join-Path $PSScriptRoot '..\plantillas' }
if (-not $Traducciones) { $Traducciones = Join-Path $PSScriptRoot '..\traducciones' }
if (-not $Salida) { $Salida = Join-Path $PSScriptRoot '..\canciones-oficiales.html' }

Add-Type -AssemblyName System.Web
function Enc([string]$s) { [System.Web.HttpUtility]::UrlEncode($s) }
function Html([string]$s) { [System.Web.HttpUtility]::HtmlEncode($s) }

$traducidas = @{}
if (Test-Path -LiteralPath $Traducciones) {
    Get-ChildItem -LiteralPath $Traducciones -Filter 'lp_*.csv' | ForEach-Object {
        if ($_.Name -match '^lp_(\d+)') { $traducidas[$matches[1]] = $true }
    }
}

$canciones = Get-ChildItem -LiteralPath $Plantillas -Filter 'lp_*.csv' | ForEach-Object {
    if ($_.BaseName -match '^lp_(\d+)(?: - (.+))?$') {
        $primera = Import-Csv -LiteralPath $_.FullName -Encoding UTF8 | Select-Object -First 1
        $nombre = if ($primera.cancion) { $primera.cancion } elseif ($matches[2]) { $matches[2] } else { "Canción $($matches[1])" }
        [pscustomobject]@{ Id = [int]$matches[1]; Nombre = $nombre; Archivo = $_.Name; Traducida = $traducidas.ContainsKey($matches[1]) }
    }
} | Sort-Object Nombre

$filas = foreach ($c in $canciones) {
    $q = Enc $c.Nombre
    $estado = if ($c.Traducida) { '<span class="ok">✔ traducida</span>' } else { '' }
    @"
<tr data-n="$(Html $c.Nombre.ToLower())">
  <td class="id">$($c.Id)</td>
  <td class="name">$(Html $c.Nombre) $estado<div class="file">$(Html $c.Archivo)</div></td>
  <td class="links">
    <a href="https://www.google.com/search?q=$q+letra+traducida+al+espa%C3%B1ol" target="_blank" rel="noopener">Google: letra en español</a>
    <a href="https://www.youtube.com/results?search_query=$q+sub+espa%C3%B1ol" target="_blank" rel="noopener">YouTube: sub español</a>
    <a href="https://vocadb.net/Search?searchType=Song&amp;filter=$q" target="_blank" rel="noopener">VocaDB</a>
    <a href="https://vocaloidlyrics.fandom.com/wiki/Special:Search?query=$q" target="_blank" rel="noopener">Vocaloid Lyrics Wiki</a>
  </td>
</tr>
"@
}

$total = @($canciones).Count
$hechas = @($canciones | Where-Object Traducida).Count

$html = @"
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Canciones oficiales</title>
<style>
:root { --bg:#f7f7f8; --card:#fff; --fg:#1d1d1f; --muted:#6e6e73; --line:#e3e3e6; --accent:#0f9d9a; --ok:#1a7f37; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg:#141416; --card:#1d1d20; --fg:#ececf0; --muted:#9a9aa3; --line:#2c2c31; --accent:#3edcd0; --ok:#4cc26b; } }
:root[data-theme="dark"] { --bg:#141416; --card:#1d1d20; --fg:#ececf0; --muted:#9a9aa3; --line:#2c2c31; --accent:#3edcd0; --ok:#4cc26b; }
* { box-sizing:border-box; }
body { margin:0; background:var(--bg); color:var(--fg); font:15px/1.45 system-ui,-apple-system,"Segoe UI",sans-serif; }
main { max-width:1000px; margin:0 auto; padding:24px 16px 48px; }
h1 { font-size:22px; margin:0 0 4px; }
p { color:var(--muted); margin:0 0 16px; }
input { width:100%; padding:10px 12px; font-size:15px; border:1px solid var(--line); border-radius:8px; background:var(--card); color:var(--fg); margin-bottom:12px; }
table { width:100%; border-collapse:collapse; background:var(--card); border:1px solid var(--line); border-radius:10px; overflow:hidden; }
td { padding:10px 12px; border-top:1px solid var(--line); vertical-align:top; }
tr:first-child td { border-top:none; }
.id { color:var(--muted); font-variant-numeric:tabular-nums; width:56px; }
.name { font-weight:600; }
.file { font-weight:400; font-size:12px; color:var(--muted); margin-top:2px; word-break:break-all; }
.links a { display:inline-block; margin:0 10px 4px 0; color:var(--accent); text-decoration:none; font-size:14px; }
.links a:hover { text-decoration:underline; }
.ok { color:var(--ok); font-size:12px; font-weight:600; margin-left:6px; }
@media (max-width:600px) { .id { display:none; } .links a { display:block; } }
</style>
</head>
<body>
<main>
<h1>Canciones oficiales ($total)</h1>
<p>$hechas traducidas. Links de búsqueda para encontrar traducciones; la planilla de cada canción está en la carpeta <code>plantillas</code>.</p>
<input id="q" type="search" placeholder="Buscar canción…" autocomplete="off">
<table><tbody id="t">
$($filas -join "`n")
</tbody></table>
</main>
<script>
document.getElementById('q').addEventListener('input', function (e) {
  var v = e.target.value.trim().toLowerCase();
  document.querySelectorAll('#t tr').forEach(function (r) { r.style.display = !v || r.dataset.n.indexOf(v) >= 0 ? '' : 'none'; });
});
</script>
</body>
</html>
"@

[System.IO.File]::WriteAllText((Resolve-Path (Split-Path $Salida)).Path + '\' + (Split-Path $Salida -Leaf), $html, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Lista creada: $Salida ($total canciones, $hechas traducidas)"
