# BDB para Godot

BDB es un addon para Godot pensado para guardar datos en archivos `.bdb` de forma simple, directa y reutilizable. Cada archivo funciona como una pequeña base de datos independiente para cosas como ajustes, progreso, sesiones, datos del jugador, dificultad, niveles o cualquier otra estructura de datos basada en `Variant`.

Esta version reorganiza el addon alrededor de 4 comandos principales (VERSION 2.0):

- `BDB.CREATE()`
- `BDB.SAVE()`
- `BDB.LOAD()`
- `BDB.DELETE()`

Tambien mejora 3 cosas clave:

- ya no depende de un formato fragil separado por comas y `;`
- puede devolver todos los datos completos de una sola vez
- puede trabajar tanto por nombre como por orden de guardado

## Instalacion

1. Copia la carpeta [addons/bdb](/addons/bdb) o instala desde la tienda de godot.
2. Activa el plugin desde `Project > Project Settings > Plugins`.
3. Usa el autoload `BDB` que el plugin registra automaticamente.

## Flujo rapido

```gdscript
# Crear por primera vez
BDB.CREATE("settings", {
	"language": "es",
	"music_volume": 0.8,
	"fullscreen": true
}, true)

# Guardar datos
BDB.SAVE("settings", {
	"language": "en",
	"music_volume": 0.5
})

# Cargar todo
var settings = BDB.LOAD("settings")

# Borrar una variable
BDB.DELETE("settings", "music_volume")
```

## Ejemplos utiles

```gdscript
# 1. Guardar variables del script actual
var player_name := "Maria"
var level := 7
var difficulty := "hard"

BDB.SAVE("player_data", self, ["player_name", "level", "difficulty"])
```

```gdscript
# 2. Cargar y rellenar variables del script automaticamente
var player_name := ""
var level := 0
var difficulty := "normal"

BDB.LOAD("player_data", self)
```

```gdscript
# 3. Cargar valores por orden
var values = BDB.LOAD("player_data", ["player_name", "level", "difficulty"])
var loaded_name = values[0]
var loaded_level = values[1]
var loaded_difficulty = values[2]
```

## Rutas de guardado

- Copia local del usuario: `user://<nombre>.bdb`
- Copia incluida en el proyecto: `res://bdb/<nombre>.bdb`

La copia en `res://` solo puede crearse desde el editor. En un juego exportado, `res://` es de solo lectura.

## Documentacion completa

La guia detallada esta en [docs/BDB_DOCUMENTATION.md](docs/BDB_DOCUMENTATION.md).

Incluye:

- cada comando y su firma
- ejemplos recomendados
- ejemplos que no conviene usar
- errores comunes
- compatibilidad con proyectos nuevos y existentes
- detalles del orden de guardado y carga
- limitaciones reales del sistema
- compatibilidad con la API vieja `save_()` y `load_()`
