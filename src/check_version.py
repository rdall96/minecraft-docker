# Minecraft Docker Compiler
# check_version.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import os
from minecraft_server_downloader import ServerVersionsInfo

cwd = os.path.dirname(
    os.path.dirname(
        os.path.abspath(__file__)
))
global_config = {
    "logging": {
        "level": os.environ.get("LOG_LEVEL", "INFO")
    }
}

# Get the latest version of Minecraft available
versions = ServerVersionsInfo.get_minecraft_versions_list(**global_config)
if len(versions) == 0:
    # No versions found, abort
    exit(1)
latest = versions[0]

# Write the latest version to a local file
latest_file_path = os.path.join(
    cwd, "minecraft", "latest.txt"
)
with open(latest_file_path, mode="w") as f:
    f.write(latest)
