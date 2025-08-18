from __future__ import annotations
from pathlib import Path
from yaml_config_loader import ConfigLoader


FIXTURE_PATH = Path(__file__).resolve().parents[1] / "fixtures" / "cm-types.yaml"


def setup_module():
    ConfigLoader.initialize(str(FIXTURE_PATH))


def test_get_int_ok_and_negative():
    assert ConfigLoader.get_int("data.MAX_RETRIES") == 5
    assert ConfigLoader.get_int("data.RETRIES_NEGATIVE") == -2


def test_get_int_missing_and_unparseable():
    assert ConfigLoader.get_int("data.MISSING", default=7) == 7
    assert ConfigLoader.get_int("data.ENABLE_FEATURE", default=None) is None


def test_get_bool_true_false_and_default():
    assert ConfigLoader.get_bool("data.ENABLE_FEATURE") is True
    assert ConfigLoader.get_bool("data.DISABLE_CACHE") is False
    assert ConfigLoader.get_bool("data.MAYBE_FLAG", default=False) is False


def test_has_presence():
    assert ConfigLoader.has("data.MAX_RETRIES") is True
    assert ConfigLoader.has("data.DOES_NOT_EXIST") is False
    assert ConfigLoader.has("data.PEOPLE_ARE_HONEST") is False


def test_suggest_close_matches():
    suggestions = ConfigLoader.suggest("data.ENABLE_FEATUR")
    assert "data.ENABLE_FEATURE" in suggestions
