# Roadmap de escalado

## Fase 0 - Fundacion de repositorio

Objetivo: poder trabajar sin perder control.

- Crear repositorio Git de producto.
- Definir `.gitignore` para Xcode, Node, DerivedData, `node_modules`, archivos bancarios reales y datos privados.
- Mover esta documentacion al lugar definitivo.
- Activar proteccion de rama principal.
- Crear CI minimo: build iOS, build macOS, tests unitarios.

Criterio de salida: cualquier cambio entra por PR y ejecuta validaciones basicas.

## Fase 1 - Seguridad de datos

Objetivo: evitar perdida de datos financieros.

- Sustituir borrado automatico de SwiftData store por backup y recuperacion.
- Definir estrategia de migracion de esquemas.
- Crear export de emergencia CSV/JSON.
- Documentar ubicacion de datos locales y politica de privacidad.

Criterio de salida: una store corrupta o incompatible no se borra silenciosamente.

## Fase 2 - Importacion end-to-end

Objetivo: que la app importe extractos reales de forma fiable.

- Crear fixtures anonimizados por banco/formato.
- Estabilizar CSV Openbank/Cajamar/ABANCA.
- Separar soporte PDF real de placeholders Santander/BBVA.
- Probar duplicados por fichero y por filas.
- Mejorar diagnosticos de mapeo manual.

Criterio de salida: importacion validada con fixtures versionados y tests repetibles.

## Fase 3 - Categorizacion y revision

Objetivo: reducir trabajo manual sin ocultar incertidumbre.

- Consolidar categorias base y reglas por defecto.
- Testear thresholds y decisiones de review queue.
- Registrar aprendizaje por correccion del usuario.
- Crear metricas de cobertura: autoaceptadas, sugeridas, pendientes y corregidas.

Criterio de salida: el usuario entiende por que una transaccion fue categorizada o enviada a revision.

## Fase 4 - Producto multiplataforma

Objetivo: experiencia coherente en iPhone, iPad y Mac.

- Completar pantallas principales con flujos reales.
- Pulir tablas, filtros, busqueda, inspector y acciones masivas en macOS.
- Ajustar navegacion iPad sin duplicar UI.
- Definir snapshots o pruebas UI para rutas criticas.

Criterio de salida: las tareas principales se pueden completar sin depender de datos demo.

## Fase 5 - Insights e IA

Objetivo: aportar valor analitico sin comprometer confianza.

- Separar insights deterministas de resumentes AI.
- Hacer transparentes las limitaciones de Foundation Models.
- Testear idioma ES/EN en prompts y salidas.
- Introducir evaluaciones con casos esperados.

Criterio de salida: con IA desactivada, la app sigue siendo plenamente util.
