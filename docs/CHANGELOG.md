# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Deshacer en la cola de revisión (aviso, ⌘Z en macOS) para aprobar, reasignar, aceptar sugerencias, aplicar a similares, aceptar alta confianza y marcar como transferencia.
- Confirmación con número de movimientos afectados antes de "Aplicar a similares".
- Detección de posibles traspasos entre cuentas propias (mismo importe saliendo de una cuenta y entrando en otra en ≤3 días), propuestos en la cola de revisión y confirmables con deshacer; aviso en Cuentas.

### Changed
- Aprobar o reasignar en la cola solo modifica el movimiento seleccionado; la propagación a movimientos con el mismo comercio es explícita.
- La propagación nunca sobrescribe decisiones manuales previas.
- Las reglas solo se crean desde la cola si el usuario lo pide; las sugeridas se ofrecen en el aviso.

### Fixed
- Las correcciones se guardan de forma atómica: un fallo a mitad ya no deja datos parciales.

---

## [0.2.0] - 2026-05-01

### Added
- Soporte nativo multiplataforma completo para macOS (Liquid Glass UI).
- Integración de SwiftData para persistencia local de transacciones.
- Soporte para importación de extractos bancarios de Openbank.
- Clasificación heurística local y motor de sugerencias basado en reglas.
- Localización inicial en inglés y español.

### Fixed
- Corrección de bugs menores en el refresco del dashboard.

---

## [0.1.0] - 2026-04-10

### Added
- Estructura base del proyecto generada mediante XcodeGen.
- Módulos del dominio de finanzas: transacciones, cuentas y categorías.
- Pruebas unitarias básicas para los modelos de datos.
