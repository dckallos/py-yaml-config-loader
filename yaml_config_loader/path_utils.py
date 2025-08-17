"""Utilities for working with dotted paths and nested mappings."""

from __future__ import annotations

from typing import List, Mapping, Sequence, TypeVar

T = TypeVar("T")


def split_dotted_path(path: str) -> List[str]:
    """
    Split a dotted path into its components.
    """
    return [segment for segment in path.split(".") if segment]


def get_nested(
    mapping: Mapping[str, T], path_segments: Sequence[str], default: T | None = None
) -> T | None:
    """
    Retrieve a nested value from a mapping using path segments.
    """

    current: object = mapping
    for segment in path_segments:
        if not isinstance(current, Mapping):
            return default
        if segment not in current:
            return default
        current = current[segment]
    return current  # type: ignore[return-value]
