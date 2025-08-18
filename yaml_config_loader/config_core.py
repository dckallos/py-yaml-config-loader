"""Core read-only loader for YAML configuration (Prompt 1).

This module provides a minimal, classmethod-only API to initialize a YAML
configuration from a file path, read it into an in-memory cache, and query
values using simple dotted paths (e.g., "data.LOG_LEVEL").

Future prompts will extend this with multi-document support and in-place edits.
"""

from __future__ import annotations

from typing import Any, Dict, List

import os

import yaml  # type: ignore[import-untyped]

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
        except yaml.YAMLError as exc:
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

    @classmethod
    def has(cls, path: str) -> bool:
        """
        Return True if a value exists for the given dotted ``path``.

        Presence-only: returns True even if the value is falsy. Returns False
        for empty ``path`` or when any segment is missing.
        """

        cls._ensure_loaded()
        if not path:
            return False
        if not isinstance(cls._cache, dict):
            return False

        segments = split_dotted_path(path)
        current: object = cls._cache
        for segment in segments:
            if not isinstance(current, dict):
                return False
            if segment not in current:
                return False
            current = current[segment]
        return True

    @classmethod
    def get_int(cls, path: str, default: int | None = None) -> int | None:
        """
        Retrieve an integer value at ``path``.

        Accepts ints or decimal strings (e.g., "5", "-2"). Whitespace around
        strings is ignored. Non-decimal formats (e.g., hex) are rejected.
        Returns ``default`` if the path is missing or the value is unparseable.
        """

        cls._ensure_loaded()
        if not path:
            return default

        value = cls.get(path, default=None)
        if value is None:
            return default
        # Explicitly reject booleans (bool is a subclass of int)
        if isinstance(value, bool):
            return default
        if isinstance(value, int):
            return value
        if isinstance(value, str):
            s = value.strip()
            # Only accept optional leading minus and digits
            if s and (s[0] == "-" and s[1:].isdigit() or s.isdigit()):
                try:
                    return int(s)
                except Exception:
                    return default
            return default
        return default

    @classmethod
    def get_bool(cls, path: str, default: bool | None = None) -> bool | None:
        """
        Retrieve a boolean value at ``path``.

        Accepts booleans or case-insensitive strings from the sets:
        - True: {"true", "yes", "on", "1"}
        - False: {"false", "no", "off", "0"}

        Returns ``default`` if the path is missing or the value is unparseable.
        """

        cls._ensure_loaded()
        if not path:
            return default

        value = cls.get(path, default=None)
        if value is None:
            return default
        if isinstance(value, bool):
            return value
        if isinstance(value, str):
            s = value.strip().lower()
            if s in {"true", "yes", "on", "1"}:
                return True
            if s in {"false", "no", "off", "0"}:
                return False
            return default
        return default

    @classmethod
    def suggest(cls, path_prefix: str, *, limit: int = 5) -> List[str]:
        """
        Suggest up to ``limit`` dotted paths that closely match ``path_prefix``.

        Builds candidates by recursively walking the cached mapping.
        Returns an empty list if there are no candidates or no close matches.
        """

        import difflib

        cls._ensure_loaded()
        if not isinstance(cls._cache, dict):
            return []

        def collect_paths(prefix: str, node: object, out: List[str]) -> None:
            if isinstance(node, dict):
                for k, v in node.items():
                    if not isinstance(k, str):
                        continue
                    dotted = k if not prefix else f"{prefix}.{k}"
                    # Only include leaf values as suggestions
                    if isinstance(v, dict):
                        collect_paths(dotted, v, out)
                    else:
                        out.append(dotted)

        candidates: List[str] = []
        collect_paths("", cls._cache, candidates)
        if not candidates:
            return []

        matches = difflib.get_close_matches(
            path_prefix, candidates, n=limit, cutoff=0.65
        )
        return list(matches)


__all__ = ["ConfigCore"]
