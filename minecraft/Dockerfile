# Minecraft Docker Compiler
# This docker build generates a docker image to run a minecraft server
#
# Author: Ricky Dall'Armellina (rdall96@gmail.com)
#

# Use alpine linux as it's the lightest image to begin with
FROM alpine:latest

# Install the runtime (java)
RUN apk update
RUN apk add openjdk17-jre-headless

# Create a directory for all of minecraft related files to reside
WORKDIR /minecraft

# Copy the server runtime and the startup scripts
COPY server/server.jar ./
COPY start_server.sh .

# Set the entry point for the container
ENTRYPOINT [ "/minecraft/start_server.sh" ]
