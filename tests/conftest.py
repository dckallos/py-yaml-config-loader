import os
import sys


# Ensure project root is on sys.path when running tests from within the
# tests/ directory (e.g., `cd tests && pytest`). This allows importing the
# local package without requiring an editable install.
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)
