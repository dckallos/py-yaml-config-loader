# yaml-config-loader

A comment-preserving YAML configuration reader for Python applications.

## Disclaimer

This code currently amounts to chicken scratch. I have not released the python package, and my work is in development.

## Features

- Read YAML configuration files with simple dotted-path access
- Preserves comments and formatting for future in-place editing (coming soon)
- Lightweight with minimal dependencies
- Type-safe error handling
- Support for nested configuration values

## Installation

```bash
pip install yaml-config-loader
```

## Quick Start

```python
from yaml_config_loader import ConfigLoader

# Initialize with your YAML file
ConfigLoader.initialize("config.yaml")

# Access values using dotted paths
log_level = ConfigLoader.get("data.LOG_LEVEL")
app_mode = ConfigLoader.get("data.APP_MODE", default="development")

# Get all top-level keys
keys = ConfigLoader.keys()

# Reload configuration from disk
ConfigLoader.reload()
```

## Example YAML

```yaml
data:
  APP_MODE: production
  LOG_LEVEL: INFO
  DATABASE:
    HOST: localhost
    PORT: 5432
```

## Error Handling

```python
from yaml_config_loader import ConfigLoader, ConfigNotFound, ConfigParseError

try:
    ConfigLoader.initialize("config.yaml")
except ConfigNotFound:
    print("Configuration file not found")
except ConfigParseError as e:
    print(f"Failed to parse YAML: {e}")
```

## Requirements

- Python >= 3.10
- PyYAML >= 6.0.1

## License

MIT License - see LICENSE file for details.

## Author

Daniel C. Kalleward
