# Background for this Functionality

I’ve always relied on external configuration files to drive behavior in my Python and R scripts (thank you, mentors). YAML and JSON have been my go-to formats because they’re human-readable, diff-friendly, and easy to version. This repository includes a small reference implementation in [config_loader.py](./config_loader.py), and I’ve also incorporated this specific `ConfigLoader` into one of my projects: https://github.com/dckallos/simple-crypto-trader-poc

## Why you shouldn't reference this exact file

This file's functionality sucks, and it merely met my requirements for [this project](https://github.com/dckallos/simple-crypto-trader-poc). As such, I'm using this exact python file as an inspirational reference for the code that I'm about to create in this repository.

### Limitations

## Why this pattern helped

- Human-centric: You can open `config.yaml`, read values at a glance, and tweak them quickly.
- Iteration speed: It’s often helpful to keep an app running and modify a parameter on the fly; the loader here re-reads the config so new values are picked up without a restart.
- Separation of concerns: Business logic lives in code; operational details live in config. Duh.

## What [config_loader.py](./config_loader.py) provides

- Simple read access to nested keys (dotted paths) with sensible defaults.
- A convenience getter for common items (e.g., traded pairs).
- A basic setter that persists values back to `config.yaml` immediately. I didn't say that it was a good setter, nor that configuration setters are a good idea. In my case, the setter would re-write the entire config file, losing all formatting and comments.

## Next Steps

I never quite automated Kubernetes-based parsing scripts, to the extent that I could provide a consistent, pre-created utility to read objects such as ConfigMap files. I don't want to keep wasting time with half-assed solutions, so I'm going to try to implement a more robust solution for the future. Fingers crossed that I'm decently clever about it.