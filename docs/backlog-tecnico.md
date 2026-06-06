# Backlog tecnico priorizado

## P0

### Crear repo de producto y CI

Sin repo Git detectado, el proyecto no puede escalar de forma segura.

Estado: mitigado localmente. Falta remoto GitHub y proteccion de rama.

Entregables:

- Repo Git. Hecho local.
- `.gitignore`. Hecho.
- Rama principal protegida. Pendiente remoto.
- Workflow CI con build y tests. Hecho.

### Proteger datos SwiftData

`ModelContainerFactory` borraba store persistente si no podia abrirla.

Estado: mitigado. Ahora crea backup y cae a in-memory.

Entregables:

- Backup antes de cualquier recuperacion. Hecho.
- Mensaje de error recuperable. Parcial.
- Export diagnostico.
- Tests de fallo de apertura.

## P1

### Fixtures anonimizados de extractos

Estado: iniciado con fixture Openbank CSV multilinea.

Entregables:

- CSV por banco. Parcial.
- XLSX representativo.
- PDF convertido a texto o fixture PDF si se puede incluir legalmente.
- Tests de regresion. Parcial.

### Matriz de soporte banco/formato

Estado: mitigado en codigo para PDF Santander/BBVA; matriz pendiente.

Entregables:

- Tabla: banco, CSV, XLSX, PDF, estado, limitaciones.
- UI que no prometa Santander/BBVA PDF si no esta implementado.

### Limpieza de workspace

Entregables:

- Excluir `node_modules`, runtime Node descargado, tarballs y DerivedData.
- Mantener solo lockfiles y scripts necesarios.

### Actualizar documentacion heredada

Entregables:

- `SETUP_XCODE.md` sin referencias obsoletas a placeholders.
- README del producto alineado con estado real.

## P2

### Logging estructurado

Entregables:

- Sustituir `print` de exportacion por `Logger` o estado UI.
- Politica de redaccion de datos sensibles.

### Robustecer regex PDF

Entregables:

- Evitar `try!` o cubrirlo con tests.
- Tests con lineas PDF representativas.

### Observabilidad de categorizacion

Entregables:

- Contadores de origen: reglas, memoria, ML, AI, unknown.
- Ratio de review queue.
- Ratio de correccion posterior.

## P3

### Product analytics local

Entregables:

- Metricas locales sin tracking externo.
- Panel de salud de importacion y aprendizaje.

### Guia de migracion Apps Script

Entregables:

- Mapeo de reglas Apps Script a Swift.
- Mapeo de reportes Sheets a insights nativos.
- Criterios para retirar automatizacion legado.
