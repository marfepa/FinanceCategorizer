# Auditoria tecnica

Fecha de auditoria: 2026-06-05.

## Resumen ejecutivo

El proyecto ya tiene una base fuerte para evolucionar: separa dominio, repositorios, servicios, view models y UI por plataforma. La app nativa `FinanceCategorizer` es mas escalable que la automatizacion Apps Script porque centraliza persistencia, importacion, categorizacion, aprendizaje, insights y UI en una arquitectura de producto.

Los riesgos principales no estan en la idea de arquitectura, sino en la falta de disciplina de producto alrededor: no habia repo Git detectado en el workspace auditado, las pruebas eran todavia estrechas, hay deuda heredada y parte de la documentacion describe placeholders antiguos. Tambien habia comportamiento potencialmente peligroso en persistencia: si SwiftData no abria la store persistente, el codigo intentaba destruir los ficheros de store y recrearla.

## Estado tras primera intervencion

- `FinanceCategorizer/` queda inicializado como repo Git local.
- La documentacion de auditoria queda incorporada en `docs/`.
- Se anade `.gitignore` para artefactos generados, datos financieros locales y dependencias no versionables.
- `ModelContainerFactory` ya no borra la store persistente automaticamente; crea backup de recuperacion y cae a in-memory.
- Santander y BBVA PDF quedan fuera del pipeline activo hasta implementar parsing real.
- Se anade fixture CSV anonimizado y test end-to-end de importacion con bloqueo de duplicados.
- Se anade CI con build iOS, build macOS, unit tests y comprobacion explicita de localizacion.

## Inventario

### Apps Script legado

- Ruta: `src/`.
- Stack: Google Apps Script + `@google/clasp`.
- Proposito: importar extractos CSV/Excel de Openbank, Cajamar y ABANCA, normalizar, categorizar por reglas y generar reportes en Google Sheets.
- Documentacion actual: `README.md`, `ARCHITECTURE.md`, `tests/manual-test-cases.md`.

### App nativa

- Ruta: `FinanceCategorizer/`.
- Stack: Swift 5.10, SwiftUI, SwiftData, XcodeGen, ZIPFoundation.
- Targets: `FinanceCategorizerIOS`, `FinanceCategorizerMac`, `FinanceCategorizerTests`, `FinanceCategorizerUITestsIOS`, `FinanceCategorizerUITestsMac`.
- Modulos: dominio, repositorios, importacion, normalizacion, categorizacion, aprendizaje local, AI/Foundation Models, insights, UI compartida, UI iOS y UI macOS.

## Fortalezas

- `AppContainer` funciona como composition root y evita cableado disperso.
- El dominio esta separado en `Shared/Domain`.
- La persistencia esta aislada en `Shared/Data`.
- La importacion tiene servicios separados para CSV, XLSX y PDF.
- La categorizacion sigue una cadena razonable: reglas, memoria de comercio, clasificador local, Foundation Models opcional, revision manual.
- La UI esta separada por plataforma y comparte design system.
- Los thresholds criticos estan centralizados en `AppConfig`.
- Hay localizacion ES/EN y test de claves importantes.

## Riesgos criticos

### P0 - Versionado ausente

No se encontro `.git` en el workspace auditado. Sin historial, ramas, CI y PRs, la app no puede escalar con seguridad.

Estado: mitigado localmente con repo Git en `FinanceCategorizer/`. Pendiente publicar remoto y proteger rama principal.

### P0 - Recuperacion destructiva de SwiftData

`ModelContainerFactory` eliminaba la store persistente si fallaba la apertura. Para una app financiera, esto podia borrar datos del usuario tras un problema de migracion o corrupcion.

Estado: mitigado. Ahora se preservan los ficheros de store en `RecoveryBackups` y se usa in-memory como fallback. Pendiente UX de recuperacion/export diagnostico.

### P1 - Pruebas insuficientes para el flujo principal

Hay tests utiles de parser, normalizacion y thresholds, pero falta cobertura end-to-end de importacion real, duplicados, repositorios, categorizacion, migraciones SwiftData y UI critica.

Accion: definir fixtures anonimizados y suite de regresion para CSV/XLSX/PDF.

### P1 - Funcionalidad anunciada incompleta

`OtherBankStrategies.swift` contenia estrategias Santander y BBVA PDF que podian hacer match aunque no extraian movimientos. La documentacion y la UI deben diferenciar "soportado", "preview experimental" y "pendiente".

Estado: mitigado tecnicamente. Santander y BBVA devuelven match 0 y `PDFParsingService` solo activa Openbank PDF. Pendiente matriz formal de soporte.

### P1 - IA y macOS 26

El proyecto apunta a macOS 26.0 y usa Foundation Models con guards. Es correcto como exploracion, pero eleva requisitos de entorno y puede limitar distribucion.

Accion: documentar compatibilidad, mantener feature flags y definir comportamiento sin IA como producto completo.

## Riesgos secundarios

- `try!` en regex de `OpenbankPDFStrategy`; bajo riesgo si son constantes validas, pero conviene encapsular para evitar crash futuro.
- `print` en UI macOS para exportacion; deberia migrarse a logging o estado visible.
- Tests con ruta absoluta opcional a `Downloads/import 1.csv`; mitigado con fixture anonimizado versionado.
- `node_modules`, `node-v20...` y `node.tar.gz` aparecen dentro del workspace; deben excluirse o aislarse.
- `SETUP_XCODE.md` conserva referencias a placeholders que ya no representan el estado actual.

## Recomendacion de direccion

1. Declarar `FinanceCategorizer` como producto principal.
2. Mantener Apps Script como legado hasta migrar reglas, bancos soportados y reportes.
3. Estabilizar importacion y persistencia antes de ampliar dashboards o IA.
4. Convertir la revision manual en parte central del producto, no en excepcion.
5. Introducir CI y fixtures antes de aceptar cambios de parsing o categorizacion.
