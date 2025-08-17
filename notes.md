# Notes for Cursor/Codex While Generating

1. **Always use `yaml` only**

   * Import as `import yaml`.
   * Use `yaml.safe_load`/`yaml.safe_load_all` for read-time parsing into dicts.
   * Use `yaml.compose` (or `compose_all`) to access the low-level node tree with `start_mark` and `end_mark` for in-place edits.
   * Do **not** use `ruamel.yaml` or PyYAML’s round-trip dumper.

2. **Classmethod style**

   * Public APIs (`ConfigCore`, `YamlStream`, etc.) should be `@classmethod`s.
   * Keep global `_path`, `_cache`, `_lkg`.
   * Instantiation should be avoided unless absolutely required for modular helpers.

3. **In-place editing only**

   * `set_value_in_place` (and sequence edits) must:

     * Parse the YAML into nodes with `yaml.compose`.
     * Traverse mapping keys (via `ScalarNode`) and sequence indices.
     * Locate the scalar node’s **span in the original file text**.
     * Replace only that span in the text and write it back.
   * Never re-serialize the entire file.
   * Never lose comments, anchors, whitespace, or formatting.

4. **Scope of setter functionality**

   * Allowed:

     * Scalar values (`"INFO"`, `42`, `true`, `null`) in mappings.
     * Scalar list elements (e.g. `- "alpha"`) addressed with `[index]`.
   * Rejected (raise clear error):

     * Block scalars (`|`, `>`).
     * Alias/anchor values.
     * Merge keys (`<<`).
     * Complex keys (sequences/maps as keys).
     * Non-scalar list items (dicts, nested lists).

5. **Quoting & style preservation**

   * Do not add/remove quotes.
   * Replace the value **inside existing quotes** if quoted.
   * For plain scalars: only replace if the new value can be expressed safely without quotes.
   * Reject multiline new values for plain style.

6. **Multi-document support**

   * Use `doc_index` to target a document in a YAML stream.
   * If no index is provided, default to the first document.
   * In-place edits must modify only the specified doc’s span, leaving others intact.

7. **ConfigMap-driven fixtures**

   * All test fixtures should look like real Kubernetes ConfigMaps.
   * Include realistic structures:

     * `data:` with scalars and lists.
     * Inline comments.
     * Block scalars (`healthcheck.sh`).
     * JSON blobs as strings.
     * Multi-doc manifests (`---` between ConfigMaps).

8. **Error handling**

   * Wrap parsing errors in `ConfigParseError`, include file path + line/column where possible.
   * For in-place edits, raise `InplaceEditError` with a clear reason (unsupported node type, missing key, etc.).

9. **Tests**

   * Write PyTest tests in separate files per feature.
   * Fixtures should live in `fixtures/` and be read as test inputs.
   * Tests must assert not only that values change, but also that comments, whitespace, and quote characters remain intact.
   * For integration tests, snapshot file text before and after, ensuring unchanged lines stay byte-for-byte the same.

10. **Live reload & CLI**

* Live reload: implement basic polling (thread or loop). Don’t over-engineer.
* CLI (`cfgctl`): all `set` operations must route through the in-place setter.

11. **Performance & safety**

* Assume files are relatively small (KB–MB scale, like typical ConfigMaps).
* Do not optimize prematurely; focus on correctness and comment preservation.
* Warn in comments if a chosen approach won’t scale to extremely large YAMLs.

12. **When unsure, prefer strictness**

* If a requested edit might break YAML syntax, raise an error instead of guessing.
* Document clearly in code: “unsupported for now.”

---

👉 These notes ensure Cursor/Codex always:

* Uses ConfigMap examples.
* Implements in-place editing, never whole-file rewriting.
* Preserves human readability (comments/anchors).
* Fails fast on unsupported constructs.

---

Do you want me to also produce a **“golden ConfigMap fixture pack”** (a set of ready-to-use YAML files with comments, block scalars, JSON blobs, etc.) so that every test across all prompts draws from the same pool of realistic examples?

---

## PyPI/TOML Rules (PEP 621)

- Use PEP 621 metadata in `pyproject.toml` only; do not add `setup.py`.
- `readme` must include content type:
  - `readme = { file = "README.md", content-type = "text/markdown" }`
- Do not use inline tables for URLs with spaced keys; use a dedicated table:
  ```toml
  [project.urls]
  Homepage = "https://github.com/<user>/<repo>"
  "Bug Tracker" = "https://github.com/<user>/<repo>/issues"
  ```
- Ship typing marker and license in artifacts:
  ```toml
  [tool.setuptools.package-data]
  yaml_config_loader = ["py.typed"]

  [tool.setuptools.license-files]
  paths = ["LICENSE"]
  ```
- Package discovery:
  ```toml
  [tool.setuptools.packages.find]
  where = ["."]
  include = ["yaml_config_loader*"]
  exclude = ["tests*"]
  ```

## Typing Rules

- Use modern unions: `T | None` (avoid `Optional[T]`).
- Do not add runtime branches for impossible types (e.g., `if path is None` when `path: str`).
- Export `__all__` for the public API and keep imports side-effect free.
- Exceptions should carry context: `path` and, where available, 1-based `line`/`column`.

## Tooling & Commands

- Prefer `pipx` for global CLIs (black, ruff, mypy, build, twine); otherwise use project `.venv` binaries.
- Use `scripts/dev-tools.sh` for consistency:
  - Provision: `ensure pipx|venv|both`
  - Quality: `fmt`, `lint`, `type`, `test`
  - Packaging: `build`, `check`, `upload-test`, `upload`
- Avoid auto-upgrading flaky `pip` mid-run; recreate `.venv` if needed.

## Design/Runtime Rules

- Global state: `ConfigCore` manages a single `_path` and `_cache`; not thread-safe; not multi-config.
- File I/O: UTF-8 decoding; prefer `pathlib.Path` for future modules.
- Semantics: `get("")` returns the entire root mapping; empty YAML file → `{}`.
- Keep import-time work minimal; no I/O at import-time.

## Testing Rules (extensions)

- Extend coverage to malformed YAML, non-mapping roots, nested paths, empty files, `keys()` and `reload()`.
- Fixtures should live in `fixtures/` and be read as test inputs.
- Tests must assert not only value changes, but that comments, whitespace, and quotes remain intact.
- For integration tests, snapshot file text before/after; unchanged lines must remain byte-for-byte identical.
