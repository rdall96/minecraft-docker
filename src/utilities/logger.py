# Minecraft Server Downloader
# minecraft_server_downloader/logger.py
# Copyright (c) 2022 Ricky Dall'Armellina (rdall96@gmail.com). All Rights Reserved.

import logging
import sys

class Logger:
    """ Custom logging class """

    _logger = None
    _FORMAT = "%(asctime)s [%(levelname)s] %(name)s - %(message)s"
    _DATETIME_FMT = "%Y-%m-%d %H:%M:%S"

    def __init__(self, name, level="info"):
        """ Creates a new custom logger with the given name
            The name will be printed with the log messages
            The log directory will be used to store log file

            Example: 2020-01-25 15:40:32 [INFO] Awesome_Server - Started the server
        """
        # Create a new logger with the given name
        self._logger = logging.Logger(name)
        self._logger.setLevel(
            level.upper() if isinstance(level, str) else level)
        # Setup the format for the logs
        formatter = logging.Formatter(self._FORMAT, self._DATETIME_FMT)
        # Logging handler for console output
        s_handler = logging.StreamHandler(sys.stdout)
        s_handler.setFormatter(formatter)
        self._logger.addHandler(s_handler)

    def __del__(self):
        """ Before deconstructing the object, close any opened handler """
        for handler in self._logger.handlers[:]:
            handler.close()
            self._logger.removeHandler(handler)

    @property
    def level(self):
        """ Returns the currently set log level """
        return self._logger.level

    def info(self, msg):
        """ Log an info message """
        self._logger.info(msg)

    def debug(self, msg):
        """ Log a debug message """
        self._logger.debug(msg)

    def warning(self, msg):
        """ Log a warning message """
        self._logger.warning(msg)

    def error(self, msg):
        """ Log an error message """
