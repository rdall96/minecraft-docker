# Minecraft Docker Compiler
# This docker build generates a docker image to run a minecraft server
# Version: FORGE
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

# Install forge
WORKDIR /tmp
ADD "${MINECRAFT_JAR_URL}" forge_installer.jar
RUN mkdir /minecraft
RUN java -jar forge_installer.jar --installServer /minecraft
RUN rm -rf /tmp

# Create a directory for all of minecraft related files to reside
WORKDIR /minecraft
COPY start_server.sh .

EXPOSE 25565
VOLUME [ "/minecraft/world", "/minecraft/mods", "/minecraft/configurations" ]
ENTRYPOINT [ "/minecraft/start_server.sh" ]
