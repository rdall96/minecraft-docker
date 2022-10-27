# Minecraft Docker Compiler
# This docker build generates a docker image to run a minecraft server
# Version: VANILLA
#
# Author: Ricky Dall'Armellina (rdall96@gmail.com)
#

# Use alpine linux as it's the lightest image to begin with
FROM alpine:latest

ARG JAVA_VER
ARG MINECRAFT_JAR_URL

# Install the runtime (java) and other dependencies
RUN apk update
RUN apk add "${JAVA_VER}" bash

# Create a directory for all of minecraft related files to reside
WORKDIR /minecraft

# Copy the server runtime and the startup scripts
ADD "${MINECRAFT_JAR_URL}" server.jar
COPY start_server.sh .

# Set the entry point for the container
ENTRYPOINT [ "/minecraft/start_server.sh" ]
# Set the 'world' folder as a volume to persist data
VOLUME [ "/minecraft/world" ]
