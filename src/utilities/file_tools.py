# MCManager-Core
# utils/__init__.py
# Copyright (c) 2021 SoloCup Labs. All Rights Reserved.

import os
import pathlib
import tarfile
from typing import NoReturn, Union
from zipfile import ZipFile


class MagicFileTools:
    @staticmethod
    def rm_tree(path: Union[str, os.PathLike]) -> Union[NoReturn, None]:
        """
        Given path removes all the included subfolders and files
        """
        if not isinstance(path, pathlib.Path):
            path = pathlib.Path(path)
        path_contents = list(path.iterdir())
        for item in path_contents:
            if item.is_dir():
                MagicFileTools.rm_tree(item)
            else:
                item.unlink()
        path.rmdir()

    @staticmethod
    def rm_file(path: Union[str, os.PathLike]) -> Union[NoReturn, None]:
        """
        Removes the given file path
        """
        if not isinstance(path, pathlib.Path):
            path = pathlib.Path(path)
        path.unlink()

    @staticmethod
    def copy_tree(
        source: Union[str, os.PathLike], destination: Union[str, os.PathLike]
    ) -> pathlib.Path:
        """
        Given source path and destination copies all the contents of source folder to destination
        """
        if not isinstance(source, pathlib.Path):
            source = pathlib.Path(source)
        if not isinstance(destination, pathlib.Path):
            destination = pathlib.Path(destination)
        destination.mkdir(exist_ok=True)

        def recursive_copy(path: pathlib.Path, destination: pathlib.Path):
            path_contents = list(path.iterdir())
            for item in path_contents:
                if item.is_file():
                    destination_file = destination / item.name
                    MagicFileTools.copy_file(item, destination_file)
                if item.is_dir():
                    new_destination = destination / item.name
                    new_destination.mkdir()
                    recursive_copy(item, new_destination)

        recursive_copy(source, destination)
        return destination

    @staticmethod
    def copy_file(
        source: Union[str, os.PathLike], destination: Union[str, os.PathLike]
    ) -> pathlib.Path:
        """
        Copies source file into destination path
        """
        if not isinstance(source, pathlib.Path):
            source = pathlib.Path(source)
        if not isinstance(destination, pathlib.Path):
            destination = pathlib.Path(destination)
        permission = source.stat().st_mode
        with open(source, "rb") as fp:
            file_contents = fp.read()
        with open(destination, "wb") as fp:
            fp.write(file_contents)
        destination.chmod(permission)
        return destination

    @staticmethod
    def extract_file(compressed_fp: str, output_path: str):
        """ Extract a file to the given path """
        # ZIP
        if compressed_fp.endswith(".zip"):
            with ZipFile(compressed_fp, "r") as f:
                f.extractall(output_path)
        # TARBALL
        elif compressed_fp.endswith(".tar.gz"):
            with tarfile.open(compressed_fp) as f:
                f.extractall(output_path)
        # INVALID
        else:
            raise ValueError(
                f"Unsupported compressed file extension type: {compressed_fp}")
