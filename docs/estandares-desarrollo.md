# Estandares de desarrollo

## Flujo de trabajo

- Todo cambio debe entrar por rama y PR.
- Un PR debe tocar un area principal: importacion, persistencia, categorizacion, UI, AI o documentacion.
- Evitar mezclar refactors con cambios funcionales.
- Cada PR debe indicar validacion ejecutada y riesgos pendientes.

## Convenciones Swift

- Mantener business logic fuera de vistas SwiftUI.
- Usar `AppContainer` como composition root.
- Inyectar servicios en view models.
- Mantener repositorios en `Shared/Data/Repositories`.
- Mantener DTOs en `Shared/Data/DTO`.
- Mantener modelos persistentes en `Shared/Domain/Models`.
- Evitar `try!` salvo constantes imposibles de fallar y cubiertas por test.
- Sustituir `print` por logging o estado visible cuando afecte a UX.

## UI

- Usar primitivas existentes: `AppSpacing`, `AppTypography`, `AppMaterials`, `AppColors`, `AppRadius`, `GlassCard`, `PrimaryButton`, `SearchBar`, `LoadingView`, `EmptyStateView`, `ErrorStateView`.
- Mantener UI especifica en `Platform/iOSUI` o `Platform/macOSUI`.
- No mover componentes a `Shared/UI` salvo reutilizacion real.
- No duplicar reglas de negocio en pantallas.

## Importacion

- Cada formato debe exponer preview, diagnosticos e importacion.
- Cada banco/formato soportado debe tener fixture anonimizados.
- Si un banco no esta implementado, debe mostrarse como no soportado o experimental.
- Los errores de fila deben ser explicables para el usuario.

## Categorizacion

- Mantener thresholds en `AppConfig`.
- Registrar fuente de decision.
- Autoaceptar solo cuando `ConfidenceScorer` lo permita.
- Enviar a review queue si hay ambiguedad.
- Las correcciones del usuario deben alimentar memoria, reglas sugeridas o modelo local.

## IA

- Todo flujo AI debe tener fallback determinista.
- Mantener guards `#if canImport(FoundationModels)` y availability checks.
- No usar IA para mutar datos sin confirmacion o trazabilidad.
- Validar outputs estructurados antes de usarlos.

## Privacidad

- No versionar extractos reales.
- No versionar stores SwiftData ni exports personales.
- Los fixtures deben estar anonimizados.
- Los logs no deben contener importes completos ni descripciones personales si van a compartirse.
