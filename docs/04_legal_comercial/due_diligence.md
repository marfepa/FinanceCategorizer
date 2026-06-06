# Auditoría y Due Diligence de Software - FinanceCategorizer

Este documento detalla los controles legales, comerciales, de seguridad y propiedad intelectual (IP) aplicados al repositorio y distribución del código.

---

## 1. Propiedad Intelectual y Licencias de Terceros

El núcleo de la aplicación está desarrollado con tecnologías propietarias de código abierto bajo términos estrictamente permisivos. Toda dependencia externa debe pasar por una revisión de licencia antes de ser integrada al archivo `project.yml`.

### Inventario de Dependencias
- **ZIPFoundation:** Licencia MIT. Utilizada para la descompresión rápida y segura de extractos bancarios en formato comprimido. Cumple con la compatibilidad de atribución al incluir la licencia original en los checks de dependencias de Xcode.

### Directrices de Integración de Dependencias
1. Solo se admiten licencias permisivas (**MIT, Apache 2.0, BSD**).
2. Se prohíbe terminantemente incluir código con licencias de tipo copyleft fuerte (**GPLv3, AGPL**) en los módulos integrados que se empaquetan en la app.

---

## 2. Gestión de Secretos y Datos Sensibles

Para asegurar el cumplimiento de regulaciones financieras y de privacidad (GDPR, APD), se implementan bloqueos y scripts automáticos en CI para evitar fugas involuntarias de información sensible.

### Elementos Críticos Bloqueados
- **Bases de Datos Locales:** Archivos con extensión `.db`, `.sqlite`, `.sqlite3`.
- **Credenciales y Entornos:** Archivos `.env`, claves de API en texto plano, archivos `*.plist` con secretos incrustados.
- **Artefactos de Compilación e Instaladores:** `.dmg`, `.app` generados en el desarrollo o empaquetado.
- **Backups y Logs:** Archivos con patrones `*backup*` o archivos de depuración `*.log`.

---

## 3. Política de Pruebas con Datos Reales (Anonimización)

Queda estrictamente prohibido subir estados de cuenta bancaria reales o información personal identificable (PII) de los desarrolladores o usuarios al repositorio.

### Excepciones Permitidas para Fixtures
Solo se permite subir datos bancarios de prueba bajo las siguientes rutas y prefijos específicos:
- `**/tests/fixtures/anonymous_*`
- `**/tests/fixtures/demo_*`
- `**/Tests/UnitTests/Fixtures/anonymous_*`
- `**/Tests/UnitTests/Fixtures/demo_*`

*Nota:* Todos los archivos incluidos en estas excepciones deben ser validados mediante script para garantizar que los nombres de usuario, números de cuenta, saldos iniciales y localizaciones geográficas específicas hayan sido reemplazados por valores mock genéricos.

---

## 4. Auditoría de Seguridad de IA y Telemetría

La aplicación cuenta con integraciones de modelos de lenguaje (AI). Se aplican las siguientes reglas comerciales y de seguridad:
1. **Consentimiento Explícito (Opt-in):** No se envían descripciones de transacciones a proveedores de modelos externos sin que el usuario active la casilla correspondiente en la interfaz de Ajustes.
2. **Uso de Datos en Tránsito:** Toda llamada a modelos remotos se realiza a través de conexiones HTTPS cifradas. No se retiene historial de transacciones en servidores externos para entrenamiento de modelos de terceros.
3. **Local/Edge First:** Se prioriza la categorización mediante reglas heurísticas locales y aprendizaje de máquina local (`CreateMLTrainer`, `HeuristicCategorizationService`) para minimizar el uso de llamadas a la red.
