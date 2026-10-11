<#
.SYNOPSIS
    Genera el mod "Spanish Lyrics" a partir de las planillas traducidas de la carpeta "traducciones".

.DESCRIPTION
    - Canciones "lp" (oficiales, formato LyricsPatch): crea lyrics\<id>_<sufijo>.toml.
      Los tiempos se toman del archivo original instalado, no del CSV, porque Excel suele
      cambiar el formato de los tiempos al guardar.
    - Canciones "pvdb" (packs): copia la entrada completa de la canción desde el pack original y
      reemplaza las líneas lyric_en por el español, en rom_steam_sp\rom\mod_pv_db.txt
      (la carpeta que usa el juego cuando está en español).
    - Canciones "sub" (de Importar-Subtitulos.ps1): crea lyrics\<id>_<sufijo>.toml con los tiempos de la planilla.
    Las líneas sin traducir quedan vacías (lp) o con el texto que ya tenía el pack (pvdb).

.EXAMPLE
    .\Construir-Mod.ps1 -CarpetaJuego "D:\SteamLibrary\steamapps\common\Hatsune Miku Project DIVA Mega Mix Plus" -Instalar
#>
param(
    [Parameter(Mandatory = $true)][string]$CarpetaJuego,
    [string]$Traducciones = '',
    [string]$Salida = '',
    [string]$NombreMod = 'Spanish Lyrics',
    # Terminación de los archivos de LyricsPatch para el idioma español (ver README, "Idioma en LyricsPatch")
    [string]$SufijoIdioma = 'sp',
    # Copia el mod generado a la carpeta mods del juego
    [switch]$Instalar
)

$ErrorActionPreference = 'Stop'
if (-not $Traducciones) { $Traducciones = Join-Path $PSScriptRoot '..\traducciones' }
if (-not $Salida) { $Salida = Join-Path $PSScriptRoot '..\dist' }
. (Join-Path $PSScriptRoot 'Comun.ps1')

$mods = Get-CarpetaMods $CarpetaJuego
if (-not (Test-Path -LiteralPath $Traducciones)) { throw "No existe la carpeta de traducciones: $Traducciones" }

$destino = Join-Path $Salida $NombreMod
if (Test-Path -LiteralPath $destino) { Remove-Item -LiteralPath $destino -Recurse -Force }
New-Item -ItemType Directory -Force -Path $destino | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\mod\config.toml') -Destination $destino
$leeme = Join-Path $PSScriptRoot '..\mod\LEEME.txt'
if (Test-Path -LiteralPath $leeme) { Copy-Item -LiteralPath $leeme -Destination $destino }
# OpenLyricLimit (korenkonder, MIT): sube el límite del juego de 150 a 1000 líneas de letra por canción
foreach ($extra in @('OpenLyricLimit.dll', 'LICENSE-OpenLyricLimit.txt')) {
    $ruta = Join-Path $PSScriptRoot "..\mod\$extra"
    if (Test-Path -LiteralPath $ruta) { Copy-Item -LiteralPath $ruta -Destination $destino }
}

# Busca el archivo de letras original (para tomar los tiempos) en las carpetas lyrics de los mods
function Find-LyricsOriginal {
    param([string]$PvId, [string]$ModPreferido)
    $candidatos = @()
    if ($ModPreferido) { $candidatos += Join-Path $mods $ModPreferido }
    $candidatos += Get-ChildItem -LiteralPath $mods -Directory | Where-Object { $_.Name -ne $NombreMod } | ForEach-Object { $_.FullName }
    foreach ($c in $candidatos) {
        foreach ($nombre in @("$PvId.toml", "$PvId`_jp.toml")) {
            $ruta = Join-Path $c "lyrics\$nombre"
            if (Test-Path -LiteralPath $ruta) { return $ruta }
        }
    }
    return $null
}

function Find-PvDbOriginal {
    param([string]$PvId, [string]$ModPreferido)
    $candidatos = @()
    if ($ModPreferido) { $candidatos += Join-Path $mods $ModPreferido }
    $candidatos += Get-ChildItem -LiteralPath $mods -Directory | Where-Object { $_.Name -ne $NombreMod } | ForEach-Object { $_.FullName }
    foreach ($c in $candidatos) {
        $ruta = Join-Path $c 'rom\mod_pv_db.txt'
        if ((Test-Path -LiteralPath $ruta) -and (Select-String -LiteralPath $ruta -Pattern "^pv_$PvId\." -Quiet)) { return $ruta }
    }
    return $null
}

$archivosCsv = Get-ChildItem -LiteralPath $Traducciones -Filter '*.csv'
if (-not $archivosCsv) { Write-Warning "No hay planillas en $Traducciones"; }

$pvdbSalida = New-Object System.Collections.Generic.List[string]
$cancionesLp = 0; $cancionesPvdb = 0; $cancionesSub = 0; $lineasTraducidas = 0; $lineasSinTraducir = 0

foreach ($archivo in $archivosCsv) {
    $filas = @(Import-Csv -LiteralPath $archivo.FullName -Encoding UTF8)
    if (-not (Test-CsvTraduccion $filas $archivo.Name)) { continue }

    foreach ($grupo in ($filas | Group-Object tipo, pv_id)) {
        $primera = $grupo.Group[0]
        $id = $primera.pv_id.Trim()
        $modOrigen = if ($primera.PSObject.Properties.Name -contains 'mod') { $primera.mod } else { '' }
        $espanol = @{}
        foreach ($f in $grupo.Group) {
            if ($f.espanol -and $f.espanol.Trim()) { $espanol[[int]$f.linea] = $f.espanol.Trim() }
        }
        if ($espanol.Count -eq 0) { continue }

        if ($primera.tipo -eq 'lp') {
            $original = Find-LyricsOriginal $id $modOrigen
            if (-not $original) { Write-Warning "[$($archivo.Name)] No se encontró el archivo de letras original de la canción $id. Se omite."; continue }
            $base = @(Read-LyricsPatchToml $original)
            $sb = New-Object System.Text.StringBuilder
            [void]$sb.AppendLine("# Spanish Lyrics - $($primera.cancion)")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('lyrics = [')
            for ($i = 0; $i -lt $base.Count; $i++) {
                $texto = ''
                if ($espanol.ContainsKey($i + 1)) { $texto = $espanol[$i + 1]; $lineasTraducidas++ } else { $lineasSinTraducir++ }
                [void]$sb.AppendLine("    {time = $($base[$i].Tiempo), text = `"$(ConvertTo-TomlString $texto)`"},")
            }
            [void]$sb.AppendLine(']')
            $dirLyrics = Join-Path $destino 'lyrics'
            New-Item -ItemType Directory -Force -Path $dirLyrics | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $dirLyrics "$id`_$SufijoIdioma.toml"), $sb.ToString(), $Utf8SinBom)
            $cancionesLp++
        }
        elseif ($primera.tipo -eq 'sub') {
            # Planillas de Importar-Subtitulos.ps1: los tiempos vienen en la planilla
            $filasSub = foreach ($f in $grupo.Group) {
                $seg = ConvertFrom-TiempoTexto $f.tiempo
                if ($seg -eq $null) { Write-Warning "[$($archivo.Name)] Línea $($f.linea): tiempo '$($f.tiempo)' no válido. Se omite."; continue }
                [pscustomobject]@{ Segundos = $seg; Texto = $(if ($f.espanol) { $f.espanol.Trim() } else { '' }) }
            }
            $filasSub = @($filasSub | Sort-Object Segundos)
            $archivoToml = Join-Path $destino "lyrics\$id`_$SufijoIdioma.toml"
            if (Test-Path -LiteralPath $archivoToml) { Write-Warning "[$($archivo.Name)] pv_$id ya tenía letras de otra planilla; se reemplazan por los subtítulos." }
            $sb = New-Object System.Text.StringBuilder
            [void]$sb.AppendLine("# Spanish Lyrics - $($primera.cancion)")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('lyrics = [')
            foreach ($f in $filasSub) {
                if ($f.Texto) { $lineasTraducidas++ }
                [void]$sb.AppendLine("    {time = $(Format-TiempoLp $f.Segundos), text = `"$(ConvertTo-TomlString $f.Texto)`"},")
            }
            [void]$sb.AppendLine(']')
            New-Item -ItemType Directory -Force -Path (Split-Path $archivoToml) | Out-Null
            [System.IO.File]::WriteAllText($archivoToml, $sb.ToString(), $Utf8SinBom)
            $cancionesSub++
        }
        elseif ($primera.tipo -eq 'pvdb') {
            $original = Find-PvDbOriginal $id $modOrigen
            if (-not $original) { Write-Warning "[$($archivo.Name)] No se encontró la canción pv_$id en los packs instalados. Se omite."; continue }
            $pvdb = Read-PvDb $original
            $prefijo = "pv_$id."
            # Formato del número de línea que usa el pack (por ejemplo 001), para no depender de Excel
            $formatoLinea = @{}
            foreach ($clave in $pvdb.Keys) {
                if ($clave -match "^pv_$id\.lyric(?:_en)?\.(\d+)$") { $formatoLinea[[int]$matches[1]] = $matches[1] }
            }
            $entrada = New-Object 'System.Collections.Specialized.OrderedDictionary'
            foreach ($clave in $pvdb.Keys) { if ($clave.StartsWith($prefijo)) { $entrada[$clave] = $pvdb[$clave] } }
            foreach ($n in $formatoLinea.Keys) {
                $claveEn = "pv_$id.lyric_en.$($formatoLinea[$n])"
                if ($espanol.ContainsKey($n)) { $entrada[$claveEn] = $espanol[$n]; $lineasTraducidas++ }
                else { $lineasSinTraducir++ }
            }
            foreach ($clave in $entrada.Keys) { $pvdbSalida.Add("$clave=$($entrada[$clave])") }
            $cancionesPvdb++
        }
    }
}

if ($pvdbSalida.Count -gt 0) {
    $dirRom = Join-Path $destino 'rom_steam_sp\rom'
    New-Item -ItemType Directory -Force -Path $dirRom | Out-Null
    # El juego necesita las claves en orden ordinal (byte a byte). Sort-Object ordena según el idioma
    # (por ejemplo song_name_en antes que song_name) y entonces el título no aparecía en la lista de canciones.
    $ordenadas = $pvdbSalida.ToArray()
    [System.Array]::Sort($ordenadas, [System.StringComparer]::Ordinal)
    [System.IO.File]::WriteAllText((Join-Path $dirRom 'mod_pv_db.txt'), ($ordenadas -join "`n") + "`n", $Utf8SinBom)
}

Write-Host "Mod generado en: $destino"
Write-Host "  Canciones oficiales (LyricsPatch): $cancionesLp"
Write-Host "  Canciones de packs: $cancionesPvdb"
Write-Host "  Canciones desde subtítulos: $cancionesSub"
Write-Host "  Líneas traducidas: $lineasTraducidas, sin traducir: $lineasSinTraducir"

if ($Instalar) {
    $instalado = Join-Path $mods $NombreMod
    if (Test-Path -LiteralPath $instalado) { Remove-Item -LiteralPath $instalado -Recurse -Force }
    Copy-Item -LiteralPath $destino -Destination $mods -Recurse
    Write-Host "Instalado en: $instalado"
    Write-Host "Pon '$NombreMod' arriba de todo en la lista del manager para que tenga prioridad sobre los packs."
}
