from __future__ import annotations

from pathlib import Path

import pytest

from yaml_config_loader import ConfigCore, ConfigNotFound


FIXTURE_PATH = Path(__file__).resolve().parents[1] / "fixtures" / "cm-basic.yaml"


def test_get_basic_values():
    ConfigCore.initialize(str(FIXTURE_PATH))
    assert ConfigCore.get("data.APP_MODE") == "production"
    assert ConfigCore.get("data.LOG_LEVEL") == "INFO"


def test_missing_key_returns_default():
    ConfigCore.initialize(str(FIXTURE_PATH))
    assert ConfigCore.get("data.MISSING", default="default-value") == "default-value"


def test_nonexistent_file_raises():
    bogus = Path(__file__).resolve().parents[1] / "fixtures" / "does-not-exist.yaml"
    with pytest.raises(ConfigNotFound):
        ConfigCore.initialize(str(bogus))
