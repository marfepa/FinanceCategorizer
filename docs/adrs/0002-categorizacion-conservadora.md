# ADR 0002: Categorizacion conservadora con revision humana

## Estado

Aceptada.

## Contexto

La app clasifica movimientos financieros. Una categorizacion incorrecta puede distorsionar presupuestos, insights y decisiones del usuario.

## Decision

La categorizacion sera conservadora. La cadena de decision sera: reglas explicitas, memoria de comercio, clasificador local, IA opcional y revision manual. Solo se autoaceptaran decisiones que superen thresholds centralizados y validados por `ConfidenceScorer`.

## Consecuencias

- La review queue es parte central del producto.
- Las decisiones deben registrar fuente y confianza.
- Las correcciones del usuario deben alimentar aprendizaje.
- Se prioriza confianza y explicabilidad sobre automatizacion agresiva.
