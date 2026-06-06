---
name: swift-ai-guarded
description: Guarded AI changes for this Swift app with strict fallbacks, deterministic behavior, and conservative use of Foundation Models. Use it for prompts, availability, structured output, and local AI actions.
---

# swift-ai-guarded

## Cuándo usar esta skill

Usa esta skill cuando el trabajo sea:

- ajustar prompts de Foundation Models
- mejorar structured output
- reforzar availability checks
- mejorar fallback determinista
- ajustar confianza, cola de revision o reason strings
- mejorar servicios AI locales de dashboard, analysis, suggestions o acciones globales

No la uses para:

- rediseno UI puro
- bugs visuales
- features generales no relacionadas con AI
- cambios de arquitectura global
- cambios de persistencia que no sean imprescindibles

## Objetivo

Mantener una integracion AI util, prudente y segura para la app.

La IA aqui debe ser:

- opcional
- conservadora
- reversible
- bien guardada por availability
- incapaz de romper el flujo principal si falla

## Reglas obligatorias

### 1. Foundation Models nunca puede ser ruta unica

Toda capacidad AI debe mantener fallback determinista o comportamiento seguro si:

- `FoundationModels` no esta disponible
- el modelo no esta usable
- la respuesta falla
- el parseo falla
- la categoria sugerida no existe
- la confianza no es suficiente

### 2. Mantén guardas explicitas

Respeta siempre:

- `#if canImport(FoundationModels)`
- checks de availability por plataforma
- checks de feature flags si ya existen
- degradacion clara a ruta no-AI

### 3. La IA no debe inventar

- usa taxonomias cerradas cuando toque categorizar
- limita formato de salida
- parsea de forma robusta
- si no hay evidencia fuerte, baja confianza o manda a review
- si una categoria no casa exactamente, no la fuerces

### 4. Sé conservador con confianza y auto-aceptacion

- no subas confianza artificialmente
- no conviertas sugerencias debiles en decisiones automaticas
- preserva el enfoque prudente del sistema

## Tipos de cambios adecuados

- mejorar prompt de categorizacion
- estrechar lista de categorias candidatas
- hacer parseo mas robusto
- mejorar reasons y explanations
- reforzar fallback de dashboard copilot
- reforzar summary service
- mejorar acciones AI globales con salida estructurada
- mejorar wording para que la respuesta sea mas corta y consistente

## Tipos de cambios no adecuados

- rehacer el dominio financiero
- sustituir reglas o motor determinista por IA
- meter networking o dependencias remotas
- hacer la UI dependiente de una respuesta AI
- dispersar logica AI por toda la app

## Forma de trabajar

1. Identifica el servicio AI exacto.
2. Revisa availability y fallback antes de tocar el prompt.
3. Reduce el cambio al prompt, parser o decision concreta.
4. Mantén formatos de salida pequenos y estrictos.
5. Preserva una ruta segura cuando falle todo.

## Checklist interno

Antes de terminar, verifica:

- sigue funcionando sin Foundation Models
- hay fallback determinista
- la salida esta acotada
- la categoria sugerida se valida contra categorias reales
- la confianza sigue siendo conservadora
- los errores degradan a comportamiento seguro

## Entregable por defecto

Devuelve:

- diff + breve resumen

o:

- patch pequeno + motivos

## Limites explicitos

No toques salvo peticion clara:

- navegacion
- vistas no relacionadas
- modelos base
- repositorios generales
- reglas automaticas del dominio fuera del punto AI exacto
