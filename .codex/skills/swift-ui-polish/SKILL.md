---
name: swift-ui-polish
description: Visual and usability polish for SwiftUI views in this app. Use it to improve hierarchy, spacing, readability, empty states, and glass or liquid-glass treatment without touching business logic.
---

# swift-ui-polish

## Cuándo usar esta skill

Usa esta skill cuando el trabajo sea:

- mejorar jerarquia visual
- mejorar espaciado y densidad
- pulir barras, tarjetas, tablas o inspectores
- mejorar estados vacios
- mejorar consistencia de controles
- reforzar estetica glass / liquid glass
- mejorar claridad de dashboard, insights, imports o review queue

No la uses para:

- crear logica nueva
- arreglar bugs funcionales complejos
- tocar IA o prompts
- modificar persistencia o modelos
- rehacer navegacion

## Objetivo

Hacer cambios visuales pequenos pero de alto impacto, manteniendo la app limpia, moderna y coherente.

## Principios visuales

- jerarquia clara antes que decoracion
- menos ruido, mas estructura
- paneles y tarjetas con roles reconocibles
- espaciado consistente
- controles claros y faciles de escanear
- estados vacios utiles
- enfasis visual solo donde aporta decision

## En esta app, prioriza

### Imports

- claridad del flujo por pasos
- drop zone como foco principal
- preview legible
- issues y validation mas escaneables
- recent imports menos ruidoso

### Transactions

- tabla legible
- search flotante bien integrada
- seleccion visible
- inspector mas claro
- acciones agrupadas por prioridad

### Review Queue

- diferencia clara entre lista e inspector
- confianza y categoria faciles de leer
- acciones principales evidentes
- herramientas avanzadas separadas del camino principal

### Dashboard

- hero mas claro
- KPIs menos densos
- copilot con mejor lectura
- mejor equilibrio entre chart, texto y acciones

### Insights

- lectura mas limpia del top bar flotante
- separacion clara entre bloques analiticos
- charts con mejor respiracion
- narrativa AI menos densa y mas escaneable

## Reglas

- No toques logica de negocio.
- No toques repositorios ni servicios.
- No conviertas el pulido en reescritura completa.
- No rehagas toda una pantalla si basta con retocar 1 a 3 componentes.
- Reutiliza estilos y materiales existentes.
- Si un control ya funciona, mejora presentacion sin romper comportamiento.
- Evita exceso de efectos: el glass debe apoyar la jerarquia, no competir con ella.

## Que puedes tocar

- layout
- padding, spacing, alignment
- agrupacion visual
- tipografia y pesos
- estados vacios
- labels y microcopy cortos
- backgrounds, glass, sombras y overlays
- tamano y prioridad de controles

## Que no debes tocar

- navegacion
- persistencia
- reglas
- import parser
- categorizacion
- servicios AI
- contratos de datos

## Entregable por defecto

Devuelve:

- diff + breve resumen

o bien:

- cambios minimos + explicacion corta

## Criterio de calidad

El resultado debe:

- verse mas profesional
- ser mas facil de escanear
- reducir friccion visual
- mantener coherencia con la estetica actual
- no introducir cambios funcionales innecesarios
