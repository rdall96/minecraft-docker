# Minecraft Server Downloader
# forge_downloader.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import re

from utilities.exceptions import ForgeVersionNotFoundError

from .downloader import Downloader

# URLs
LIST_FORGE_VERSIONS_URL_FORMAT = "https://files.minecraftforge.net/net/minecraftforge/forge/index_{}.html"
FORGE_DOWNLOAD_LINK_TEMPLATE_STRING = "https://maven.minecraftforge.net/net/minecraftforge/forge/{minecraft}-{forge}/forge-{minecraft}-{forge}-installer.jar"

# Regex
FIND_DOWNLOAD_LINK_REGEX_STRING = "https://maven\.minecraftforge\.net/net/minecraftforge/forge/{}-(\S*)/\S*\.jar"
FIND_RECOMMENDED_FORGE_VERSION_REGEX_STRING = re.compile(r'<td\s*class=\"download-version\">\n\s*(\S*)\n\s*<i\s*class=\"promo-recommended\s*fa\"></i>\n\s*</td>')


class ForgeDownloader(Downloader):
    """ Download Minecraft Forge jar """

    _type: str = "forge"

    def __init__(self, **extra_configs: dict):
        super().__init__(**extra_configs)

    def get_forge_versions(self, minecraft_version: str) -> dict:
        """ Returns a dictionary of forge versions with metadata associated with them """
        data = {"versions": []}
        # Since Forge doesn't provide a public API, we need to resort to scraping their web page
        web_page_url = LIST_FORGE_VERSIONS_URL_FORMAT.format(minecraft_version)
        html = Downloader._make_request(web_page_url)
        if not html:
            self._logger.error("No html data found in page!")
            return data
        
        # Run a regex through the page to grab all the available Forge versions
        regex_string = FIND_DOWNLOAD_LINK_REGEX_STRING.format(minecraft_version.replace(".", "\."))
        version_data = re.findall(regex_string, html)

        # There are multiple links throughout the page, so remove all the duplicates here
        version_data.sort() # from oldest to newest
        forge_versions = []
        for x in version_data:
            if x not in forge_versions:
                forge_versions.append(x)

        # Now do another search to find the recommended version of forge (if any)
        recommended_data = FIND_RECOMMENDED_FORGE_VERSION_REGEX_STRING.findall(html)
        
        data["versions"] = forge_versions
        data["latest"] = forge_versions[-1]
        
        return data

    @staticmethod
    def _assemble_download_url(minecraft_version: str, forge_version: str) -> str:
        """ Build a url to download forge for a given Minecraft version """
        return FORGE_DOWNLOAD_LINK_TEMPLATE_STRING.format(
            minecraft=minecraft_version,
            forge=forge_version
        )
    
    def _get_file_name(self, version: str) -> str:
        """ Returns the file name for this version (specific to the downloader type) """
        return f"forge-{version}-installer.jar"
    
    def _game_versions(self) -> dict:
        """ Dictionary of released game versions and url downloads """
        raise NotImplementedError()

    def get_download_url(self, version: str) -> str:
        """ Returns the URL where to download the specified server version """
        """
        Fetch the Forge download URL for the given Minecraft version.
        This will try to use the recommended version of Forge and fallback to the latest version otherwise.
        """
        versions = self.get_forge_versions(minecraft_version=version)
        forge_version = versions.get("latest")
        if not forge_version:
            self._logger.error(f"No forge version found for Minecraft {version}, does it exist?")
            raise ForgeVersionNotFoundError
        return ForgeDownloader._assemble_download_url(version, forge_version)
