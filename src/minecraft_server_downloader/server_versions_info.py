# Minecraft Server Downloader
# minecraft_server_downloader/server_versions_info.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

from .java_server_downloader import Java_ServerDownloader

class ServerVersionsInfo:

    @staticmethod
    def get_minecraft_versions_list(**kwargs) -> list:
        """ Returns a list of available and supported server versions for the given game version (java, bedrock, etc...) """
        # Create a downloader and get the list of versions
        downloader = Java_ServerDownloader(**kwargs)
        return downloader.get_available_game_versions()
