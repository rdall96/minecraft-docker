# Minecraft Docker Compiler
# downloader_factory.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

from inspect import ClassFoundException
from utilities import MinecraftVersionType

from .downloader import Downloader
from .vanilla_downloader import VanillaDownloader
from .forge_downloader import ForgeDownloader

class DownloaderFactory:
    
    def create_downloader(self, downloader_type: MinecraftVersionType, **extra_configs: dict) -> Downloader:
        """ Assemble a server downloader of the desired type """
        class_name = f"{downloader_type.value.title()}Downloader"
        try:
            downloader = eval(class_name)(**extra_configs)
        except:
            raise ClassFoundException(f"No downloader of type {downloader_type} with class name {class_name} found!")
        return downloader
