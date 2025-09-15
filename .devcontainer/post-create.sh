#!/usr/bin/env bash
set -euo pipefail

# 1) Clone official ADK repos side-by-side (read-only)
cd /workspaces
if [ ! -d "adk-python" ]; then
  git clone --depth=1 https://github.com/google/adk-python.git
fi
if [ ! -d "adk-samples" ]; then
  # Sparse clone only the Python samples to save space
  git clone --filter=blob:none --depth=1 https://github.com/google/adk-samples.git
  cd adk-samples
  git sparse-checkout init --cone
  git sparse-checkout set python
  cd ..
fi
if [ ! -d "adk-docs" ]; then
  git clone --depth=1 https://github.com/google/adk-docs.git
fi
if [ ! -d "adk-python-community" ]; then
  git clone --depth=1 https://github.com/google/adk-python-community.git
fi

# 2) Create a venv for YOUR project (not for the cloned repos)
cd $GITHUB_WORKSPACE
python -m venv .venv
source .venv/bin/activate

# 3) Install ADK + optional community pkg (pin to current versions)
pip install --upgrade pip
pip install "google-adk" "google-adk-community"

# 4) (Optional) Enable the ADK CLI autocompletion here if you use it later
# adk --help  # sanity check if CLI is present in PATH
