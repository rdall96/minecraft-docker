# Minecraft Docker Compiler
# downloader_factory.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

from inspect import ClassFoundException
from utilities import InstallType

from .downloader import Downloader
from .vanilla_downloader import VanillaDownloader
from .forge_downloader import ForgeDownloader

class DownloaderFactory:
    
    def create_downloader(self, type: InstallType, **extra_configs: dict) -> Downloader:
        """ Assemble a server downloader of the desired type """
        class_name = f"{type.value.title()}Downloader"
        try:
            downloader = eval(class_name)(**extra_configs)
        except:
            raise ClassFoundException(f"No downloader of type {type} with class name {class_name} found!")
        return downloader
