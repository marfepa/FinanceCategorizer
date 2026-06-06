# FinanceCategorizer Agent Instructions

Este archivo contiene las directrices arquitectónicas y decisiones clave de diseño para el mantenimiento y evolución de FinanceCategorizer.

## Principios Generales
- **Actúa como Ingeniero Principal.**
- **Mantén la funcionalidad exacta** de la lógica de negocio al adaptar código.
- **Sintaxis moderna:** Usa Swift 5.10+, SwiftUI moderno y SwiftData.
- **Modularidad:** Genera archivos modulares, evita monolitos.

## Localización y Multi-idioma
- **Infraestructura:** La app soporta Castellano e Inglés mediante el uso de `Localizable.strings` y `AppLanguage.localized()`.
- **Enum de Idioma:** `AppLanguage` gestiona los idiomas soportados (`en`, `es`) y provee métodos de ayuda para formateo y traducción (`localized`, `formatCurrency`, `formatPercent`).
- **Persistencia:** La preferencia de idioma se guarda en `UserDefaults` mediante `@AppStorage("appLanguage")`.
- **Cambio en tiempo de ejecución:** El idioma se aplica inyectando `.environment(\.locale, locale)` en la raíz de la aplicación y pasando explícitamente el `AppLanguage` a los servicios que lo requieran.
- **Nuevas Cadenas:** Todas las nuevas cadenas de la UI deben localizarse obligatoriamente.
- **Servicios e IA:** Toda generación de texto dinámico (Copilotos de IA, Resúmenes de Análisis, Motores de Insights) **DEBE** evitar lógica ternaria hardcoded (`language == .spanish ? ...`). En su lugar, usa `language.localized("key", arguments...)` operando sobre claves estandarizadas en `Localizable.strings`.
- **Prompts de IA:** Los prompts enviados a modelos de lenguaje deben inyectar el idioma esperado (ej. `language.title`) para que la respuesta sea generada nativamente en el idioma del usuario.

## Estructura de Datos
- **Persistence:** Uso de SwiftData con `ModelContainer` inyectado vía `AppContainer`.
- **Repositorios:** Lógica de acceso a datos desacoplada de la UI.

## UI / UX
- **Design System:** Usa `AppColors`, `AppMaterials`, `AppRadius` y `AppSpacing` definidos en `Shared/UI/DesignSystem`.
- **Liquid Glass (macOS):** La app adopta el look nativo de macOS 15+ (v26).
    - **Estrategia de 3 Capas:**
        1. `ControlGlass`: Para controles interactivos (botones, chips, drop zones). Usa `.buttonStyle(.glassProminent)` y `.glassEffect`.
        2. `NavigationGlass`: Para Toolbar, Sidebar y filtros superiores.
        3. `ContentMaterial`: Para el contenido principal (tarjetas de dashboard, listas, tablas). Usa materiales estándar (`.regularMaterial`).
    - **Controles Nativos:** Prioriza el uso de componentes estándar de SwiftUI (`NavigationSplitView`, `Toolbar`, `List`) para que el sistema aplique Liquid Glass automáticamente.
    - **Menos es más:** Evita el uso excesivo de divisores. Usa el espaciado (múltiplos de 8) y la agrupación visual para separar contenidos.
- **Multiplataforma:** Mantén pantallas específicas en `Platform/iOSUI` and `Platform/macOSUI` cuando la experiencia nativa lo requiera.
