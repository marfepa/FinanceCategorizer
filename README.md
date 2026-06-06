# FinanceCategorizer

FinanceCategorizer es una app multiplataforma para iPhone, iPad y Mac centrada en importacion, categorizacion y analisis de finanzas personales.

El proyecto se genera con XcodeGen y mantiene:

- nucleo compartido en Swift
- persistencia local con SwiftData
- UI especifica por plataforma
- servicios de importacion, categorizacion, aprendizaje e IA con fallback conservador
- un design system compartido para mantener coherencia visual

## Estructura del proyecto

- `Apps/`: puntos de entrada y scene wiring por plataforma
- `Shared/`: dominio, datos, repositorios, servicios, AI, features y UI comun
- `Platform/`: pantallas y componentes especificos de iOS y macOS
- `Resources/`: assets, localizacion, fuentes y recursos de vista previa
- `Tests/`: unit tests y UI tests
- `scratch/`: scripts o experimentos locales que no forman parte del producto

## Proyectos y targets

El proyecto Xcode se genera desde `project.yml` y crea estos targets:

- `FinanceCategorizerIOS`
- `FinanceCategorizerMac`
- `FinanceCategorizerTests`
- `FinanceCategorizerUITestsIOS`
- `FinanceCategorizerUITestsMac`

## Arranque rapido

1. Entra en la carpeta del proyecto:

   ```bash
   cd "/Users/mariofernandez/Desktop/Economía familiar/FinanceCategorizer"
   ```

2. Genera el proyecto Xcode:

   ```bash
   xcodegen generate
   ```

3. Abre el proyecto generado:

   ```bash
   open FinanceCategorizer.xcodeproj
   ```

## Flujo de arranque

1. La app entra por `Apps/iOS/FinanceCategorizerIOSApp.swift` o `Apps/macOS/FinanceCategorizerMacApp.swift`
2. Ambas crean e inyectan `AppContainer.shared`
3. `AppContainer` monta `ModelContainer`, repositorios y servicios
4. La UI raiz carga la shell principal:
   - iOS: `TabView`
   - macOS: `NavigationSplitView`

## Estado actual del scaffold

El repositorio ya incluye:

- modelos SwiftData base
- repositorios y DTOs para el dominio financiero
- pipeline de categorizacion con thresholds conservadores
- servicios de importacion para CSV, Excel y PDF
- servicios de normalizacion y aprendizaje local
- integraciones AI con Foundation Models protegidas por availability checks
- pantallas separadas para iOS y macOS
- componentes reutilizables del design system

## Carpetas clave

- `Shared/App/`: `AppContainer`, configuracion general y feature flags
- `Shared/Domain/`: modelos, enums y value objects
- `Shared/Data/`: persistence, repositorios y DTOs
- `Shared/Services/`: import, export, normalization, categorization, learning e insights
- `Shared/AI/`: Foundation Models y prompts
- `Shared/UI/`: design system y componentes compartidos
- `Shared/Features/`: view models de dashboard, import, rules, categories, transactions, review queue, settings e insights
- `Platform/iOSUI/`: pantallas SwiftUI de iOS
- `Platform/macOSUI/`: pantallas y componentes SwiftUI de macOS

## Convenciones del repositorio

- Mantener la logica de negocio fuera de las vistas cuando sea posible.
- Preferir view models, services y repositories para comportamiento no trivial.
- No mover UI especifica de macOS o iOS a `Shared/` salvo que realmente sea reutilizable.
- Mantener los fallbacks deterministicos cuando se toque IA.
- Respetar el flujo de importacion: preview, diagnostics, import, summary.
- Conservar el review queue para casos ambiguos o de baja confianza.

## Archivos de referencia

- `AGENTS.md`: reglas de trabajo y arquitectura para este repo
- `docs/`: auditoria tecnica, arquitectura objetivo, roadmap, QA, backlog y ADRs
- `SETUP_XCODE.md`: guia para generar y cablear el proyecto en Xcode
- `project.yml`: fuente de verdad de targets, schemes y dependencias
- `Resources/README.md`: ubicacion de assets y recursos visuales
- `Tests/README.md`: division de los targets de prueba

## Validacion recomendada

Antes de cerrar cambios importantes, sigue este orden cuando aplique:

1. Regenerar proyecto si cambio `project.yml`:

   ```bash
   xcodegen generate
   ```

2. Compilar iOS si tocaste UI o logica compartida:

   ```bash
   xcodebuild -scheme FinanceCategorizerIOS -destination 'platform=iOS Simulator,name=iPhone 17' build
   ```

3. Compilar macOS si tocaste UI o logica compartida:

   ```bash
   xcodebuild -scheme FinanceCategorizerMac build
   ```

4. Ejecutar tests focalizados cuando proceda:

   ```bash
   xcodebuild test -scheme FinanceCategorizerIOS -destination 'platform=iOS Simulator,name=iPhone 17'
   ```

El repo incluye CI en `.github/workflows/ci.yml` con generacion XcodeGen, build iOS, build macOS, comprobacion de localizacion y unit tests.

## Siguiente paso natural

Lo mas rentable ahora mismo suele ser uno de estos dos caminos:

1. completar la importacion real y conectar la primera lista de transacciones al repositorio
2. pulir la UX de las pantallas principales sin tocar la arquitectura base
