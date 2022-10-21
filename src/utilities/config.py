# Minecraft Docker Compiler
# config.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import os

import yaml

class Config:

    def __init__(self, config_path: str):
        self._data = {}
        
        # Load the config path
        if not os.path.isfile(config_path):
            raise FileNotFoundError(f"No config file found at {config_path}")
        with open(config_path, mode="r") as f:
            self._data = yaml.safe_load(f)
    
    @property
    def log_level(self) -> str:
        return self._data["logging"]["level"]

    def set_log_level(self, level: str):
        self._data["logging"]["level"] = level

    @property
    def logger_config_dict(self) -> dict:
        return {"logging": self._data["logging"]}

    @property
    def docker_build_directory(self) -> str:
        return self._data["build_directory"]

    @property
    def docker_image_name(self) -> str:
        return self._data.get("docker_image_name", "minecraft")
    
    @property
    def latest_java_version(self) -> int:
        return self._data["latest_java_version"]
    
    @property
    def _supported_java_versions(self) -> dict:
        return self._data["supported_java_versions"]
    
    def java_package_name(self, version: int) -> str:
        return self._supported_java_versions.get(version, self.latest_java_version)["package_name"]
    
    def _minecraft_version_data(self, version: str = None) -> dict:
        if version:
            return self._data.get("minecraft_versions", {}).get(float(version), {})
        else:
            return self._data.get("minecraft_versions", {})

    def java_version(self, minecraft_version: str) -> int:
        # Remove the patch number from the Minecraft versions
        version_numbers = minecraft_version.split(".")
        if len(version_numbers) > 2:
            minecraft_version = ".".join(version_numbers[:-1])
        return self._minecraft_version_data(version=minecraft_version).get("java")
