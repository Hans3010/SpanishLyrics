# Spanish Lyrics

Letras en **español neutro** para *Hatsune Miku: Project DIVA Mega Mix+*, hechas por la comunidad.

Este repositorio **no trae letras originales**: trae las herramientas para traducir y armar el mod.
Cada persona genera las planillas con las letras que ya tiene instaladas en su juego, traduce,
y el constructor arma el mod.

## Cómo funciona

El juego guarda las letras de dos formas, y el mod soporta las dos (más una tercera para canciones sin letra):

| Tipo | Canciones | Dónde va el español |
|---|---|---|
| `lp` | Canciones oficiales con archivos de [LyricsPatch](https://gamebanana.com/mods/414986) | `lyrics\<id>_<sufijo>.toml` (requiere LyricsPatch) |
| `pvdb` | Packs de canciones (`mod_pv_db.txt`) | `rom_steam_sp\rom\mod_pv_db.txt` |
| `sub` | Cualquier canción, desde subtítulos `.vtt`, `.srt` o `.lrc` | `lyrics\<id>_<sufijo>.toml` (requiere LyricsPatch) |

`rom_steam_sp` es la carpeta que el juego carga cuando está configurado en español
(igual que *English Lyrics* usa `rom_steam_en` para inglés).

## Requisitos

- Windows con PowerShell (ya viene con Windows).
- DivaModLoader instalado (lo instala DivaModManager).
- LyricsPatch, para las canciones oficiales.
- El juego en **español** en Steam (Propiedades → General → Idioma).

## Paso a paso

Abre PowerShell en la carpeta `herramientas` y define la carpeta de tu juego:

```powershell
$juego = "D:\SteamLibrary\steamapps\common\Hatsune Miku Project DIVA Mega Mix Plus"
```

1. **Crear las planillas** (una por canción, en la carpeta `plantillas`):

   ```powershell
   .\Crear-Plantillas.ps1 -CarpetaJuego $juego
   ```

2. **Traducir:** copia a la carpeta `traducciones` las planillas de las canciones que vas a traducir
   y completa la columna **`espanol`**, una línea por fila. Puedes abrirlas con Excel o LibreOffice
   (guárdalas como *CSV UTF-8*). En canciones `lp` puedes usar `\n` para un salto de línea.

3. **Construir e instalar el mod:**

   ```powershell
   .\Construir-Mod.ps1 -CarpetaJuego $juego -Instalar
   ```

4. En DivaModManager, pon **Spanish Lyrics arriba de todo** en la lista de mods.

## Otras herramientas

| Script | Para qué sirve |
|---|---|
| `Ver-Estado.ps1 -CarpetaJuego $juego` | Crea `estado-traducciones.html`: qué canciones instaladas ya están en español |
| `Exportar-Pendientes.ps1 -CarpetaJuego $juego -Pack "Nombre"` | Copia a `para-traducir` las planillas de un pack que faltan traducir |
| `Importar-Subtitulos.ps1 -Archivo pv_123.srt` | Convierte subtítulos sincronizados (`.vtt`, `.srt`, `.lrc`) en una planilla `sub` para el mod. Sirve para canciones que no tienen letra en el juego |
| `Crear-Lista-Canciones.ps1` | Crea `canciones-oficiales.html` con links para buscar traducciones |
| `Crear-Prueba-Idioma.ps1` | Prueba qué terminación de archivo usa LyricsPatch (en español es `_sp`) |

## Estado

- Canciones oficiales: 255 con borrador en español (traducción automática, pendiente de revisión).
- Packs: algunas canciones de Nitori's Song Pack.

## Canciones sin letra (subtítulos)

Muchas canciones de packs no traen letra. Si tienes la letra en español sincronizada como subtítulos
(por ejemplo, hecha con [Aegisub](https://aegisub.org) o un archivo `.lrc`), puedes agregarla:

```powershell
.\Importar-Subtitulos.ps1 -Archivo "C:\subs\pv_4501.srt" -Cancion "Nombre de la canción"
# si la letra sale adelantada o atrasada:  -Desfase -0.3  (segundos)
.\Construir-Mod.ps1 -CarpetaJuego $juego -Instalar
```

El número de la canción se toma del nombre del archivo (`pv_4501.srt`, `4501.lrc`) o de `-PvId`.
El número de cada canción aparece en el nombre de las planillas o en `estado-traducciones.html`.
Se genera un archivo de LyricsPatch, que muestra la letra por tiempo sin tocar los archivos del pack.

## Límite de 150 líneas

El juego muestra como máximo 150 líneas de letra por canción. `Crear-Plantillas.ps1` avisa cuando una
canción tiene más; para verlas todas hace falta el mod *OpenLyricLimit*.

## Guía de estilo (español neutro)

- Sin regionalismos: nada de *vos/vosotros*, *che*, *tío*, *wey*, etc. Usar *tú* y *ustedes*.
- Traducir el sentido, no palabra por palabra; que se pueda leer al ritmo de la canción.
- Mantener líneas cortas: si una línea queda larga, usar `\n`.
- Nombres propios y palabras en inglés que forman parte de la canción se dejan como están.
- Si no estás seguro de una línea, déjala vacía: se mostrará en blanco (lp) o en el idioma del pack (pvdb).

## Compartir traducciones

Las letras originales tienen derechos de autor. Al compartir, comparte solo tus traducciones
(la columna `espanol` junto con `tipo`, `pv_id`, `mod` y `linea`), no las planillas completas.
La carpeta `plantillas` está excluida de git por esa razón.

## Idioma en LyricsPatch

LyricsPatch elige el archivo según el idioma del juego, con una terminación en el nombre
(`<id>_jp.toml` para japonés). Para confirmar cuál usa con el juego en español:

```powershell
.\Crear-Prueba-Idioma.ps1 -CarpetaJuego $juego     # instala un mod de prueba
# juega Alien Alien y mira qué "PRUEBA _xx" aparece
.\Crear-Prueba-Idioma.ps1 -CarpetaJuego $juego -Quitar
```

Si la terminación no es `sp`, constrúyelo con `-SufijoIdioma xx`.

## Créditos

- [LyricsPatch](https://gamebanana.com/mods/414986) por Jay.
- Formato inspirado en *English Lyrics for Song Packs*.
- Lectura de los `.dsc` (tiempos de las letras) e idea de importar subtítulos: basadas en
  [LyricGen](https://github.com/Aura39/LyricGen) de Aura39 y en la tabla de comandos del
  [editor de DSC de nastys](https://github.com/nastys/nastys.github.io). El código es propio.
- Herramientas y mod: Hanserm.
