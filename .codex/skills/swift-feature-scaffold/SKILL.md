---
name: swift-feature-scaffold
description: Scaffold of a small, tightly scoped Swift feature for this finance app. Use it to create a screen, subview, ViewModel, or local flow without reworking the global architecture.
---

# swift-feature-scaffold

## Cuándo usar esta skill

Usa esta skill cuando el trabajo sea uno de estos:

- crear una pantalla nueva en una feature ya existente
- añadir una subvista o panel nuevo
- añadir un ViewModel local
- conectar una vista con servicios o repositorios ya existentes
- introducir una mejora pequena de flujo en Imports, Transactions, Review Queue, Dashboard, Insights, Rules o Settings

No la uses para:

- refactors globales
- rehacer navegacion
- rehacer persistencia
- redisenar toda la arquitectura
- arreglar bugs complejos ya existentes
- cambios centrados en IA con Foundation Models
- pulido visual puro

## Objetivo

Crear cambios minimos, claros y coherentes con la arquitectura actual del repo.

Prioriza siempre:

1. una sola feature
2. 1 a 3 archivos si es posible
3. integracion local
4. diff pequeno y revisable

## Zonas tipicas del repo

Usala sobre una de estas zonas:

- Imports
- Transactions
- Review Queue
- Dashboard
- Insights
- Rules
- Categories
- Budgets
- Settings

## Que debes respetar

- No rehagas la arquitectura general.
- No muevas responsabilidades entre capas salvo necesidad clara.
- Reutiliza componentes y patrones ya presentes.
- Mantén el cambio local a la feature pedida.
- Si necesitas estado, prioriza estado local o un ViewModel concreto.
- Si necesitas datos, reutiliza repositorios y servicios ya existentes.
- No mezcles en el mismo cambio UI + networking + persistencia + IA.

## Forma de trabajar

1. Identifica la feature exacta.
2. Limita el trabajo a una pantalla, subpantalla o componente.
3. Detecta los archivos minimos a tocar.
4. Crea la pieza nueva con el estilo y convenciones del repo.
5. Conecta solo lo imprescindible.
6. Devuelve un cambio pequeno.

## Reglas de implementacion

- Si el usuario pide algo grande, reduce el alcance al primer corte logico.
- Si hay varias opciones, elige la mas conservadora.
- Si una pieza nueva puede vivir como subvista local, no abras una expansion innecesaria.
- Si basta con una extension o helper local, no crees una capa extra.
- Si la nueva funcionalidad depende de IA, no la implementes aqui: deriva a `swift-ai-guarded`.

## Entregable por defecto

Devuelve:

- diff o codigo final
- breve resumen
- notas minimas de integracion si hacen falta

## Ejemplos de uso

- Crear una tarjeta nueva dentro de Dashboard sin tocar Insights.
- Anadir una seccion nueva de validacion en Imports sin rehacer el flujo completo.
- Anadir una accion secundaria en Review Queue sin tocar reglas automaticas.
- Anadir una subvista reutilizable en Transactions sin alterar repositorios.

## Limites explicitos

No toques salvo que se pida:

- navegacion global
- modelos base
- persistencia
- import pipeline completo
- IA / prompts / Foundation Models
- estilos globales de toda la app
