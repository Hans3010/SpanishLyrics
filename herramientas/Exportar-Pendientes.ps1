<#
.SYNOPSIS
    Copia a la carpeta "para-traducir\<pack>" las planillas de las canciones de un pack que todavía no están en español.

.EXAMPLE
    .\Exportar-Pendientes.ps1 -CarpetaJuego $juego -Pack "Nitori's Song Pack"
#>
param(
    [Parameter(Mandatory = $true)][string]$CarpetaJuego,
    [Parameter(Mandatory = $true)][string]$Pack,
    [string]$NombreModEspanol = 'Spanish Lyrics'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Comun.ps1')

$raiz = Split-Path $PSScriptRoot
$plantillas = Join-Path $raiz 'plantillas'
$traducciones = Join-Path $raiz 'traducciones'
$mods = Get-CarpetaMods $CarpetaJuego
$dirPack = Join-Path $mods $Pack
if (-not (Test-Path -LiteralPath $dirPack)) { throw "No existe el pack: $dirPack" }

# Líneas en español que el juego va a usar: mod Spanish Lyrics primero, después el propio pack
$sp = @{}
foreach ($ruta in @((Join-Path $mods "$NombreModEspanol\rom_steam_sp\rom\mod_pv_db.txt"), (Join-Path $dirPack 'rom_steam_sp\rom\mod_pv_db.txt'))) {
    if (Test-Path -LiteralPath $ruta) { $db = Read-PvDb $ruta; foreach ($k in $db.Keys) { if (-not $sp.ContainsKey($k)) { $sp[$k] = $db[$k] } } }
}
$base = Read-PvDb (Join-Path $dirPack 'rom\mod_pv_db.txt')
$enRuta = Join-Path $dirPack 'rom_steam_en\rom\mod_pv_db.txt'
$en = if (Test-Path -LiteralPath $enRuta) { Read-PvDb $enRuta } else { @{} }

$destino = Join-Path $raiz "para-traducir\$Pack"
New-Item -ItemType Directory -Force -Path $destino | Out-Null
Get-ChildItem -LiteralPath $destino -Filter '*.csv' | ForEach-Object { [System.IO.File]::Delete($_.FullName) }

$copiadas = 0; $sinIngles = 0
foreach ($f in Get-ChildItem -LiteralPath $plantillas -Filter 'pvdb_*.csv') {
    $filas = @(Import-Csv -LiteralPath $f.FullName -Encoding UTF8)
    if (-not $filas -or $filas[0].mod -ne $Pack) { continue }
    $id = $filas[0].pv_id
    if (Test-Path -LiteralPath (Join-Path $traducciones $f.Name)) { continue }

    $total = 0; $espanol = 0
    foreach ($k in $base.Keys) {
        if ($k -notmatch "^pv_$id\.lyric\.(\d+)$") { continue }
        $total++
        $claveEn = "pv_$id.lyric_en.$($matches[1])"
        $original = if ($en.Contains($claveEn)) { $en[$claveEn] } else { $base[$claveEn] }
        if ($sp.ContainsKey($claveEn) -and $sp[$claveEn] -ne $original -and $sp[$claveEn] -ne $base[$k]) { $espanol++ }
    }
    if ($total -gt 0 -and $espanol -ge $total * 0.9) { continue }

    [System.IO.File]::Copy($f.FullName, (Join-Path $destino $f.Name), $true)
    $copiadas++
    if (-not ($filas | Where-Object { $_.ingles })) { $sinIngles++ }
}

Write-Host "$copiadas planillas pendientes copiadas a: $destino"
if ($sinIngles) { Write-Host "  $sinIngles no tienen inglés de referencia (solo japonés)." }
