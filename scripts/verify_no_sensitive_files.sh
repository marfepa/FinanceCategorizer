#!/usr/bin/env bash
# verify_no_sensitive_files.sh
# Escanea el repositorio para asegurar que ningún archivo sensible esté presente.
# Se permiten excepciones bajo tests/fixtures/anonymous_*, tests/fixtures/demo_*,
# Tests/UnitTests/Fixtures/anonymous_*, o Tests/UnitTests/Fixtures/demo_*.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Iniciando escaneo de archivos sensibles en: $ROOT_DIR"

# Extensiones prohibidas
FORBIDDEN_EXTS=("db" "sqlite" "sqlite3" "env" "dmg" "app")

# Patrones prohibidos
FORBIDDEN_PATTERNS=("*backup*" "*.log")

SENSITIVE_FOUND=0

# Función para verificar si un archivo es una excepción permitida
is_exception() {
  local filepath="$1"
  # Convertir a minúsculas para comparación robusta
  local lower_path
  lower_path=$(echo "$filepath" | tr '[:upper:]' '[:lower:]')

  # Criterio de excepciones:
  # Permitir si el archivo está dentro de una carpeta 'fixtures' y empieza con 'anonymous_' o 'demo_'
  if [[ "$lower_path" =~ /fixtures/anonymous_[^/]+$ ]] || \
     [[ "$lower_path" =~ /fixtures/demo_[^/]+$ ]]; then
    return 0 # Es excepción (permitido)
  fi
  return 1 # No es excepción (bloqueado)
}

# Buscamos archivos omitiendo directorios de compilación y control de versiones
while IFS= read -r filepath; do
  # Ignorar si el archivo no existe (por si acaso find da nombres vacíos)
  [[ -f "$filepath" ]] || continue

  # Obtener ruta relativa para claridad en los logs
  rel_path="${filepath#"$ROOT_DIR"/}"
  filename=$(basename "$filepath")
  ext="${filename##*.}"

  # Verificar si el archivo está en la lista de excepciones permitidas
  if is_exception "$rel_path"; then
    continue
  fi

  # 1. Comprobar extensiones fijas
  for forbidden in "${FORBIDDEN_EXTS[@]}"; do
    if [[ "$ext" == "$forbidden" ]] || [[ "$filename" == ".env" ]]; then
      echo "CRITICAL: Archivo prohibido detectado (extensión '.$forbidden'): $rel_path"
      SENSITIVE_FOUND=1
    fi
  done

  # 2. Comprobar patrones de nombres (case-insensitive)
  lower_filename=$(echo "$filename" | tr '[:upper:]' '[:lower:]')

  # Patrón de backups
  if [[ "$lower_filename" == *backup* ]]; then
    echo "CRITICAL: Archivo de copia de seguridad detectado: $rel_path"
    SENSITIVE_FOUND=1
  fi

  # Patrón de archivos .log
  if [[ "$lower_filename" == *.log ]]; then
    echo "CRITICAL: Archivo de log detectado: $rel_path"
    SENSITIVE_FOUND=1
  fi

done < <(find "$ROOT_DIR" -type f \
  -not -path "*/.git/*" \
  -not -path "*/.derived-data.nosync/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/node-v20.11.1-darwin-arm64/*" \
  -not -path "*/build/*")

if [[ $SENSITIVE_FOUND -eq 1 ]]; then
  echo "ERROR: Escaneo fallido. Se encontraron archivos sensibles no autorizados."
  exit 1
else
  echo "OK: Escaneo completado. No se encontraron archivos sensibles."
  exit 0
fi
