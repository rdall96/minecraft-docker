# Minecraft Docker Compiler
# This docker build generates a docker image to run a minecraft server
# Version: BEDROCK
#
# Author: Ricky Dall'Armellina (rdall96@gmail.com)
#

FROM ubuntu:latest

ARG MINECRAFT_SERVER_URL

# Install the runtime dependencies
RUN echo "deb http://security.ubuntu.com/ubuntu focal-security main" | tee /etc/apt/sources.list.d/focal-security.list
RUN apt update
RUN apt install -y libssl1.1 libcurl4 unzip

# Copy the server runtime and unzip it
ADD "${MINECRAFT_SERVER_URL}" server.zip
RUN unzip server.zip -d /minecraft
RUN rm -rf server.zip
WORKDIR /minecraft

# Copy the startup scripts
COPY start_server.sh .

# Set the entry point for the container
ENTRYPOINT [ "/minecraft/start_server.sh" ]
# Set the 'world' folder as a volume to persist data
VOLUME [ "/minecraft/world" ]
