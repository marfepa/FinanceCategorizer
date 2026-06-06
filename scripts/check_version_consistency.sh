#!/usr/bin/env bash
# check_version_consistency.sh
# Verifica que las versiones en el manifiesto project.yml, la rama de release y el CHANGELOG estén sincronizadas.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_YML="$ROOT_DIR/project.yml"
CHANGELOG="$ROOT_DIR/docs/CHANGELOG.md"

if [[ ! -f "$PROJECT_YML" ]]; then
  echo "ERROR: project.yml no encontrado en $PROJECT_YML"
  exit 1
fi

# 1. Obtener la versión de marketing de project.yml
# Buscamos MARKETING_VERSION en project.yml (e.g. MARKETING_VERSION: 0.3.0)
YML_VERSION=$(grep -E 'MARKETING_VERSION:' "$PROJECT_YML" | head -n 1 | awk '{print $2}' | tr -d '"'\''')
echo "==> MARKETING_VERSION en project.yml: '$YML_VERSION'"

if [[ -z "$YML_VERSION" ]]; then
  echo "ERROR: MARKETING_VERSION no se pudo leer de project.yml"
  exit 1
fi

# 2. Comprobar concordancia con la rama de Git actual (si es de release)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
echo "==> Rama de Git actual: '$CURRENT_BRANCH'"

if [[ "$CURRENT_BRANCH" =~ ^release/ ]]; then
  BRANCH_VERSION="${CURRENT_BRANCH#release/}"
  # Quitar 'v' inicial si el desarrollador la incluyó por error (ej. release/v0.3.0 -> 0.3.0)
  BRANCH_VERSION="${BRANCH_VERSION#v}"
  
  if [[ "$YML_VERSION" != "$BRANCH_VERSION" ]]; then
    echo "ERROR: Inconsistencia de versiones detectada!"
    echo "  Versión de la rama: '$BRANCH_VERSION' (rama '$CURRENT_BRANCH')"
    echo "  Versión en project.yml: '$YML_VERSION'"
    exit 1
  else
    echo "OK: La versión de la rama coincide con project.yml."
  fi
fi

# 3. Comprobar concordancia con la cabecera más reciente del CHANGELOG.md
if [[ -f "$CHANGELOG" ]]; then
  # Extrae la primera cabecera de versión del changelog (ej. ## [0.3.0] o ## 0.3.0-alpha.1)
  CHANGELOG_VERSION=$(grep -E '^##\s+\[?[vV]?[0-9]+\.[0-9]+\.[0-9]+' "$CHANGELOG" | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?' | head -n 1 || true)
  echo "==> Versión más reciente en CHANGELOG.md: '$CHANGELOG_VERSION'"
  
  if [[ -n "$CHANGELOG_VERSION" ]]; then
    # Quitamos 'v' o 'V' inicial para la comparación
    CLEANED_CHANGELOG_VERSION="${CHANGELOG_VERSION#[vV]}"
    
    if [[ "$CLEANED_CHANGELOG_VERSION" != "$YML_VERSION"* ]]; then
      echo "ERROR: Inconsistencia con el CHANGELOG.md!"
      echo "  Versión en CHANGELOG.md: '$CLEANED_CHANGELOG_VERSION'"
      echo "  Versión en project.yml: '$YML_VERSION'"
      exit 1
    else
      echo "OK: La versión del CHANGELOG es consistente con project.yml."
    fi
  else
    echo "WARNING: No se pudo identificar una cabecera de versión clara en el CHANGELOG.md"
  fi
else
  echo "WARNING: CHANGELOG.md no encontrado en $CHANGELOG"
fi

echo "OK: Comprobaciones de consistencia de versión completadas con éxito."
exit 0
