# Operaciones y release

## Requisitos locales

- Xcode compatible con Swift 5.10.
- XcodeGen.
- Simulador iPhone configurado.
- Acceso a macOS target segun deployment definido.
- Node solo para Apps Script legado y `clasp`.

## Comandos

Generar proyecto:

```bash
cd FinanceCategorizer
xcodegen generate
```

Build iOS:

```bash
xcodebuild -scheme FinanceCategorizerIOS -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Build macOS:

```bash
xcodebuild -scheme FinanceCategorizerMac build
```

Tests rapidos:

```bash
FinanceCategorizer/scripts/test-fast.sh
```

## Checklist pre-release

- Build iOS limpio.
- Build macOS limpio.
- Unit tests en verde.
- Fixtures de importacion ejecutados.
- Localizacion ES/EN validada.
- Sin datos personales en repo.
- Export de emergencia probado.
- Fallback AI probado con feature flag desactivado.
- Store SwiftData abre con esquema actual.

## Versionado

Usar version semantica practica:

- Patch: correcciones sin cambio de modelo ni UI relevante.
- Minor: nueva funcionalidad compatible.
- Major: cambio de modelo, migracion o ruptura de compatibilidad.

## Politica de datos

Antes de distribuir:

- Documentar donde se guardan los datos locales.
- Documentar como exportar y borrar datos.
- No enviar datos financieros a servicios externos sin consentimiento explicito.
- Mantener AI local o claramente opt-in si se introduce proveedor externo.
