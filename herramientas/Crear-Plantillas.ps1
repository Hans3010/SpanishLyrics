<#
.SYNOPSIS
    Crea una planilla de traducción (CSV) por canción a partir de las letras que ya tienes instaladas.

.DESCRIPTION
    Busca letras en dos lugares:
      - Carpetas "lyrics" de los mods (formato LyricsPatch): canciones oficiales del juego.
        Toma el japonés de <id>_jp.toml y el romaji de <id>.toml, con sus tiempos.
      - Archivos rom\mod_pv_db.txt de los packs de canciones: toma el japonés (lyric) y el inglés (lyric_en).
    Cada planilla tiene una columna "espanol" vacía para escribir la traducción.

    Las planillas contienen las letras originales, que tienen derechos de autor: son solo para trabajar
    en tu PC. Para compartir traducciones, usa el CSV con la columna "espanol" (ver README).

.EXAMPLE
    .\Crear-Plantillas.ps1 -CarpetaJuego "D:\SteamLibrary\steamapps\common\Hatsune Miku Project DIVA Mega Mix Plus"
#>
param(
    [Parameter(Mandatory = $true)][string]$CarpetaJuego,
    [string]$Salida = '',
    [string]$NombreModEspanol = 'Spanish Lyrics'
)

$ErrorActionPreference = 'Stop'
if (-not $Salida) { $Salida = Join-Path $PSScriptRoot '..\plantillas' }
. (Join-Path $PSScriptRoot 'Comun.ps1')

$mods = Get-CarpetaMods $CarpetaJuego
New-Item -ItemType Directory -Force -Path $Salida | Out-Null
$Salida = (Resolve-Path $Salida).Path

function Get-NombreArchivo {
    param([string]$Tipo, [string]$PvId, [string]$Cancion)
    $limpio = ($Cancion -replace '[\\/:*?"<>|]', '').Trim()
    if ($limpio.Length -gt 60) { $limpio = $limpio.Substring(0, 60).Trim() }
    if ($limpio) { return "$Tipo`_$PvId - $limpio.csv" }
    return "$Tipo`_$PvId.csv"
}

function Save-Planilla {
    param($Filas, [string]$Archivo)
    $Filas | Select-Object $ColumnasCsv | Export-Csv -LiteralPath $Archivo -NoTypeInformation -Encoding UTF8
}

$totalCanciones = 0
$totalLineas = 0
$modsLeidos = Get-ChildItem -LiteralPath $mods -Directory | Where-Object { $_.Name -ne $NombreModEspanol }

# 1) Canciones con archivos de LyricsPatch
$porId = @{}
foreach ($mod in $modsLeidos) {
    $dir = Join-Path $mod.FullName 'lyrics'
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.toml') {
        if ($f.BaseName -match '^(\d+)(_jp)?$') {
            $id = $matches[1]
            if (-not $porId.ContainsKey($id)) { $porId[$id] = @{ Mod = $mod.Name } }
            if ($matches[2]) { $porId[$id].Jp = $f.FullName } else { $porId[$id].Romaji = $f.FullName }
        }
    }
}
foreach ($id in ($porId.Keys | Sort-Object { [int]$_ })) {
    $info = $porId[$id]
    $romaji = @(); $jp = @()
    if ($info.Romaji) { $romaji = @(Read-LyricsPatchToml $info.Romaji) }
    if ($info.Jp) { $jp = @(Read-LyricsPatchToml $info.Jp) }
    $base = if ($romaji.Count -ge $jp.Count) { $romaji } else { $jp }
    if ($base.Count -eq 0) { continue }
    $nombre = if ($info.Romaji) { Get-NombreDesdeToml $info.Romaji } else { Get-NombreDesdeToml $info.Jp }

    $filas = for ($i = 0; $i -lt $base.Count; $i++) {
        [pscustomobject]@{
            tipo    = 'lp'
            pv_id   = $id
            cancion = $nombre
            mod     = $info.Mod
            linea   = $i + 1
            tiempo  = $base[$i].Tiempo
            japones = $(if ($i -lt $jp.Count) { $jp[$i].Texto } else { '' })
            romaji  = $(if ($i -lt $romaji.Count) { $romaji[$i].Texto } else { '' })
            ingles  = ''
            espanol = ''
        }
    }
    Save-Planilla $filas (Join-Path $Salida (Get-NombreArchivo 'lp' $id $nombre))
    $totalCanciones++; $totalLineas += $base.Count
}

# 2) Canciones de packs (mod_pv_db.txt)
foreach ($mod in $modsLeidos) {
    $pvdbRuta = Join-Path $mod.FullName 'rom\mod_pv_db.txt'
    if (-not (Test-Path -LiteralPath $pvdbRuta)) { continue }
    $pvdb = Read-PvDb $pvdbRuta
    # Si el pack trae su propio archivo en inglés, se usa para la columna "ingles"
    $enRuta = Join-Path $mod.FullName 'rom_steam_en\rom\mod_pv_db.txt'
    $en = if (Test-Path -LiteralPath $enRuta) { Read-PvDb $enRuta } else { $null }

    $porCancion = @{}
    foreach ($clave in $pvdb.Keys) {
        if ($clave -match '^pv_(\d+)\.lyric\.(\d+)$') {
            $id = $matches[1]
            if (-not $porCancion.ContainsKey($id)) { $porCancion[$id] = New-Object System.Collections.Generic.List[string] }
            $porCancion[$id].Add($matches[2])
        }
    }
    foreach ($id in ($porCancion.Keys | Sort-Object { [int]$_ })) {
        $nombre = $pvdb["pv_$id.song_name_en"]
        if (-not $nombre) { $nombre = $pvdb["pv_$id.song_name"] }
        $filas = foreach ($n in ($porCancion[$id] | Sort-Object { [int]$_ })) {
            $claveEn = "pv_$id.lyric_en.$n"
            $ingles = $null
            if ($en -and $en.Contains($claveEn)) { $ingles = $en[$claveEn] } elseif ($pvdb.Contains($claveEn)) { $ingles = $pvdb[$claveEn] }
            [pscustomobject]@{
                tipo    = 'pvdb'
                pv_id   = $id
                cancion = $nombre
                mod     = $mod.Name
                linea   = $n
                tiempo  = ''
                japones = $pvdb["pv_$id.lyric.$n"]
                romaji  = ''
                ingles  = $ingles
                espanol = ''
            }
        }
        Save-Planilla $filas (Join-Path $Salida (Get-NombreArchivo 'pvdb' $id $nombre))
        $totalCanciones++; $totalLineas += @($filas).Count
    }
}

Write-Host "Listo: $totalCanciones planillas ($totalLineas líneas) en $Salida"
Write-Host "Copia a la carpeta 'traducciones' las que vayas a traducir y completa la columna 'espanol'."
