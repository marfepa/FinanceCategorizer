# ADR 0001: La app nativa Swift es la linea principal

## Estado

Aceptada.

## Contexto

El workspace contiene una automatizacion Apps Script y una app nativa `FinanceCategorizer`. Apps Script resuelve un flujo inicial en Google Sheets, pero escalar importacion, persistencia, revision, aprendizaje, insights y UX multiplataforma es mas sostenible en la app Swift.

## Decision

`FinanceCategorizer` sera la linea principal de producto. Apps Script queda como legado funcional, fuente de requisitos y posible herramienta auxiliar hasta completar migracion.

## Consecuencias

- Las nuevas capacidades se disenaran primero para la app nativa.
- Los bancos, reglas y reportes del Apps Script se migraran mediante backlog.
- No se ampliara Apps Script salvo mantenimiento necesario.
- La documentacion distinguira claramente legado y producto principal.
