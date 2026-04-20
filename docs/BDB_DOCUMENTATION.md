# Documentacion Completa de BDB

## 1. Que es BDB

BDB es un addon para Godot que guarda datos en archivos `.bdb` usando un autoload llamado `BDB`.

La idea del addon es simple:

- un archivo `.bdb` por cada grupo de datos que quieras manejar
- una API pequena y clara
- soporte para datos reales de Godot (`Variant`)
- carga completa de datos sin tener que sacar variable por variable a mano
- opcion de trabajo por nombres o por orden

Sirve tanto para:

- proyectos que apenas empiezan y quieren algo rapido
- proyectos grandes o ya avanzados que necesitan ordenar persistencia sin meter una solucion demasiado pesada


## 2. Objetivos

- usar `CREATE`, `SAVE`, `LOAD` y `DELETE` como comandos principales
- poder guardar variables normales creadas con `var`
- poder obtener el archivo completo sin extraer campo por campo
- permitir carga por orden cuando el proyecto quiera ese flujo
- seguir siendo simple para proyectos chicos
- seguir siendo util para proyectos ya terminados o en produccion

## 3. Como funciona internamente

Cada archivo `.bdb` guarda un bloque de datos con:

- `values`: diccionario real con los datos
- `order`: orden de guardado para cargas posicionales
- metadata minima de version y timestamps

no separadores manuales. Ahora guarda una estructura completa de Godot, mucho mas estable para `Dictionary`, `Array`, `String`, `bool`, `int`, `float`, vectores, colores y otros `Variant` serializables.

## 4. Rutas que usa BDB

### 4.1 Archivo local del usuario

Todos los datos jugables o modificables se guardan en:

```text
user://<nombre>.bdb
```

Ejemplo:

```text
user://settings.bdb
user://player/profile.bdb
```

### 4.2 Archivo incluido en el proyecto

Si usas `CREATE(..., true)`, BDB puede crear una copia base en:

```text
res://bdb/<nombre>.bdb
```

Eso sirve como archivo plantilla o archivo inicial incluido en el paquete del juego.

Importante:

- `res://` solo puede escribirse desde el editor
- en una exportacion final, `res://` es solo lectura
- el archivo del jugador siempre debe vivir en `user://`

## 5. API principal

## 5.1 `BDB.CREATE(file_name, defaults = {}, create_bundle_copy = false)`

Crea el archivo por primera vez si no existe.

### Que hace

- normaliza el nombre y asegura la extension `.bdb`
- si no existe copia local en `user://`, la crea
- si existe una copia base en `res://bdb/`, usa esa como semilla
- si `create_bundle_copy` es `true`, intenta crear tambien la copia base en `res://bdb/`
- devuelve todos los datos finales como `Dictionary`

### Uso recomendado

```gdscript
var settings = BDB.CREATE("settings", {
	"language": "es",
	"music_volume": 1.0,
	"fullscreen": false
}, true)
```

### Cuando usarlo

- cuando el archivo todavia no existe
- cuando quieres definir valores predeterminados
- cuando quieres generar una base inicial del archivo

### Cuando no usarlo

- no lo llames en cada frame
- no lo uses como sustituto de `SAVE`
- no esperes que sobrescriba automaticamente un archivo ya existente

### Importante

`CREATE` no esta pensado para destruir o rehacer la base cada vez. Si el archivo ya existe, lo respeta.

## 5.2 `BDB.SAVE(file_name, data_or_context, fields_or_order = [], order = [])`

Guarda datos en el archivo `.bdb`.

### Modos de uso

### A. Guardar con `Dictionary`

Esta es la forma mas clara y recomendable.

```gdscript
BDB.SAVE("settings", {
	"language": "en",
	"music_volume": 0.65,
	"fullscreen": true
})
```

### B. Guardar variables del script actual

```gdscript
var player_name := "Maria"
var level := 5
var difficulty := "hard"

BDB.SAVE("player", self, ["player_name", "level", "difficulty"])
```

### C. Guardar con orden explicito

Si quieres que el archivo recuerde un orden especifico:

```gdscript
BDB.SAVE("player", {
	"player_name": "Maria"
}, ["slot_1", "slot_2", "player_name"])
```

En ese caso:

- `slot_1` se guarda como `null`
- `slot_2` se guarda como `null`
- `player_name` se guarda con `"Maria"`

Eso permite mantener posiciones si quieres una logica basada en orden.

### Que hace

- mezcla lo nuevo con lo ya guardado
- conserva lo anterior que no fue reemplazado
- mantiene un orden interno
- si pasas un orden explicito, lo respeta y rellena huecos con `null`

### Cuando usarlo

- para guardar ajustes
- para actualizar progreso
- para almacenar sesion, inventario, stats, banderas, checkpoints o configuraciones

### Cuando no usarlo

- no le pases nodos vivos del arbol como si fueran datos persistentes
- no le pases objetos temporales que no sean serializables
- no esperes que borre campos antiguos: para eso usa `DELETE`

## 5.3 `BDB.LOAD(file_name, request_or_target = null, defaults = {})`

Carga datos desde el archivo `.bdb`.

Este comando es el mas importante porque cubre varios casos sin agregar comandos extra.

### A. Cargar todo el archivo completo

```gdscript
var data = BDB.LOAD("settings")
```

Resultado:

- devuelve un `Dictionary` con todo el contenido

Ejemplo:

```gdscript
{
	"language": "en",
	"music_volume": 0.65,
	"fullscreen": true
}
```

Este es el flujo recomendado cuando quieres recuperar todo de una sola vez.

### B. Cargar una sola variable por nombre

```gdscript
var language = BDB.LOAD("settings", "language")
```

### C. Cargar varias variables en orden

```gdscript
var values = BDB.LOAD("settings", ["language", "music_volume", "fullscreen"])
```

Resultado:

```gdscript
["en", 0.65, true]
```

### D. Cargar segun el orden almacenado

```gdscript
var values = BDB.LOAD("settings", [])
```

Si pasas un `Array` vacio, BDB devuelve los valores siguiendo el orden guardado en el archivo.

### E. Cargar y rellenar variables del script automaticamente

```gdscript
var language := "es"
var music_volume := 1.0
var fullscreen := false

BDB.LOAD("settings", self)
```

Si en tu script existen variables con esos nombres, BDB las rellena automaticamente.

Este modo es el mas cercano a tu idea de "cargar y dejar las variables listas para usar".

### F. Cargar con valores por defecto

```gdscript
var settings = BDB.LOAD("settings", null, {
	"language": "es",
	"music_volume": 1.0,
	"fullscreen": false
})
```

Los defaults se usan cuando:

- el archivo no existe
- una clave concreta no existe

### Cuando usarlo

- cuando quieres leer todo de una vez
- cuando quieres autocompletar variables del script
- cuando necesitas una lectura por orden
- cuando quieres una sola clave

### Cuando no usarlo

- no esperes que cree automaticamente una plantilla base en `res://`; para eso usa `CREATE`
- no uses orden si realmente dependes de nombres claros; cuando puedas, usa nombres

## 5.4 `BDB.DELETE(file_name, target = null)`

Borra el archivo completo o una o varias claves.

### A. Borrar el archivo completo del usuario

```gdscript
BDB.DELETE("settings")
```

### B. Borrar una sola variable

```gdscript
BDB.DELETE("settings", "music_volume")
```

### C. Borrar varias variables

```gdscript
BDB.DELETE("settings", ["music_volume", "fullscreen"])
```

### Importante

`DELETE` borra la copia del usuario en `user://`.

No esta pensado para administrar archivos del plugin ni para editar directamente `res://bdb/` durante el juego exportado.

## 6. Orden de guardado y carga

Tu idea de trabajar por orden es valida y ahora queda cubierta de una manera mas limpia.

### Como funciona

1. Cuando guardas con nombres normales, el addon recuerda el orden de insercion.
2. Si das un orden explicito, el addon usa exactamente ese orden.
3. Si una posicion existe en el orden pero no recibe dato, se guarda como `null`.
4. Cuando haces `LOAD(file, [])`, el addon devuelve los datos segun ese orden guardado.
5. Cuando haces `LOAD(file, ["a", "b", "c"])`, devuelve exactamente esos campos en ese orden.

### Recomendacion

Si puedes trabajar por nombres, hazlo.

Usa orden solo cuando realmente tu flujo depende de posiciones fijas.

## 7. Compatibilidad con proyectos nuevos y viejos

## 7.1 Proyectos nuevos

BDB funciona bien para arrancar rapido:

- creas la base con `CREATE`
- guardas con `SAVE`
- cargas con `LOAD`
- limpias con `DELETE`

Es suficiente para settings, perfiles, progreso o datos de gameplay simple.

## 7.2 Proyectos existentes o grandes

Tambien es util si ya tienes muchas variables repartidas por scripts:

- puedes agrupar por archivo `.bdb`
- puedes guardar desde `self` indicando los nombres
- puedes cargar todo a un `Dictionary`
- puedes rellenar variables del script con `LOAD(..., self)`

Eso permite ordenar persistencia sin reescribir todo el proyecto de golpe.

## 8. Compatibilidad con la API vieja

Se mantiene una compatibilidad basica con:

- `save_(context, file_name, variable_names)`
- `load_(context, file_name, defaults = {})`

Internamente ahora usan la nueva logica.

Ademas, BDB intenta leer el formato viejo basado en texto cuando encuentra archivos anteriores.

Nota importante:

- si un archivo antiguo tenia casos ambiguos con comas dentro de strings complejos, la recuperacion es de mejor esfuerzo
- una vez que vuelvas a guardar con esta nueva version, el archivo queda estabilizado en el formato nuevo

## 9. Tipos de datos recomendados

BDB esta pensado para `Variant` serializables de Godot.

Ejemplos recomendados:

- `bool`
- `int`
- `float`
- `String`
- `Array`
- `Dictionary`
- `Vector2`
- `Vector3`
- `Color`
- combinaciones anidadas de los anteriores

## 10. Cosas que no conviene guardar

No es buena idea guardar esto directamente:

- nodos vivos del arbol
- referencias a escenas instanciadas
- objetos temporales que existen solo en runtime
- recursos no serializables
- `Callable` y cosas que dependen del estado vivo del motor

Si necesitas persistir esos casos, guarda una representacion simple:

- ids
- rutas
- nombres
- indices
- diccionarios planos

## 11. Ejemplos completos

## 11.1 Ajustes del juego

```gdscript
func _ready():
	BDB.CREATE("settings", {
		"language": "es",
		"music_volume": 0.8,
		"sfx_volume": 0.8,
		"fullscreen": false
	}, true)

	var settings = BDB.LOAD("settings")
	_apply_settings(settings)


func save_settings(language: String, music_volume: float, sfx_volume: float, fullscreen: bool) -> void:
	BDB.SAVE("settings", {
		"language": language,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen
	})
```

## 11.2 Datos del jugador

```gdscript
extends Node

var player_name := "Juan"
var level := 1
var xp := 0
var inventory := []


func save_player() -> void:
	BDB.SAVE("player/profile", self, ["player_name", "level", "xp", "inventory"])


func load_player() -> void:
	BDB.LOAD("player/profile", self, {
		"player_name": "Juan",
		"level": 1,
		"xp": 0,
		"inventory": []
	})
```

## 11.3 Carga por orden

```gdscript
BDB.SAVE("ordered_example", {
	"name": "Maria",
	"score": 1000
}, ["slot_1", "name", "slot_3", "score"])

var values = BDB.LOAD("ordered_example", [])
# Resultado: [null, "Maria", null, 1000]
```

## 12. Errores comunes

## 12.1 Llamar `CREATE` todo el tiempo

Incorrecto:

```gdscript
func _process(_delta):
	BDB.CREATE("settings")
```

Correcto:

```gdscript
func _ready():
	BDB.CREATE("settings")
```

## 12.2 Usar `SAVE` para borrar

Incorrecto:

```gdscript
BDB.SAVE("settings", {
	"fullscreen": null
})
```

Eso guarda `null`, pero no elimina la clave.

Correcto:

```gdscript
BDB.DELETE("settings", "fullscreen")
```

## 12.3 Esperar que `res://` sea editable en export

Incorrecto:

- asumir que el juego exportado puede escribir libremente en `res://`

Correcto:

- usar `user://` para datos del jugador
- usar `res://bdb/` solo como plantilla creada desde el editor

## 12.4 Mezclar orden con nombres sin saber cual manda

Si guardas con orden explicito, ese orden pasa a ser la referencia para las cargas posicionales.

Si no necesitas posiciones, evita ese modo y usa nombres.

## 13. Flujo recomendado

Para la mayoria de proyectos:

1. `CREATE` una vez al iniciar o al instalar el sistema.
2. `LOAD` para obtener o aplicar el estado.
3. `SAVE` cuando cambie algo importante.
4. `DELETE` solo cuando quieras limpiar una clave o reiniciar un archivo.

## 14. Resumen corto

Si quieres la version mas simple posible, piensa BDB asi:

- `CREATE`: prepara el archivo
- `SAVE`: guarda o actualiza datos
- `LOAD`: lee todo, una parte o rellena variables del script
- `DELETE`: borra archivo o campos

La forma mas clara de usarlo normalmente es:

```gdscript
BDB.CREATE("settings", {"language": "es"}, true)
BDB.SAVE("settings", {"language": "en"})
var data = BDB.LOAD("settings")
```

Y si quieres que las variables del script queden listas automaticamente:

```gdscript
var language := "es"
BDB.LOAD("settings", self)
```
