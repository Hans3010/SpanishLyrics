<#
.SYNOPSIS
    Instala un mod de prueba para averiguar qué terminación de archivo usa LyricsPatch con el juego en español.

.DESCRIPTION
    Crea el mod "Spanish Lyrics Test" con varios archivos para la misma canción (por defecto Alien Alien, 270):
      270_sp.toml, 270_es.toml, 270_spa.toml, 270_spanish.toml ...
    Cada uno muestra un texto de prueba distinto ("PRUEBA _sp", "PRUEBA _es", ...), no letras reales.
    Juega la canción: el texto que aparezca indica la terminación correcta.
    Cuando termines, borra el mod con -Quitar.
#>
param(
    [Parameter(Mandatory = $true)][string]$CarpetaJuego,
    [string]$PvId = '270',
    [string[]]$Sufijos = @('sp', 'es', 'spa', 'spanish', 'es_es', 'en'),
    [switch]$Quitar
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Comun.ps1')

$mods = Get-CarpetaMods $CarpetaJuego
$prueba = Join-Path $mods 'Spanish Lyrics Test'

if ($Quitar) {
    if (Test-Path -LiteralPath $prueba) { Remove-Item -LiteralPath $prueba -Recurse -Force; Write-Host 'Mod de prueba eliminado.' }
    return
}

# Tiempos del archivo original, para que el texto de prueba aparezca durante toda la canción
$original = Get-ChildItem -LiteralPath $mods -Directory | ForEach-Object { Join-Path $_.FullName "lyrics\$PvId.toml" } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
$tiempos = if ($original) { @(Read-LyricsPatchToml $original | ForEach-Object { $_.Tiempo }) } else { @('00:00:00', '00:00:10', '00:00:20', '00:00:30') }

New-Item -ItemType Directory -Force -Path (Join-Path $prueba 'lyrics') | Out-Null
[System.IO.File]::WriteAllText((Join-Path $prueba 'config.toml'), "enabled = true`nname = `"Spanish Lyrics Test`"`ndescription = `"Prueba temporal de idioma para LyricsPatch`"`ninclude = [`".`"]`n", $Utf8SinBom)

foreach ($s in $Sufijos) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('lyrics = [')
    for ($i = 0; $i -lt $tiempos.Count; $i++) {
        [void]$sb.AppendLine("    {time = $($tiempos[$i]), text = `"PRUEBA _$s (linea $($i + 1))`"},")
    }
    [void]$sb.AppendLine(']')
    [System.IO.File]::WriteAllText((Join-Path $prueba "lyrics\$PvId`_$s.toml"), $sb.ToString(), $Utf8SinBom)
}

Write-Host "Mod de prueba instalado en: $prueba"
Write-Host "Actívalo en el manager, juega la canción $PvId y fíjate qué 'PRUEBA _xx' aparece en las letras."
