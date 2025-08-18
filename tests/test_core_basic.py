from __future__ import annotations
from pathlib import Path
import pytest

from yaml_config_loader import ConfigLoader, ConfigNotFound


FIXTURE_PATH = Path(__file__).resolve().parents[1] / "fixtures" / "cm-basic.yaml"


def test_get_basic_values():
    ConfigLoader.initialize(str(FIXTURE_PATH))
    assert ConfigLoader.get("data.APP_MODE") == "production"
    assert ConfigLoader.get("data.LOG_LEVEL") == "INFO"


def test_missing_key_returns_default():
    ConfigLoader.initialize(str(FIXTURE_PATH))
    assert ConfigLoader.get("data.MISSING", default="default-value") == "default-value"


def test_nonexistent_file_raises():
    bogus = Path(__file__).resolve().parents[1] / "fixtures" / "does-not-exist.yaml"
    with pytest.raises(ConfigNotFound):
        ConfigLoader.initialize(str(bogus))
