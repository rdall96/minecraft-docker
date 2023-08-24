# ================================
# Build image
# ================================
FROM swift:5.8-jammy as build

ARG BUILD_TYPE="release"

# Install OS updates and, if needed, sqlite3
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
  && apt-get update \
  && apt-get dist-upgrade -y

# Set up a build area
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

# Build everything, with optimizations
RUN swift build \
  -c ${BUILD_TYPE} \
  --static-swift-stdlib

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp \
  "$(swift build \
    --package-path /build \
    -c ${BUILD_TYPE} \
    --show-bin-path)/MinecraftDocker" ./minecraft-docker-cli

# ================================
# Run image
# ================================
FROM ubuntu:jammy

ARG CLI_VERSION="(unknown)"

ENV APP_HOME="/app"

# Make sure all system packages are up to date, and install only essential packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
  && apt-get update \
  && apt-get dist-upgrade -y \
  && apt-get install -y \
    ca-certificates \
    tzdata \
    curl \
    gnupg \
  # install docker
  && install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && chmod a+r /etc/apt/keyrings/docker.gpg \
  && echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && apt-get update \
  && apt-get install -y docker-ce \
  # remove apt lists to prevent further updates
  && rm -r /var/lib/apt/lists/*

# Switch to the home directory
WORKDIR ${APP_HOME}

# Copy built executable
COPY --from=build /staging ${APP_HOME}
# Create the version file
RUN echo "$CLI_VERSION" > ${APP_HOME}/version

# Volume to download data to
VOLUME [ "/data" ]
# Entrypoint command so argument and options can easily be passed to the container
ENTRYPOINT ["./minecraft-docker-cli"]
