#!/bin/bash

set -o errexit

# Set globals and defaults
WORK_DIR=$(dirname $0)

# Check tools version
docker --version
python3 -V

# Create Python environment
echo -e "\nSetting up build environment..."
PYTHON_VENV="$WORK_DIR/venv"
rm -rf "$PYTHON_VENV"
python3 -m venv "$PYTHON_VENV" > /dev/null
source "$PYTHON_VENV/bin/activate"

# Update packages and install dependencies
pip install --upgrade pip > /dev/null
pip install -r "$WORK_DIR/requirements.txt" > /dev/null

# Run the build script
python "$WORK_DIR/src/main.py" "$@"

# Cleanup
deactivate
rm -rf "$PYTHON_VENV"
