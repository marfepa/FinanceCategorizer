# Modelo de datos y dominio

## Entidades persistentes detectadas

El esquema SwiftData contiene:

- `Transaction`
- `Category`
- `Merchant`
- `ImportBatch`
- `Rule`
- `UserCorrection`
- `Insight`
- `Budget`

## Conceptos clave

### Transaction

Movimiento financiero normalizado. Debe conservar descripcion original, descripcion limpia, comercio, importe, divisa, categoria, fuente de categorizacion, confianza, estado de revision y fingerprint.

### Category

Taxonomia financiera del usuario. Debe soportar categorias base y evolucion por personalizacion.

### Merchant

Memoria de comercios normalizados. Es clave para aprender de correcciones repetidas.

### ImportBatch

Traza cada importacion: fichero, tipo, filas validas, filas importadas, duplicados, pendientes de revision y fingerprints.

### Rule

Regla explicita de categorizacion. Debe tener prioridad sobre aprendizaje estadistico o IA.

### UserCorrection

Correccion humana que alimenta memoria, sugerencias de reglas y modelo local.

### Insight

Resultado derivado de analisis financiero. Debe poder recalcularse desde datos base.

### Budget

Presupuesto por categoria o periodo. Debe mantenerse desacoplado de importacion.

## Invariantes recomendadas

- Una transaccion no debe importarse dos veces si su fingerprint coincide.
- Una decision con baja confianza debe quedar pendiente de revision.
- Una correccion humana debe ser trazable.
- Los insights deben ser recalculables.
- La eliminacion de datos persistentes nunca debe ser automatica y silenciosa.
- La IA no debe sobrescribir decisiones humanas.

## Eventos de dominio utiles

Aunque la app no tenga un bus de eventos formal, conviene pensar en estos eventos:

- `ImportPreviewCreated`
- `ImportBatchImported`
- `TransactionCategorized`
- `TransactionQueuedForReview`
- `UserCorrectionApplied`
- `RuleSuggested`
- `InsightsRefreshed`
- `StoreRecoveryRequired`

Estos eventos pueden guiar logging, tests y futuras automatizaciones.
