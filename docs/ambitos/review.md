# Ámbito: review (cola de revisión y correcciones)

## 1. Estado Actual
- **Objetivo del ámbito:** que el usuario confirme o corrija la categoría de los movimientos dudosos, con decisiones visibles, atómicas y reversibles.
- **Funcionalidades completadas:**
  - [x] Cola de revisión iOS/macOS con filtros, sugerencias y lotes de similares.
  - [x] Lotes de corrección (`CorrectionBatchService`): un único `save` por acción, snapshot del estado previo y deshacer (aviso, ⌘Z, sacudir en iOS).
  - [x] "Aplicar a similares" con confirmación y número exacto de afectados.
  - [x] La propagación nunca toca movimientos con origen `manual`.
  - [x] Reglas: en la cola solo se crean si el usuario lo pide; si el motor las sugiere, se ofrecen en el aviso.
  - [x] Posibles traspasos entre cuentas propias (`TransferPairDetector` + `TransferPairService`): se proponen en la cola (filtro en macOS, sección en iOS) y se confirman como un lote deshacible. Aviso en Cuentas.
- **Pendiente / Roadmap:**
  - [ ] Conectar deshacer en Transacciones y Auditoría de categorías (ya pasan por el servicio, falta UI).
  - [ ] Historial persistente entre sesiones (requiere estrategia de migración, ver Trampas).
  - [ ] `dismissSuggestedCategory` y `updateSelectedKind` todavía no son deshacibles.
  - [ ] Persistir parejas y descartes de traspasos (requiere congelar el esquema V1).
  - [ ] Señales fuertes de traspaso: IBAN propio y nombre del titular (hoy no se guardan).
- **Deuda técnica:** el servicio carga todos los `Transaction` en memoria para calcular la propagación; con historiales grandes conviene acotar por `kindRaw` y signo en el `#Predicate`.

## 2. Terreno de Juego (Ficheros y Límites)
- **Archivos bajo propiedad:**
  - `Shared/Services/Learning/CorrectionBatchService.swift`
  - `Shared/Services/Learning/LearningService.swift` (`CorrectionLearningService`, `RuleSuggestionEngine`)
  - `Shared/Features/Transactions/ReviewQueueViewModel.swift`
  - `Shared/UI/Components/CorrectionUndoBanner.swift`, `Shared/UI/Components/TransferPairRow.swift`
  - `Shared/Services/Insights/TransferPairDetector.swift`, `Shared/Services/Insights/TransferPairService.swift`
  - `Platform/macOSUI/Screens/MacReviewQueueView.swift`, `Platform/iOSUI/Screens/IOSReviewQueueView.swift`
  - `Tests/UnitTests/CorrectionBatchServiceTests.swift`
- **Dependencias externas (solo lectura):** `TransactionRepository` (`TransactionNameMatcher`), `CategoryDirectionPolicy`, `LocalModelManager`, modelos `Transaction`, `UserCorrection`, `Merchant`, `Rule`.

## 3. Modelo de Datos y Dominio
- **Entidades:** `CorrectionBatch` (en memoria, máx. 20 por sesión) agrupa los `TransactionState`, `UserCorrection` insertadas, `Merchant` y `Rule` creados o modificados por una acción.
- **Máquina de estados:** `[aplicado] -> [revertido]`. Revertir dos veces es un no-op.
- **Invariantes:**
  - Una categoría de gasto nunca se aplica a un ingreso ni al revés (`CategoryDirectionPolicy`), también en lotes.
  - Todo lo de un lote se guarda o se descarta junto; el reentrenamiento del modelo va después del `save` y su fallo no deshace nada.
  - Un lote solo se revierte si sus movimientos siguen con `updatedAt == appliedAt`; si no, `conflictingLaterChanges`.

## 4. Trampas Encontradas (Gotchas y Lecciones Aprendidas)
- ⚠ **Migraciones SwiftData:** `FinanceSchemaV1` referencia las clases `@Model` vivas. Añadir una `FinanceSchemaV2` sin congelar antes V1 en tipos anidados deja el store existente sin versión reconocible (error 134504 de staged migration) y la app entra en modo recuperación. Cualquier cambio de modelo exige primero congelar V1.
- ⚠ **Contextos por llamada:** cada repositorio crea un `ModelContext` nuevo por operación; para atomicidad hay que trabajar en un único contexto (como hace `CorrectionBatchService`), no encadenar llamadas a repositorios.
- ⚠ **Reglas sugeridas:** `RuleSuggestionEngine.shouldSuggestRule` depende de `categoryID` y `confidence` actuales; evaluarlo después de mutar el movimiento siempre devuelve verdadero.
- ⚠ **`applyCorrection` legado:** Auditoría y Transacciones siguen propagando por nombre (comportamiento histórico) pero ya excluyen decisiones manuales, y usan `recordHistory: false` para no expulsar del historial los lotes deshacibles de la cola.
- ⚠ **Procesos que escriben `updatedAt`** (recategorización, auditoría de duplicados) invalidan el deshacer de lotes previos sobre esos movimientos: es intencionado.
- ⚠ **`CategoryDirectionPolicy`:** transferencias y ajustes son compatibles con cualquier categoría; solo ingreso↔gasto se rechaza. Los previews filtran incompatibles con `compatibleTransactionIDs` para que un lote confirmado no falle entero.
- ⚠ **Deshacer exige que existan todos los movimientos del lote:** si uno se borró, la reversión se rechaza entera (`transactionNotFound`) en vez de restaurar a medias.
- ⚠ **`isSimilar` (VM) y `TransactionNameMatcher` (propagación) son criterios distintos:** el diálogo de confirmación separa "de la cola" y "anteriores del mismo comercio"; al confirmar se recalcula y, si cambió, se vuelve a pedir confirmación.
- ⚠ **`accountName` es opcional al importar:** sin nombre de cuenta, el detector solo empareja movimientos de importaciones distintas y con menor confianza. Animar a nombrar cuentas mejora la detección.
- ⚠ **Traspasos ambiguos:** si un movimiento tiene más de una contrapartida posible no se propone ninguna (ADR 0002). No "arreglar" eligiendo la más cercana sin una señal adicional.
- ⚠ **Traspasos: misma divisa y misma cantidad.** El detector agrupa por importe y divisa; un traspaso con cambio de moneda nunca coincide en importe, así que no se propone.
- ⚠ **Compra y devolución:** dos movimientos con la misma descripción normalizada (misma tienda) no son un traspaso aunque el importe coincida.
- ⚠ **Ventana de días en días naturales** (`calendarDayGap`), no en segundos: el cambio de hora convierte 3 días en 71 o 73 horas.
- ⚠ **Confirmar una pareja revalida** que ningún lado se haya decidido a mano ni marcado como traspaso desde la propuesta (`transferPairNoLongerValid`).
- ⚠ **La barra segmentada de la cola ya no cabe con 5 filtros en 420 pt** (deuda previa): los traspasos van en un botón aparte, no como sexto segmento.

