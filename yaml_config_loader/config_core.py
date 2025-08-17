"""Core read-only loader for YAML configuration (Prompt 1).

This module provides a minimal, classmethod-only API to initialize a YAML
configuration from a file path, read it into an in-memory cache, and query
values using simple dotted paths (e.g., "data.LOG_LEVEL").

Future prompts will extend this with multi-document support and in-place edits.
"""

from __future__ import annotations

from typing import Any, Dict, List

import os

import yaml

from .errors import ConfigNotFound, ConfigParseError
from .path_utils import split_dotted_path, get_nested


class ConfigCore:
    """
    Static-style interface for loading and querying a YAML config file.
    """

    _path: str | None = None
    _cache: Dict[str, Any] | None = None

    @classmethod
    def initialize(cls, path: str) -> None:
        """
        Set the config file path and load it into cache.

        Parameters
        ----------
        path: str
            Path to the YAML file to load.
        """

        cls._path = path
        cls._load()

    @classmethod
    def _load(cls) -> None:
        """
        Internal: load YAML from ``_path`` into ``_cache``.

        Raises
        ------
        ConfigNotFound
            If the configured path does not exist.
        ConfigParseError
            If the YAML cannot be parsed or the root document is not a mapping.
        """

        if cls._path is None:
            # Nothing to load yet. Treat as empty.
            cls._cache = None
            return

        path = cls._path
        if not os.path.exists(path):
            raise ConfigNotFound(path)

        try:
            with open(path, "r", encoding="utf-8") as f:
                data = yaml.safe_load(f)
        except yaml.YAMLError as exc:  # type: ignore[attr-defined]
            # Try to extract mark info if available
            line = getattr(getattr(exc, "problem_mark", None), "line", None)
            column = getattr(getattr(exc, "problem_mark", None), "column", None)
            raise ConfigParseError(
                path,
                str(exc),
                line=None if line is None else line + 1,
                column=None if column is None else column + 1,
            )
        except Exception as exc:  # noqa: BLE001 - surface as parse error for consistency
            raise ConfigParseError(path, str(exc))

        if data is None:
            # Empty file: treat as empty mapping for convenience
            cls._cache = {}
            return

        if not isinstance(data, dict):
            raise ConfigParseError(path, "Root document must be a mapping (YAML dict)")

        cls._cache = data

    @classmethod
    def reload(cls) -> None:
        """
        Reload the current config from disk into cache.
        """

        cls._load()

    @classmethod
    def _ensure_loaded(cls) -> None:
        if cls._cache is None:
            cls._load()

    @classmethod
    def get(cls, path: str, default: Any | None = None) -> Any | None:
        """
        Get a value from the cached config using a dotted path.

        Examples
        --------
        >>> ConfigCore.get("data.LOG_LEVEL")
        'INFO'
        """

        cls._ensure_loaded()
        if cls._cache is None:
            return default

        if not path:
            return cls._cache

        segments = split_dotted_path(path)
        return get_nested(cls._cache, segments, default)

    @classmethod
    def keys(cls) -> List[str]:
        """
        Return top-level keys of the cached config as a list.

        If config is not loaded yet, returns an empty list.
        """

        cls._ensure_loaded()
        if not isinstance(cls._cache, dict):
            return []
        return list(cls._cache.keys())


__all__ = ["ConfigCore"]
