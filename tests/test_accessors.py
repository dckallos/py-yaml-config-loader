from __future__ import annotations
from pathlib import Path
from yaml_config_loader import ConfigCore


FIXTURE_PATH = Path(__file__).resolve().parents[1] / "fixtures" / "cm-types.yaml"


def setup_module():
    ConfigCore.initialize(str(FIXTURE_PATH))


def test_get_int_ok_and_negative():
    assert ConfigCore.get_int("data.MAX_RETRIES") == 5
    assert ConfigCore.get_int("data.RETRIES_NEGATIVE") == -2


def test_get_int_missing_and_unparseable():
    assert ConfigCore.get_int("data.MISSING", default=7) == 7
    assert ConfigCore.get_int("data.ENABLE_FEATURE", default=None) is None


def test_get_bool_true_false_and_default():
    assert ConfigCore.get_bool("data.ENABLE_FEATURE") is True
    assert ConfigCore.get_bool("data.DISABLE_CACHE") is False
    assert ConfigCore.get_bool("data.MAYBE_FLAG", default=False) is False


def test_has_presence():
    assert ConfigCore.has("data.MAX_RETRIES") is True
    assert ConfigCore.has("data.DOES_NOT_EXIST") is False
    assert ConfigCore.has("data.PEOPLE_ARE_HONEST") is False


def test_suggest_close_matches():
    suggestions = ConfigCore.suggest("data.ENABLE_FEATUR")
    assert "data.ENABLE_FEATURE" in suggestions
