# Minecraft Docker Compiler
# types.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

from enum import Enum

class MinecraftVersionType(Enum):
    vanilla = "vanilla"
    forge = "forge"
    fabric = "fabric"
    bedrock = "bedrock"
