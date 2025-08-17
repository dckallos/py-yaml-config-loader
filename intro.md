# 📖 Project Introduction: Comment-Preserving YAML Config Loader

## Overview

We are building a **generalized YAML configuration management toolkit** for Python. The goal is to support **real-world, human-maintained configuration files** where preserving comments, anchors, indentation, ordering, and formatting is as important as modifying the values.

Unlike typical YAML libraries, this loader must be able to:

* Safely **read** and query values with dotted paths.
* Perform **in-place updates** to scalars or simple list items **without re-serializing the entire file**.
* Preserve **all surrounding comments, whitespace, anchors, and Kubernetes-style formatting**.
* Support **multi-document YAML streams** as often used in Kubernetes manifests.

This is not an application-specific loader. It should work equally well on any YAML configuration, but for realism and testing, we will increasingly use **Kubernetes ConfigMaps** as the reference structure. ConfigMaps are a perfect example of complex but human-edited YAMLs: they include inline comments, multiple formats (YAML/JSON/scripts inside values), and often appear in **multi-doc manifests**.

---

## Design Goals

1. **Independence** – No business logic; just YAML manipulation.
2. **Comment Preservation** – When setting values, only the targeted scalar/list element should be updated. Comments, anchors, and formatting **must remain unchanged**.
3. **Incremental Complexity** – Start with simple key/value edits, then progress to lists, multi-doc files, and eventually complex overlays.
4. **K8s Awareness** – Use **ConfigMap examples** in tests and fixtures to model the structures this loader must reliably handle.
5. **Minimal Surface** – Expose functionality through static/class methods (`ConfigCore`) to keep APIs lean.
6. **Safety** – Fail clearly if attempting to edit unsupported constructs (block scalars, aliases, complex keys).
7. **Test-Driven** – Every new feature includes PyTest modules + YAML fixtures that resemble real K8s manifests.

---

## Technical Constraints

* Use the `yaml` module (`yaml.safe_load`, `yaml.compose`), **no `ruamel.yaml` or PyYAML-specific round-tripper**.
* Organize functionality under the typed Python package `yaml_config_loader/` (PEP 621 packaging in `pyproject.toml`).
* Use `@classmethod` style for public APIs (`ConfigCore`, `YamlStream`, etc.).
* Implement **in-place edits** via `yaml.compose` node marks (`start_mark`, `end_mark`) and string splicing — **never re-dump the whole file**.
* Support only **limited setters**: scalars and scalar list elements inside simple mappings/sequences.
* Reject complex/ambiguous cases with clear errors (block scalars, aliases, merges).
* PyTest for both **unit and integration tests**. Each step should generate **fixture YAML files** with realistic structures.

---

## Functional Roadmap

The project will be developed step by step, with each prompt covering a logical milestone. Fixtures will progressively reference **ConfigMap-style YAMLs**.

1. **Core Loader** – Read YAML, query with dotted paths (`get`).

   * Example fixture: small ConfigMap `data:` with `LOG_LEVEL: INFO`.

2. **Accessors** – Add `has()`, `get_int()`, `get_bool()`, `suggest()`.

   * Example fixture: ConfigMap with `data:` containing string numbers and booleans.

3. **Multi-Document Support** – Handle YAML streams (`---` separated docs).

   * Example fixture: a file containing two ConfigMaps.

4. **In-Place Scalar Edits** – Safely update a value while preserving comments.

   * Example fixture: ConfigMap with `LOG_LEVEL: "INFO"  # must stay here`.

5. **Sequence Element Edits** – Support editing list items (e.g., container args).

   * Example fixture: ConfigMap with a list of `ENABLED_FEATURES`.

6. **Overlays & Layered Reads** – Support merging multiple YAMLs for read queries (write only to primary file).

   * Example fixture: `base-config.yaml` + `override-config.yaml` layered like Helm values.

7. **Environment Tag `!env`** – Allow substitution of environment variables in ConfigMaps.

8. **Schema Validation** – Lightweight schema enforcement (e.g., ensure `data.LOG_LEVEL` is string).

9. **Last-Known-Good (LKG)** – Preserve working in-memory config even if the YAML file becomes corrupted.

10. **Live Reload (Polling)** – Watch a ConfigMap file for changes and reload, triggering subscribers.

11. **CLI Tool** – Provide `cfgctl` for `get`, `set`, `validate`, `layers`.

* Example usage: `cfgctl set --file cm.yaml --key data.LOG_LEVEL --value DEBUG`

12. **Integration Suite** – End-to-end tests using **complex ConfigMaps** with:

* Multiline shell scripts (`healthcheck.sh`)
* JSON blobs inside `data:`
* SQL migrations
* Comments and inline notes
* Multi-doc streams with several ConfigMaps

---

## Project Layout

- This repository is a Python package: `yaml_config_loader/`.
- Packaging uses PEP 621 metadata in `pyproject.toml` (no `setup.py`).
- Public API (current): `ConfigCore`, `ConfigNotFound`, `ConfigParseError`.
- Future modules (e.g., `YamlStream`, comment-preserving editor) will live under this package.

---

## Behavior and Guarantees (Current Scope)

- Encoding: files are read as UTF-8.
- Empty file: treated as an empty mapping `{}`.
- `get("")`: returns the entire root mapping (dict).
- Dotted path resolution: split on `.`; empty segments are ignored.
- Errors:
  - Missing file → `ConfigNotFound(path)`.
  - YAML errors → `ConfigParseError(path, message, line?, column?)`.
- Global state: `ConfigCore` maintains a single `_path` and `_cache`; not thread-safe; one active config at a time.
- `reload()` re-reads the configured file into memory.

---

## Compatibility and Support

- Python versions: 3.10–3.12 (3.13 pending CI validation).
- Typed package (PEP 561): ships `py.typed` and includes it in wheels.
- OS independent; pure Python (file I/O + PyYAML only).
- Intended for small-to-medium YAML files (KB–low MB).

---

## Packaging and Release

- PEP 621 metadata lives in `pyproject.toml`.
- README configuration:
  - `readme = { file = "README.md", content-type = "text/markdown" }`
- URLs must live under a dedicated table:
  ```toml
  [project.urls]
  Homepage = "https://github.com/dckallos/py-yaml-config-loader"
  "Bug Tracker" = "https://github.com/dckallos/py-yaml-config-loader/issues"
  ```
- Ship typing marker and license in artifacts:
  ```toml
  [tool.setuptools.package-data]
  yaml_config_loader = ["py.typed"]

  [tool.setuptools.license-files]
  paths = ["LICENSE"]
  ```
- Classifiers include: OS Independent, Python 3 :: Only, Typing :: Typed, and target Python versions.
- Version exposure: `yaml_config_loader.__version__` reads from installed metadata with a safe fallback.

### Release checklist
1. `scripts/dev-tools.sh fmt && scripts/dev-tools.sh lint && scripts/dev-tools.sh type && scripts/dev-tools.sh test`
2. `scripts/dev-tools.sh build && scripts/dev-tools.sh check`
3. `scripts/dev-tools.sh upload-test` (validate on TestPyPI)
4. `scripts/dev-tools.sh upload` (PyPI)

---

## Roadmap Status

- Current: read-only loader and dotted-path access (Objective 1).
- Not yet implemented: in-place edits, multi-doc editing, CLI.
- When edit features land, they will preserve comments/anchors by splicing YAML text using node marks, not whole-file reserialization.

---

## Target Audience & Use Cases

This loader is useful anywhere YAML configs are manually edited and **must retain formatting and comments**:

* Kubernetes ConfigMaps and manifests
* Helm chart overrides
* CI/CD pipeline configs
* Local development `.yaml` files where comments are documentation

