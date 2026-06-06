#!/usr/bin/env bash
# create_release_candidate.sh
# Automatiza el flujo para preparar una release: crea rama release/x.y.z y bumpéa versión localmente sin subir tags.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_YML="$ROOT_DIR/project.yml"
CHANGELOG="$ROOT_DIR/docs/CHANGELOG.md"

# 1. Validar parámetros
if [[ $# -ne 1 ]]; then
  echo "Uso: $0 <version>"
  echo "Ejemplo: $0 0.3.0-alpha.1"
  exit 1
fi

VERSION="$1"

# Validar formato SemVer básico
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  echo "ERROR: La versión '$VERSION' no cumple con el formato SemVer (ej. 0.3.0 o 0.3.0-alpha.1)"
  exit 1
fi

# 2. Validar estado de Git
if [[ -n "$(git status --porcelain | grep -v '??' || true)" ]]; then
  echo "ERROR: El directorio de trabajo tiene cambios sin confirmar. Haz commit o stash antes de proceder."
  exit 1
fi

echo "==> Preparando el Release Candidate para la versión: $VERSION..."

# 3. Crear y cambiar a la rama de release
BRANCH_NAME="release/$VERSION"
echo "==> Creando y cambiando a la rama '$BRANCH_NAME'..."
git checkout -b "$BRANCH_NAME"

# 4. Modificar project.yml
if [[ -f "$PROJECT_YML" ]]; then
  echo "==> Actualizando versión de marketing en project.yml..."
  # Reemplazar la línea de MARKETING_VERSION usando Perl (altamente portable en macOS y Linux)
  perl -pi -e "s/MARKETING_VERSION: .*/MARKETING_VERSION: $VERSION/g" "$PROJECT_YML"
  
  # Incrementar automáticamente el build number (CURRENT_PROJECT_VERSION)
  CURRENT_BUILD=$(grep -E 'CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -n 1 | awk '{print $2}')
  if [[ -n "$CURRENT_BUILD" ]]; then
    NEW_BUILD=$((CURRENT_BUILD + 1))
    perl -pi -e "s/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: $NEW_BUILD/g" "$PROJECT_YML"
    echo "    MARKETING_VERSION actualizada a: $VERSION"
    echo "    CURRENT_PROJECT_VERSION incrementada a: $NEW_BUILD"
  else
    echo "    WARNING: CURRENT_PROJECT_VERSION no encontrada en project.yml"
  fi
else
  echo "WARNING: project.yml no encontrado. Omitiendo actualización de versión de compilación."
fi

# 5. Modificar CHANGELOG.md
if [[ -f "$CHANGELOG" ]]; then
  echo "==> Agregando cabecera de versión al CHANGELOG.md..."
  DATE=$(date +%Y-%m-%d)
  HEADER="## [$VERSION] - $DATE"
  
  # Insertar el nuevo bloque de versión después del título del archivo (# Changelog)
  # Usamos perl para buscar "# Changelog" e insertar el bloque debajo
  perl -pi -e "s/(# Changelog\n)/\$1\n$HEADER\n\n### Added\n- Release candidate preparado para la versión $VERSION.\n\n### Changed\n\n### Fixed\n\n/i" "$CHANGELOG"
  echo "    CHANGELOG.md actualizado con stub para $VERSION"
else
  # Si no existe, lo creamos
  echo "==> Creando CHANGELOG.md..."
  DATE=$(date +%Y-%m-%d)
  cat <<EOF > "$CHANGELOG"
# Changelog

## [$VERSION] - $DATE

### Added
- Release candidate preparado para la versión $VERSION.

### Changed

### Fixed
EOF
  echo "    CHANGELOG.md creado con stub para $VERSION"
fi

# 6. Confirmar cambios localmente
echo "==> Realizando commit del incremento de versión..."
git add "$PROJECT_YML" "$CHANGELOG" 2>/dev/null || true
git commit -m "chore: preparar release candidate $VERSION"

echo "==> ¡Listo! La rama '$BRANCH_NAME' ha sido configurada localmente."
echo "    Revisa los cambios de versión y completa el CHANGELOG.md."
echo "    Para validar localmente antes de empujar, puedes correr:"
echo "      ./scripts/check_version_consistency.sh"
echo "      ./scripts/verify_no_sensitive_files.sh"
exit 0
