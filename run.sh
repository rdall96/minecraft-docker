#!/bin/bash

set -o errexit

WORK_DIR=$(dirname $0)

IMAGE_NAME="rdall96/minecraft-server"

# Check docker version
docker --version

# Check python version
python3 -V

# Create Python environment
echo -e "\nSetting up build environment..."
PYTHON_VENV="$WORK_DIR/venv"
if [[ ! -d "$PYTHON_VENV" ]]; then
    python3 -m venv "$PYTHON_VENV"
fi
source "$PYTHON_VENV/bin/activate"

# Update packages and install dependencies
pip install --upgrade pip
pip install -r "$WORK_DIR/requirements.txt"

# Check if the image has already been created
echo -e "\nChecking the latest Minecraft version..."
python "$WORK_DIR/src/check_version.py"
LATEST_VER=$(cat "$WORK_DIR/minecraft/latest.txt")
set +o errexit
docker manifest inspect "$IMAGE_NAME:$LATEST_VER" > /dev/null
FOUND="$(echo $?)"
set -o errexit

if [[ $FOUND == 0 ]]; then
    # The image exists abort
    echo -e "\nFound image for latest Minecraft version in DockerHub '$IMAGE_NAME:$LATEST_VER', no need to rebuild"
    exit 0
else
    # Run the minecraft download script
    echo -e "\nDownloading Minecraft..."
    python "$WORK_DIR/src/main.py"
    MINECRAFT_VER=$(cat "$WORK_DIR/minecraft/server/version.txt")

    # Build the docker image
    echo -e "\nBuilding image..."
    docker build "$WORK_DIR/minecraft" -t "$IMAGE_NAME:$MINECRAFT_VER"
    echo -e "\nTagged Minecraft docker image '$IMAGE_NAME:$MINECRAFT_VER' (latest)"
    docker tag "$IMAGE_NAME:$MINECRAFT_VER" "$IMAGE_NAME:latest"

    # Push to DockerHub
    echo -e "\nPushing to DockerHub..."
    docker push "$IMAGE_NAME:$MINECRAFT_VER"
    docker push "$IMAGE_NAME:latest"
fi

# Cleanup
deactivate
rm -rf "$PYTHON_VENV"
docker rmi "$IMAGE_NAME:$MINECRAFT_VER" "$IMAGE_NAME:latest"
