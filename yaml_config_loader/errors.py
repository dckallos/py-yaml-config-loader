"""Custom exceptions for the YAML Config Loader."""

from __future__ import annotations


__all__ = [
    "ConfigNotFound",
    "ConfigParseError",
]


class ConfigNotFound(FileNotFoundError):
    """Raised when the configured YAML file path does not exist."""

    def __init__(self, path: str):
        self.path = path
        super().__init__(f"Config file not found: {path}")


class ConfigParseError(Exception):
    """Raised when the YAML file cannot be parsed."""

    def __init__(
        self,
        path: str,
        message: str,
        *,
        line: int | None = None,
        column: int | None = None,
    ):
        self.path = path
        self.line = line
        self.column = column
        location = (
            f" (line {line}, column {column})"
            if line is not None and column is not None
            else ""
        )
        super().__init__(f"Failed to parse YAML at {path}{location}: {message}")
