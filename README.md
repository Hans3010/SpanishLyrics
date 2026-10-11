# Spanish Lyrics

Letras en **español neutro** para *Hatsune Miku: Project DIVA Mega Mix+*, hechas por la comunidad.

Este repositorio **no trae letras originales**: trae las herramientas para traducir y armar el mod.
Cada persona genera las planillas con las letras que ya tiene instaladas en su juego, traduce,
y el constructor arma el mod.

## Cómo funciona

El juego guarda las letras de dos formas, y el mod soporta las dos:

| Tipo | Canciones | Dónde va el español |
|---|---|---|
| `lp` | Canciones oficiales con archivos de [LyricsPatch](https://gamebanana.com/mods/414986) | `lyrics\<id>_<sufijo>.toml` (requiere LyricsPatch) |
| `pvdb` | Packs de canciones (`mod_pv_db.txt`) | `rom_steam_sp\rom\mod_pv_db.txt` |

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
| `Crear-Lista-Canciones.ps1` | Crea `canciones-oficiales.html` con links para buscar traducciones |
| `Crear-Prueba-Idioma.ps1` | Prueba qué terminación de archivo usa LyricsPatch (en español es `_sp`) |

## Estado

- Canciones oficiales: 255 con borrador en español (traducción automática, pendiente de revisión).
- Packs: algunas canciones de Nitori's Song Pack.

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
- Herramientas y mod: Hanserm.
