# ADR 0003: IA opcional con fallback determinista

## Estado

Aceptada.

## Contexto

El proyecto incluye integraciones con Foundation Models bajo availability checks. La disponibilidad depende de plataforma, version del sistema y capacidades locales.

## Decision

La IA sera opcional. Ningun flujo principal dependera exclusivamente de IA. Cada servicio AI tendra fallback determinista y salida validada.

## Consecuencias

- La app debe funcionar con IA desactivada o no disponible.
- Las sugerencias AI no deben sobrescribir decisiones humanas sin confirmacion.
- Los prompts y salidas se testearan por idioma cuando afecten UX.
- La documentacion de compatibilidad debe explicar claramente las limitaciones.
