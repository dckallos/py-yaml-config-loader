"""yaml_config_loader package.

Public API (Prompt 1):
- ConfigCore: core read-only loader and accessor
- ConfigNotFound, ConfigParseError: exceptions
"""

from .config_core import ConfigCore
from .errors import ConfigNotFound, ConfigParseError

try:
    # Prefer dynamic version from installed metadata
    from importlib.metadata import version, PackageNotFoundError  # Python 3.8+

    try:
        __version__ = version("yaml-config-loader")
    except PackageNotFoundError:
        # Fallback for editable installs or when metadata is unavailable
        __version__ = "0.1.0"
except Exception:
    # Very defensive: never fail import just because of version resolution
    __version__ = "0.1.0"

__all__ = [
    "ConfigCore",
    "ConfigNotFound",
    "ConfigParseError",
]
