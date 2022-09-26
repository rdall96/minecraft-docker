#!/bin/bash

set -o errexit

# Set globals and defaults
WORK_DIR=$(dirname $0)
MINECARFT_SERVER_DIR="$WORK_DIR/minecraft/server"
IMAGE_NAME="rdall96/minecraft-server"
JAVA_VER="17"
MINECRAFT_VER="latest"
TAG_LATEST=0

# Check args
while [[ $# -ge 1 ]]; do
    case $1 in
        -d|--dryrun)        # Dryrun (build but don't upload)
            DRYRUN=1;;
        -s|--save)          # Save the tagged image, don't delete
            SAVE=1;;
        -f|--force)         # Force upload to overwrite the remote registry
            FORCE=1;;
        --java)             # Specify the version of Java to use for this build
            JAVA_VER="$2"
            shift;;
        --minecraft)        # Specify the version of Minecraft to build
            MINECRAFT_VER="$2"
            shift;;
        *)
            echo "Usage: run.sh [OPTION]"
            echo -e "\n Options:"
            echo -e "\t-d, --dryrun\tDryrun (build the image but don't upload)"
            echo -e "\t-s, --save\tSave the tagged image (don't delete the artifacts)"
            echo -e "\t-f, --force\tForce the uplaod to overwrite the remote registry"
            echo -e "\t    --java\tSpecify the Java version to use for this build (default: $JAVA_VER)"
            echo -e "\t    --minecraft\tSpecify the version of Minecraft to build (default: $MINECRAFT_VER)"
            exit 1
    esac
    shift
done

# Check tools version
docker --version
python3 -V

# Show build settings
echo -e "\nSelected Java version: $JAVA_VER"
echo -e "Selected Minecraft version: $MINECRAFT_VER"

# Create Python environment
echo -e "\nSetting up build environment..."
PYTHON_VENV="$WORK_DIR/venv"
rm -rf "$PYTHON_VENV"
python3 -m venv "$PYTHON_VENV"
source "$PYTHON_VENV/bin/activate"

# Update packages and install dependencies
pip install --upgrade pip
pip install -r "$WORK_DIR/requirements.txt"

# Check if the image has already been created
if [[ "$MINECRAFT_VER" == "latest" ]]; then
    TAG_LATEST=1
    echo -e "\nChecking the latest Minecraft version..."
    python "$WORK_DIR/src/main.py" --latest
    MINECRAFT_VER=$(cat "$MINECARFT_SERVER_DIR/version.txt")
fi
set +o errexit
docker manifest inspect "$IMAGE_NAME:$MINECRAFT_VER" > /dev/null
FOUND="$(echo $?)"
set -o errexit
if [[ $FOUND -eq 0 && $FORCE -ne 1 ]]; then
    # The image exists, abort
    echo -e "\nFound image for selected Minecraft version in DockerHub '$IMAGE_NAME:$MINECRAFT_VER', no need to rebuild"
    exit 0
fi

# Run the minecraft download script
echo -e "\nDownloading Minecraft..."
python "$WORK_DIR/src/main.py" --minecraft "$MINECRAFT_VER"

# Build the docker image
echo -e "\nBuilding image..."
docker build "$WORK_DIR/minecraft" \
    --build-arg JAVA_VER="$JAVA_VER" \
    --build-arg MINECRAFT_VER="$MINECRAFT_VER" \
    -t "$IMAGE_NAME:$MINECRAFT_VER"
echo -e "\nTagged Minecraft docker image '$IMAGE_NAME:$MINECRAFT_VER'"
if [[ $TAG_LATEST -eq 1 ]]; then
    docker tag "$IMAGE_NAME:$MINECRAFT_VER" "$IMAGE_NAME:latest"
fi

# Push to DockerHub
if [[ $DRYRUN -ne 1 ]]; then
    echo -e "\nPushing to DockerHub..."
    docker push "$IMAGE_NAME:$MINECRAFT_VER"
    if [[ $TAG_LATEST -eq 1 ]]; then
        docker push "$IMAGE_NAME:latest"
    fi
fi

# Cleanup
deactivate
rm -rf "$PYTHON_VENV"
if [[ $SAVE -ne 1 ]]; then
    docker rmi "$IMAGE_NAME:$MINECRAFT_VER"
    if [[ $TAG_LATEST -eq 1 ]]; then
        docker rmi "$IMAGE_NAME:latest"
    fi
fi
