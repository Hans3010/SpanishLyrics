<#
.SYNOPSIS
    Revisa qué canciones instaladas tienen letras en español y crea estado-traducciones.html.

.DESCRIPTION
    Para cada canción con letras de los mods instalados revisa:
      - Canciones oficiales (LyricsPatch): si existe lyrics\<id>_sp.toml en algún mod.
      - Canciones de packs: las líneas lyric_en que el juego en español va a usar (rom_steam_sp del mod
        "Spanish Lyrics" o del propio pack) y cuántas son distintas del japonés/inglés original.
#>
param(
    [Parameter(Mandatory = $true)][string]$CarpetaJuego,
    [string]$NombreModEspanol = 'Spanish Lyrics',
    [string]$Salida = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Comun.ps1')
if (-not $Salida) { $Salida = Join-Path $PSScriptRoot '..\estado-traducciones.html' }
Add-Type -AssemblyName System.Web

$mods = Get-CarpetaMods $CarpetaJuego
$dirs = Get-ChildItem -LiteralPath $mods -Directory
$resultado = New-Object System.Collections.Generic.List[object]

# Entradas en español (rom_steam_sp): primero el mod Spanish Lyrics, después los packs
$sp = @{}
$fuentesSp = @($dirs | Where-Object { $_.Name -eq $NombreModEspanol }) + @($dirs | Where-Object { $_.Name -ne $NombreModEspanol })
foreach ($d in $fuentesSp) {
    $ruta = Join-Path $d.FullName 'rom_steam_sp\rom\mod_pv_db.txt'
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    $db = Read-PvDb $ruta
    foreach ($k in $db.Keys) { if (-not $sp.Contains($k)) { $sp[$k] = $db[$k] } }
}

# Canciones de packs
foreach ($d in ($dirs | Where-Object { $_.Name -ne $NombreModEspanol })) {
    $ruta = Join-Path $d.FullName 'rom\mod_pv_db.txt'
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    $db = Read-PvDb $ruta
    $enRuta = Join-Path $d.FullName 'rom_steam_en\rom\mod_pv_db.txt'
    $en = if (Test-Path -LiteralPath $enRuta) { Read-PvDb $enRuta } else { $null }
    $lineas = @{}
    foreach ($k in $db.Keys) { if ($k -match '^pv_(\d+)\.lyric\.(\d+)$') { if (-not $lineas[$matches[1]]) { $lineas[$matches[1]] = @() }; $lineas[$matches[1]] += $matches[2] } }
    foreach ($id in $lineas.Keys) {
        $total = 0; $espanol = 0
        foreach ($n in $lineas[$id]) {
            $jp = $db["pv_$id.lyric.$n"]
            if (-not $jp) { continue }
            $total++
            $claveEn = "pv_$id.lyric_en.$n"
            $valorSp = $sp[$claveEn]
            $original = if ($en -and $en.Contains($claveEn)) { $en[$claveEn] } else { $db[$claveEn] }
            if ($valorSp -and $valorSp -ne $original -and $valorSp -ne $jp) { $espanol++ }
        }
        if ($total -eq 0) { continue }
        $nombre = $db["pv_$id.song_name_en"]; if (-not $nombre) { $nombre = $db["pv_$id.song_name"] }
        $tieneIngles = [bool]($en -and $en.Contains("pv_$id.song_name"))
        $resultado.Add([pscustomobject]@{ Tipo = 'pack'; Id = [int]$id; Cancion = $nombre; Mod = $d.Name; Lineas = $total; Espanol = $espanol; Ingles = $tieneIngles })
    }
}

# Canciones oficiales (LyricsPatch)
$conSp = @{}
foreach ($d in $dirs) {
    $l = Join-Path $d.FullName 'lyrics'
    if (Test-Path -LiteralPath $l) { Get-ChildItem -LiteralPath $l -Filter '*_sp.toml' | ForEach-Object { $conSp[($_.BaseName -replace '_sp$', '')] = $true } }
}
foreach ($d in ($dirs | Where-Object { $_.Name -ne $NombreModEspanol })) {
    $l = Join-Path $d.FullName 'lyrics'
    if (-not (Test-Path -LiteralPath $l)) { continue }
    foreach ($f in (Get-ChildItem -LiteralPath $l -Filter '*.toml' | Where-Object { $_.BaseName -match '^\d+$' })) {
        $n = @(Read-LyricsPatchToml $f.FullName | Where-Object { $_.Texto }).Count
        $resultado.Add([pscustomobject]@{ Tipo = 'oficial'; Id = [int]$f.BaseName; Cancion = (Get-NombreDesdeToml $f.FullName); Mod = $d.Name; Lineas = $n; Espanol = $(if ($conSp[$f.BaseName]) { $n } else { 0 }); Ingles = $false })
    }
}

# Canciones con letras en español por LyricsPatch que no están en la lista anterior
# (por ejemplo, las importadas desde subtítulos con Importar-Subtitulos.ps1)
$ids = @{}
foreach ($r in $resultado) {
    $ids[[string]$r.Id] = $true
    # Una canción de pack también cuenta como traducida si tiene su archivo _sp.toml
    if ($r.Tipo -eq 'pack' -and $conSp[[string]$r.Id]) { $r.Espanol = $r.Lineas }
}
foreach ($d in $dirs) {
    $l = Join-Path $d.FullName 'lyrics'
    if (-not (Test-Path -LiteralPath $l)) { continue }
    foreach ($f in Get-ChildItem -LiteralPath $l -Filter '*_sp.toml') {
        $id = $f.BaseName -replace '_sp$', ''
        if ($ids[$id] -or $id -notmatch '^\d+$') { continue }
        $ids[$id] = $true
        $n = @(Read-LyricsPatchToml $f.FullName | Where-Object { $_.Texto }).Count
        $nombre = (Get-NombreDesdeToml $f.FullName) -replace '^Spanish Lyrics - ', ''
        $resultado.Add([pscustomobject]@{ Tipo = 'subtítulos'; Id = [int]$id; Cancion = $nombre; Mod = $d.Name; Lineas = $n; Espanol = $n; Ingles = $false })
    }
}

function Estado($r) {
    if ($r.Espanol -ge $r.Lineas * 0.9) { return 'traducida' }
    if ($r.Espanol -gt 0) { return 'parcial' }
    return 'pendiente'
}

$filas = foreach ($r in ($resultado | Sort-Object Tipo, Mod, Cancion)) {
    $e = Estado $r
    $etiqueta = @{ traducida = '✔ Traducida'; parcial = '◐ Parcial'; pendiente = '✖ Pendiente' }[$e]
    $nota = if ($r.Tipo -eq 'pack' -and -not $r.Ingles -and $e -ne 'traducida') { 'sin inglés de referencia' } else { '' }
    "<tr class=`"$e`" data-n=`"$([System.Web.HttpUtility]::HtmlEncode(($r.Cancion + ' ' + $r.Mod).ToLower()))`"><td>$etiqueta</td><td><b>$([System.Web.HttpUtility]::HtmlEncode($r.Cancion))</b><div class=`"sub`">$([System.Web.HttpUtility]::HtmlEncode($r.Mod)) · pv_$($r.Id) · $($r.Tipo)</div></td><td class=`"num`">$($r.Espanol)/$($r.Lineas)</td><td class=`"sub`">$nota</td></tr>"
}

$cuenta = $resultado | Group-Object { Estado $_ } | ForEach-Object { @{ $_.Name = $_.Count } }
$c = @{ traducida = 0; parcial = 0; pendiente = 0 }; foreach ($x in $cuenta) { foreach ($k in $x.Keys) { $c[$k] = $x[$k] } }

$html = @"
<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Estado de traducciones</title>
<style>
:root{--bg:#f7f7f8;--card:#fff;--fg:#1d1d1f;--muted:#6e6e73;--line:#e3e3e6;--ok:#1a7f37;--mid:#9a6700;--no:#c4314b}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#141416;--card:#1d1d20;--fg:#ececf0;--muted:#9a9aa3;--line:#2c2c31;--ok:#4cc26b;--mid:#e3b341;--no:#ff7b8a}}
:root[data-theme="dark"]{--bg:#141416;--card:#1d1d20;--fg:#ececf0;--muted:#9a9aa3;--line:#2c2c31;--ok:#4cc26b;--mid:#e3b341;--no:#ff7b8a}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.45 system-ui,"Segoe UI",sans-serif}
main{max-width:1000px;margin:0 auto;padding:24px 16px 48px}h1{font-size:22px;margin:0 0 8px}
.chips{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 12px}.chips button{border:1px solid var(--line);background:var(--card);color:var(--fg);border-radius:999px;padding:6px 12px;cursor:pointer;font-size:14px}
.chips button.on{border-color:var(--fg)}input{width:100%;padding:10px 12px;font-size:15px;border:1px solid var(--line);border-radius:8px;background:var(--card);color:var(--fg);margin-bottom:12px}
table{width:100%;border-collapse:collapse;background:var(--card);border:1px solid var(--line);border-radius:10px;overflow:hidden}
td{padding:9px 12px;border-top:1px solid var(--line);vertical-align:top}tr:first-child td{border-top:none}
.sub{font-size:12px;color:var(--muted)}.num{font-variant-numeric:tabular-nums;text-align:right;white-space:nowrap}
tr.traducida td:first-child{color:var(--ok)}tr.parcial td:first-child{color:var(--mid)}tr.pendiente td:first-child{color:var(--no)}td:first-child{white-space:nowrap;font-weight:600;font-size:13px}
</style></head><body><main>
<h1>Estado de traducciones al español</h1>
<div class="chips">
<button data-f="" class="on">Todas ($($resultado.Count))</button>
<button data-f="traducida">✔ Traducidas ($($c.traducida))</button>
<button data-f="parcial">◐ Parciales ($($c.parcial))</button>
<button data-f="pendiente">✖ Pendientes ($($c.pendiente))</button>
</div>
<input id="q" type="search" placeholder="Buscar canción o pack…" autocomplete="off">
<table><tbody id="t">
$($filas -join "`n")
</tbody></table></main>
<script>
var f='',q='';function u(){document.querySelectorAll('#t tr').forEach(function(r){r.style.display=(!f||r.classList.contains(f))&&(!q||r.dataset.n.indexOf(q)>=0)?'':'none'})}
document.querySelectorAll('.chips button').forEach(function(b){b.onclick=function(){document.querySelectorAll('.chips button').forEach(function(x){x.classList.remove('on')});b.classList.add('on');f=b.dataset.f;u()}});
document.getElementById('q').oninput=function(e){q=e.target.value.trim().toLowerCase();u()};
</script></body></html>
"@
$destino = Join-Path (Resolve-Path (Split-Path $Salida)).Path (Split-Path $Salida -Leaf)
[System.IO.File]::WriteAllText($destino, $html, $Utf8SinBom)

Write-Host "Estado: $($c.traducida) traducidas, $($c.parcial) parciales, $($c.pendiente) pendientes"
foreach ($g in ($resultado | Group-Object Tipo, Mod | Sort-Object Name)) {
    $t = @($g.Group | Where-Object { (Estado $_) -eq 'traducida' }).Count
    $p = @($g.Group | Where-Object { (Estado $_) -eq 'parcial' }).Count
    Write-Host ("  {0}: {1}/{2} traducidas, {3} parciales" -f $g.Name, $t, $g.Count, $p)
}
Write-Host "Detalle: $destino"
