# Estrategia de pruebas y QA

## Piramide recomendada

### Unit tests

Cobertura obligatoria:

- `ImportValueParser`: importes europeos, negativos, separadores mixtos.
- `DateNormalizationService`: formatos por banco e idioma.
- `TextCleanupService` y `MerchantExtractionService`.
- `FingerprintBuilder`: estabilidad y colisiones esperables.
- `ConfidenceScorer`: thresholds y review queue.
- `RuleEngine` y `MerchantMemoryEngine`.
- `ImportValidationService`: mapeos validos e invalidos.

### Integration tests

Cobertura obligatoria:

- Preview e importacion de CSV.
- Preview e importacion de XLSX.
- PDF Openbank si se mantiene como soportado.
- Duplicados por fingerprint de archivo.
- Duplicados por fingerprint de filas.
- Guardado de `ImportBatch`.
- Refresco de insights tras importacion.
- Persistencia SwiftData in-memory y persistente temporal.

### UI tests

Rutas criticas:

- Importar archivo y ver resumen.
- Resolver transaccion en review queue.
- Filtrar y editar transacciones.
- Crear o modificar regla.
- Exportar movimientos.
- Cambiar idioma.

## Fixtures

Crear carpeta de fixtures dentro del repo de producto:

```text
Tests/Fixtures/
  openbank/
    csv_basic.csv
    csv_multiline_concepts.csv
    pdf_basic.txt
  cajamar/
    csv_basic.csv
  abanca/
    csv_basic.csv
```

Reglas:

- Datos anonimizados.
- Importes plausibles, no reales.
- Nombres de comercio sinteticos.
- Casos borde documentados en el nombre del fichero.

## CI minimo

Comandos objetivo:

```bash
xcodegen generate
xcodebuild -scheme FinanceCategorizerIOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme FinanceCategorizerMac build
xcodebuild test -scheme FinanceCategorizerIOS -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Criterios de aceptacion por PR

- Tests nuevos cuando se toca parsing, normalizacion, categorizacion o persistencia.
- Build de plataforma afectada.
- Sin datos personales en fixtures o logs.
- Documentacion actualizada si cambia un flujo usuario o una decision arquitectura.

## Gaps actuales detectados

- Tests todavia demasiado concentrados en parser CSV y utilidades.
- Test opcional con ruta absoluta a `Downloads/import 1.csv`.
- Falta suite de migracion SwiftData.
- Falta matriz automatizada banco/formato.
- Falta CI.
