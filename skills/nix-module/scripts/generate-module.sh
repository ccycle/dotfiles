#!/usr/bin/env bash
set -e

MODULE_NAME="$1"

if [ -z "$MODULE_NAME" ]; then
  echo "Usage: $0 <module-name>"
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
MODULE_DIR="$REPO_ROOT/modules/$MODULE_NAME"
PARENT_DARWIN="$REPO_ROOT/modules/darwin.nix"
PARENT_HOME="$REPO_ROOT/modules/home.nix"

if [ -d "$MODULE_DIR" ]; then
  echo "Error: Module directory '$MODULE_DIR' already exists."
  exit 1
fi

echo "Creating module directory: $MODULE_DIR"
mkdir -p "$MODULE_DIR"

# Create darwin.nix
cat > "$MODULE_DIR/darwin.nix" <<EOF
{ ... }:
{
  # System-level configuration for $MODULE_NAME
}
EOF

# Create home.nix
cat > "$MODULE_DIR/home.nix" <<EOF
{ ... }:
{
  # User-level configuration for $MODULE_NAME
}
EOF

echo "Created basic structure:"
echo "  - $MODULE_DIR/darwin.nix"
echo "  - $MODULE_DIR/home.nix"

# Helper function to check if file contains import
has_import() {
  local file="$1"
  local import_path="$2"
  grep -q "$import_path" "$file"
}

echo ""
echo "!!! ACTION REQUIRED !!!"
echo "Please manually update the parent modules to include the new files."
echo ""
echo "1. Edit: modules/darwin.nix"
echo "   Add: ./$MODULE_NAME/darwin.nix"
echo ""
echo "2. Edit: modules/home.nix"
echo "   Add: ./$MODULE_NAME/home.nix"
echo ""
