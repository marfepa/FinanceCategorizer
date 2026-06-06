# Setup Xcode

Esta guia convierte el scaffold en un proyecto Xcode limpio para:

- iPhone + iPad
- Mac
- nucleo compartido con SwiftData
- tests unitarios y UI tests separados

## 1. Crear el proyecto base

1. Abre Xcode.
2. `File > New > Project...`
3. Elige `App`.
4. Product Name: `FinanceCategorizerIOS`
5. Interface: `SwiftUI`
6. Language: `Swift`
7. Marca `Use SwiftData`
8. Guarda el proyecto dentro de:
   `/Users/mariofernandez/Desktop/Economía familiar/FinanceCategorizer`

Nota:
Xcode creara un `.xcodeproj` inicial. Lo vamos a reutilizar y luego renombraremos el target visualmente si hace falta.

## 2. Crear los targets exactos

Debes terminar con estos 5 targets:

- `FinanceCategorizerIOS`
- `FinanceCategorizerMac`
- `FinanceCategorizerTests`
- `FinanceCategorizerUITestsIOS`
- `FinanceCategorizerUITestsMac`

### Crear `FinanceCategorizerMac`

1. Selecciona el proyecto en el navigator.
2. Pulsa `+` debajo de `TARGETS`.
3. Elige `App`.
4. Platform: `macOS`
5. Product Name: `FinanceCategorizerMac`
6. Interface: `SwiftUI`
7. Language: `Swift`
8. Marca `Use SwiftData`

### Crear tests

1. `File > New > Target...`
2. Crea un target `Unit Testing Bundle` con nombre `FinanceCategorizerTests`
3. Crea un target `UI Testing Bundle` con nombre `FinanceCategorizerUITestsIOS`
4. Crea un target `UI Testing Bundle` con nombre `FinanceCategorizerUITestsMac`

## 3. Limpiar archivos generados por Xcode

Elimina del proyecto los archivos SwiftUI generados automaticamente que no vayas a usar.

Normalmente:

- `ContentView.swift`
- `Item.swift`
- archivos de app duplicados creados por Xcode
- tests placeholder genericos

Si quieres mantenerlos unos minutos para comparar, quitalos del target al menos.

## 4. Crear los groups visuales

En el Project Navigator crea estos groups en la raiz:

- `Apps`
- `Shared`
- `Platform`
- `Resources`
- `Tests`

Importante:
usa `New Group`, no hace falta `New Folder Reference`.

## 5. Añadir la carpeta scaffold al proyecto

1. Click derecho sobre la raiz del proyecto.
2. `Add Files to "FinanceCategorizerIOS"...`
3. Selecciona el contenido de:
   `/Users/mariofernandez/Desktop/Economía familiar/FinanceCategorizer`
4. Desmarca copiar si ya esta en la ubicacion final.
5. Usa `Create groups`, no `folder references`.

## 6. Estructura visual recomendada en Xcode

Organiza asi:

- `Apps`
  - `iOS`
  - `macOS`
- `Shared`
  - `App`
  - `Domain`
  - `Data`
  - `Services`
  - `AI`
  - `Features`
  - `UI`
- `Platform`
  - `iOSUI`
  - `macOSUI`
- `Resources`
- `Tests`

## 7. Target membership exacto

### Solo target `FinanceCategorizerIOS`

Asigna estos archivos unicamente al target iOS:

- `Apps/iOS/FinanceCategorizerIOSApp.swift`
- `Apps/iOS/IOSAppRootView.swift`
- todo `Platform/iOSUI/...`

### Solo target `FinanceCategorizerMac`

Asigna estos archivos unicamente al target Mac:

- `Apps/macOS/FinanceCategorizerMacApp.swift`
- `Apps/macOS/MacAppRootView.swift`
- todo `Platform/macOSUI/...`

### Targets `FinanceCategorizerIOS` y `FinanceCategorizerMac`

Asigna a ambos targets todo lo compartido:

- `Shared/App/...`
- `Shared/Domain/...`
- `Shared/Data/...`
- `Shared/Services/...`
- `Shared/AI/...`
- `Shared/Features/...`
- `Shared/UI/...`

### Resources

Asignalos a ambos app targets cuando existan:

- `Assets.xcassets`
- `Localizable.xcstrings`
- `Fonts/...`

### Tests

Usa esta regla:

- `FinanceCategorizerTests`: unit tests puros de dominio, servicios, repositorios
- `FinanceCategorizerUITestsIOS`: solo UI tests de iOS
- `FinanceCategorizerUITestsMac`: solo UI tests de macOS

## 8. Build Settings que debes revisar

Para ambos app targets revisa:

1. `Swift Language Version`: Swift actual del proyecto
2. `iOS Deployment Target`: el que quieras soportar
3. `macOS Deployment Target`: el que quieras soportar
4. `Bundle Identifier`
5. `Product Name`
6. `Development Assets` si usas previews

Recomendacion inicial:

- iOS 17+
- macOS 14+

Porque el scaffold usa SwiftUI moderno y SwiftData.

## 9. SwiftData y arranque

Los dos app targets deben incluir:

- `Shared/App/AppContainer.swift`
- `Shared/Data/Persistence/FinanceSchema.swift`
- `Shared/Data/Persistence/ModelContainerFactory.swift`

Flujo de arranque actual:

1. La app entra por `FinanceCategorizerIOSApp` o `FinanceCategorizerMacApp`
2. Inyecta `AppContainer.shared`
3. `AppContainer` crea el `ModelContainer`
4. Se conectan repositorios y servicios
5. La UI raiz recibe `modelContainer` y entorno compartido

## 10. Orden real de cableado

Haz esto en este orden:

1. Crea proyecto y targets
2. Añade grupos
3. Importa archivos scaffold
4. Corrige target membership
5. Compila iOS
6. Compila macOS
7. Ajusta recursos
8. Crea tests vacios por target
9. Empieza a sustituir placeholders

## 11. Primera compilacion esperada

Tu objetivo no es tener funcionalidades completas en la primera apertura.
Tu objetivo es este:

- el target iOS abre con `TabView`
- el target Mac abre con `NavigationSplitView`
- el contenedor SwiftData se crea
- no hay archivos cruzados entre targets

## 12. Errores tipicos y como evitarlos

### Error: dos `@main`

Causa:
ambos archivos `FinanceCategorizerIOSApp.swift` y `FinanceCategorizerMacApp.swift` estan marcados en el mismo target.

Solucion:
deja cada `@main` solo en su plataforma.

### Error: vista iOS compilando en Mac o al reves

Causa:
has metido `Platform/iOSUI` y `Platform/macOSUI` en ambos targets.

Solucion:
separa el target membership estrictamente por plataforma.

### Error: recursos duplicados

Causa:
el mismo asset o strings file esta copiado varias veces.

Solucion:
usa una sola referencia en `Resources`.

### Error: tests enlazados al target incorrecto

Causa:
UI tests iOS apuntando a Mac, o al reves.

Solucion:
revisa `Target Application` en cada UI test target.

## 13. Mapa rapido de cada target

### `FinanceCategorizerIOS`

- `Apps/iOS`
- `Platform/iOSUI`
- todo `Shared`
- `Resources`

### `FinanceCategorizerMac`

- `Apps/macOS`
- `Platform/macOSUI`
- todo `Shared`
- `Resources`

### `FinanceCategorizerTests`

- tests unitarios
- enlace a modulos compartidos

### `FinanceCategorizerUITestsIOS`

- UI tests iOS
- target application: `FinanceCategorizerIOS`

### `FinanceCategorizerUITestsMac`

- UI tests Mac
- target application: `FinanceCategorizerMac`

## 14. Primeros archivos que debes tocar despues

Cuando el proyecto compile, sigue por aqui:

1. `Shared/Data/Persistence/FinanceSchema.swift`
2. `Shared/Data/Repositories/TransactionRepository.swift`
3. `Shared/Services/Import/ImportOrchestrator.swift`
4. `Platform/iOSUI/Screens/IOSImportView.swift`
5. `Platform/macOSUI/Screens/MacTransactionsView.swift`

## 15. Checklist final

Antes de seguir con producto, confirma:

- `FinanceCategorizerIOS` compila
- `FinanceCategorizerMac` compila
- cada plataforma tiene un unico `@main`
- `Shared/...` entra en ambos app targets
- `Platform/iOSUI/...` solo entra en iOS
- `Platform/macOSUI/...` solo entra en Mac
- `Tests` estan separados por tipo

Si quieres, el siguiente paso te lo puedo dejar ya preparado como:

- un `project.yml` de XcodeGen para generar el `.xcodeproj` automaticamente
- o una fase 2 con importacion real de CSV y lista de transacciones

## 16. Opcion recomendada: generar todo con XcodeGen

He dejado un archivo `project.yml` en la raiz del scaffold.

Flujo:

1. Instala XcodeGen si no lo tienes
2. En Terminal entra en:
   `/Users/mariofernandez/Desktop/Economía familiar/FinanceCategorizer`
3. Ejecuta:
   `xcodegen generate`
4. Abre `FinanceCategorizer.xcodeproj`

El `project.yml` ya define:

- `FinanceCategorizerIOS`
- `FinanceCategorizerMac`
- `FinanceCategorizerTests`
- `FinanceCategorizerUITestsIOS`
- `FinanceCategorizerUITestsMac`

Y separa automaticamente:

- `Apps/iOS` solo para iOS
- `Apps/macOS` solo para Mac
- `Platform/iOSUI` solo para iOS
- `Platform/macOSUI` solo para Mac
- `Shared` para ambos

Tambien he dejado tests placeholder en:

- `Tests/UnitTests`
- `Tests/UITests_iOS`
- `Tests/UITests_macOS`
