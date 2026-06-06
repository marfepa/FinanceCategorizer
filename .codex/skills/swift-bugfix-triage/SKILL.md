---
name: swift-bugfix-triage
description: Triage and fix of localized bugs in this Swift app. Use it to isolate the failure, minimize the change surface, and apply the smallest reliable fix.
---

# swift-bugfix-triage

## Cuándo usar esta skill

Usa esta skill cuando el trabajo sea:

- un bug visual localizado
- un bug funcional en una pantalla
- un fallo de estado o binding
- un problema de interaccion en una tabla, sheet o inspector
- un fallo localizado en imports, review queue, dashboard o AI fallback

No la uses para:

- refactors globales
- rediseno visual
- creacion de features nuevas
- integracion nueva de IA
- cambios amplios de arquitectura

## Objetivo

Encontrar el fallo real y aplicar el fix mas pequeno posible.

Prioriza:

1. reproducir mentalmente el problema con el codigo dado
2. acotar la causa
3. tocar el menor numero de archivos posible
4. evitar arreglos colaterales

## Proceso de triage

1. Define el sintoma exacto.
2. Localiza el flujo y la vista afectada.
3. Distingue si el fallo es de:
   - estado
   - layout
   - bindings
   - logica local
   - asincronia
   - integracion con repositorio o servicio
4. Propone primero el fix minimo.
5. Solo amplia alcance si el fix pequeno no basta.

## Heuristicas por zona

### Imports
Sospecha de:

- transicion entre pasos
- estado de preview/import
- file importer
- drop target
- manual mapping
- summary sheet
- recent imports

### Transactions
Sospecha de:

- seleccion actual
- filtros
- busqueda
- tabla con overlays flotantes
- inspector y acciones de edicion
- export CSV

### Review Queue
Sospecha de:

- seleccion en lista
- apply to similar
- approve/reassign/skip
- estado de AI suggestion
- recategorization summary
- acciones del inspector

### Dashboard / Insights
Sospecha de:

- snapshots vacios
- cargas asincronas
- overlays flotantes
- layout en split o grids
- visualizaciones que dependen de datos incompletos

### AI
Sospecha de:

- availability checks
- fallback no ejecutado
- parseo de salida estructurada
- confianza mal interpretada
- categoria no encontrada
- logica conservadora rota

## Reglas

- No rehagas la arquitectura para arreglar un bug local.
- No limpies medio repo aprovechando el bug.
- No mezcles mejoras visuales con el arreglo salvo necesidad directa.
- Si el bug esta en una ruta AI, mantén el fallback determinista intacto.
- Si el bug no esta probado del todo, elige la opcion mas segura y reversible.

## Que devolver

Prioriza uno de estos formatos:

- diff + breve resumen
- lista corta de causa + fix propuesto
- patch pequeno + motivo

## Que no hacer

- no conviertas el bugfix en refactor
- no abras mas de una linea de trabajo
- no cambies nombres, estructura y estilo sin necesidad
- no toques navegacion, persistencia o reglas globales si el fallo es local
