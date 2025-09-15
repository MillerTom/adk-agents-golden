#!/usr/bin/env bash
set -euo pipefail

# Resolve project root relative to this script so it works after renames
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACES_ROOT="/workspaces"
echo "[post-create] Project root: $PROJECT_ROOT"

# 1) Clone official ADK repos side-by-side (read-only) under /workspaces
cd "$WORKSPACES_ROOT"

clone_if_missing() {
  local repo_name="$1"
  local repo_url="$2"
  if [ ! -d "$repo_name" ]; then
    echo "[post-create] Cloning $repo_name ..."
    git clone --depth=1 "$repo_url" "$repo_name"
  else
    echo "[post-create] $repo_name already exists, skipping clone"
  fi
}

clone_if_missing "adk-python" "https://github.com/google/adk-python.git"
if [ ! -d "adk-samples" ]; then
  echo "[post-create] Cloning adk-samples (sparse python) ..."
  git clone --filter=blob:none --depth=1 https://github.com/google/adk-samples.git
  pushd adk-samples >/dev/null
  if git sparse-checkout init --cone 2>/dev/null; then
    git sparse-checkout set python || true
  else
    echo "[post-create] sparse-checkout not supported; keeping full repo"
  fi
  popd >/dev/null
else
  echo "[post-create] adk-samples already exists, skipping clone"
fi
clone_if_missing "adk-docs" "https://github.com/google/adk-docs.git"
clone_if_missing "adk-python-community" "https://github.com/google/adk-python-community.git"

# Set permissive permissions (read/execute for all) on cloned directories
for d in adk-python adk-samples adk-docs adk-python-community; do
  if [ -d "$d" ]; then
    chmod -R a+rX "$d" || true
  fi
done

# 2) Create a venv for THIS project (not for the cloned repos)
cd "$PROJECT_ROOT"
if [ ! -d .venv ]; then
  echo "[post-create] Creating venv at $PROJECT_ROOT/.venv"
  python3 -m venv .venv
else
  echo "[post-create] Reusing existing venv at $PROJECT_ROOT/.venv"
fi
source .venv/bin/activate

# 3) Install ADK + optional community pkg (pin to current versions if desired)
pip install --upgrade pip
pip install "google-adk" "google-adk-community"

# 4) Post-install check: verify ADK import and CLI
python - << 'PY' || true
try:
  import google.adk as adk
  print('[post-create] google.adk import OK', getattr(adk, '__version__', ''))

#!/usr/bin/env bash
set -euo pipefail

# Enable debug tracing if DEBUG=1
[[ "${DEBUG:-0}" == "1" ]] && set -x

# Trap errors for diagnostics
trap 'echo "[post-create] Error on line $LINENO"; exit 1' ERR

# Log to file and stdout
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/post-create.log"
WORKSPACES_ROOT="/workspaces"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[post-create] Starting at $(date)"
echo "[post-create] Running as user: $(whoami)"
echo "[post-create] Working directory: $(pwd)"
echo "[post-create] Project root: $PROJECT_ROOT"
echo "[post-create] Python: $(which python3) $(python3 --version 2>&1)"
echo "[post-create] Pip: $(which pip) $(pip --version 2>&1)"

# 1) Clone official ADK repos side-by-side (read-only) under /workspaces
cd "$WORKSPACES_ROOT"
echo "[post-create] Cloning/checking ADK repos in $WORKSPACES_ROOT"

clone_if_missing() {
  local repo_name="$1"
  local repo_url="$2"
  if [ ! -d "$repo_name" ]; then
    echo "[post-create] Cloning $repo_name ..."
    git clone --depth=1 "$repo_url" "$repo_name"
  else
    echo "[post-create] $repo_name already exists, skipping clone"
  fi
}

clone_if_missing "adk-python" "https://github.com/google/adk-python.git"
if [ ! -d "adk-samples" ]; then
  echo "[post-create] Cloning adk-samples (sparse python) ..."
  git clone --filter=blob:none --depth=1 https://github.com/google/adk-samples.git
  pushd adk-samples >/dev/null
  if git sparse-checkout init --cone 2>/dev/null; then
    git sparse-checkout set python || true
  else
    echo "[post-create] sparse-checkout not supported; keeping full repo"
  fi
  popd >/dev/null
else
  echo "[post-create] adk-samples already exists, skipping clone"
fi
clone_if_missing "adk-docs" "https://github.com/google/adk-docs.git"
clone_if_missing "adk-python-community" "https://github.com/google/adk-python-community.git"

# Set permissive permissions (read/execute for all) on cloned directories
for d in adk-python adk-samples adk-docs adk-python-community; do
  if [ -d "$d" ]; then
    chmod -R a+rX "$d" || true
    echo "[post-create] Set permissions on $d"
  fi
done

# 2) Create a venv for THIS project (not for the cloned repos)
cd "$PROJECT_ROOT"
if [ ! -d .venv ]; then
  echo "[post-create] Creating venv at $PROJECT_ROOT/.venv"
  python3 -m venv .venv
else
  echo "[post-create] Reusing existing venv at $PROJECT_ROOT/.venv"
fi
source .venv/bin/activate
echo "[post-create] Activated venv: $(which python)"

# 3) Install ADK + optional community pkg (pin to current versions if desired)
echo "[post-create] Upgrading pip..."
pip install --upgrade pip || { echo '[post-create] pip upgrade failed'; exit 1; }
echo "[post-create] Installing google-adk and google-adk-community..."
pip install "google-adk" "google-adk-community" || { echo '[post-create] pip install failed'; exit 1; }

# 4) Post-install check: verify ADK import and CLI
echo "[post-create] Verifying google.adk Python import..."
python - << 'PY' || true
try:
    import google.adk as adk
    print('[post-create] google.adk import OK', getattr(adk, '__version__', ''))
except Exception as e:
    print('[post-create] WARNING: google.adk import failed:', type(e).__name__, e)
PY
echo "[post-create] Verifying adk CLI..."
adk --version || echo '[post-create] WARNING: adk CLI not on PATH in venv'

# 5) (Optional) Enable the ADK CLI autocompletion here if you use it later
# adk --help  # sanity check if CLI is present in PATH

echo "[post-create] Finished at $(date)"
echo "[post-create] Log saved to $LOG_FILE"
