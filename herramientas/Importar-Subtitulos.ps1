<#
.SYNOPSIS
    Convierte subtítulos con tiempos (.vtt, .srt o .lrc) en una planilla "sub" lista para el mod.

.DESCRIPTION
    Sirve para canciones que no tienen letra en el juego o en ningún mod (muchas canciones de packs),
    o para traer una traducción que ya está sincronizada (por ejemplo, hecha con Aegisub o un .lrc).

    Cada subtítulo pasa a ser una fila con su tiempo y el texto en la columna "espanol".
    Si entre un subtítulo y el siguiente hay una pausa, se agrega una fila vacía para borrar la letra
    de la pantalla. Construir-Mod.ps1 convierte estas planillas en archivos de LyricsPatch
    (lyrics\<id>_sp.toml), que funcionan con cualquier canción.

    El número de canción (pv_id) se toma del nombre del archivo (pv_123.vtt, pv_123_sp.srt, 123.lrc)
    o del parámetro -PvId. Idea tomada de LyricGen (https://github.com/Aura39/LyricGen).

.EXAMPLE
    .\Importar-Subtitulos.ps1 -Archivo "C:\subs\pv_4501.srt" -Cancion "Mi canción"

.EXAMPLE
    .\Importar-Subtitulos.ps1 -Archivo .\letra.lrc -PvId 3519 -Desfase -0.2
#>
param(
    [Parameter(Mandatory = $true)][string[]]$Archivo,
    [string]$PvId = '',
    [string]$Cancion = '',
    [string]$Mod = '',
    # Segundos a sumar a todos los tiempos (negativo para adelantar la letra)
    [double]$Desfase = 0,
    [string]$Salida = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Comun.ps1')
if (-not $Salida) { $Salida = Join-Path $PSScriptRoot '..\traducciones' }
New-Item -ItemType Directory -Force -Path $Salida | Out-Null

# Pausa mínima (segundos) para agregar una fila vacía entre dos subtítulos
$PausaMinima = 0.5

function Read-VttSrt {
    param([string]$Ruta)
    $texto = [System.IO.File]::ReadAllText($Ruta, $Utf8SinBom) -replace "`r", ''
    $resultado = New-Object System.Collections.Generic.List[object]
    foreach ($bloque in ($texto -split "`n\s*`n")) {
        $lineas = @($bloque -split "`n" | Where-Object { $_.Trim() -ne '' })
        $i = 0
        while ($i -lt $lineas.Count -and $lineas[$i] -notmatch '-->') { $i++ }
        if ($i -ge $lineas.Count) { continue }
        $m = [regex]::Match($lineas[$i], '([\d:.,]+)\s*-->\s*([\d:.,]+)')
        if (-not $m.Success) { continue }
        $cuerpo = @()
        if ($i + 1 -lt $lineas.Count) {
            $cuerpo = @($lineas[($i + 1)..($lineas.Count - 1)] | ForEach-Object { ($_ -replace '<[^>]+>', '').Trim() })
        }
        $resultado.Add([pscustomobject]@{
            Inicio = ConvertFrom-TiempoTexto $m.Groups[1].Value
            Fin    = ConvertFrom-TiempoTexto $m.Groups[2].Value
            Texto  = (@($cuerpo) -join '\n')
        })
    }
    return $resultado
}

function Read-Lrc {
    param([string]$Ruta)
    $resultado = New-Object System.Collections.Generic.List[object]
    foreach ($l in [System.IO.File]::ReadAllLines($Ruta, $Utf8SinBom)) {
        $marcas = [regex]::Matches($l, '\[(\d+:\d+(?:[.:]\d+)?)\]')
        if ($marcas.Count -eq 0) { continue }   # metadatos como [ar:...] o [ti:...]
        $texto = ($l -replace '\[[^\]]*\]', '' -replace '<[^>]+>', '').Trim()
        foreach ($m in $marcas) {
            # En .lrc a veces se usa mm:ss:cc en lugar de mm:ss.cc
            $t = [regex]::Replace($m.Groups[1].Value, '^(\d+:\d+):(\d+)$', '$1.$2')
            $resultado.Add([pscustomobject]@{ Inicio = ConvertFrom-TiempoTexto $t; Fin = $null; Texto = $texto })
        }
    }
    return $resultado
}

foreach ($ruta in $Archivo) {
    $ruta = (Resolve-Path -LiteralPath $ruta).Path
    $ext = [System.IO.Path]::GetExtension($ruta).ToLowerInvariant()
    $subs = switch ($ext) {
        '.vtt' { Read-VttSrt $ruta }
        '.srt' { Read-VttSrt $ruta }
        '.lrc' { Read-Lrc $ruta }
        default { throw "Formato no soportado: $ext (usa .vtt, .srt o .lrc)" }
    }
    $subs = @($subs | Where-Object { $_.Inicio -ne $null } | Sort-Object Inicio)
    if ($subs.Count -eq 0) { Write-Warning "$ruta no tiene subtítulos con tiempo. Se omite."; continue }

    $id = $PvId
    if (-not $id) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($ruta)
        if ($base -match '^(?:pv_)?(\d+)(?:_|$)') { $id = [string][int]$matches[1] }
        else { throw "No se pudo saber el número de canción de '$base'. Usa -PvId o nombra el archivo pv_<id>.vtt" }
    }

    $filas = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $subs.Count; $i++) {
        $s = $subs[$i]
        $filas.Add($s)
        $siguiente = if ($i + 1 -lt $subs.Count) { $subs[$i + 1].Inicio } else { $null }
        if ($s.Fin -ne $null -and $s.Texto -and ($siguiente -eq $null -or $siguiente - $s.Fin -ge $PausaMinima)) {
            $filas.Add([pscustomobject]@{ Inicio = $s.Fin; Fin = $null; Texto = '' })
        }
    }

    $n = 0
    $csv = foreach ($f in $filas) {
        $n++
        [pscustomobject]@{
            tipo    = 'sub'
            pv_id   = $id
            cancion = $Cancion
            mod     = $Mod
            linea   = $n
            tiempo  = Format-TiempoLp ([math]::Max([double]0, [double]$f.Inicio + $Desfase))
            japones = ''
            romaji  = ''
            ingles  = ''
            espanol = $f.Texto
        }
    }
    $limpio = ($Cancion -replace '[\\/:*?"<>|]', '').Trim()
    $nombre = if ($limpio) { "sub_$id - $limpio.csv" } else { "sub_$id.csv" }
    $destino = Join-Path (Resolve-Path $Salida).Path $nombre
    $csv | Select-Object $ColumnasCsv | Export-Csv -LiteralPath $destino -NoTypeInformation -Encoding UTF8
    Write-Host "pv_$id : $($subs.Count) subtítulos -> $destino"
}
