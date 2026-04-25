# DL16 sigrok-cli Harness

This repo now includes a minimal local test flow for the in-progress
`alientek-dl16` `libsigrok` driver.

Script:

- [tools/test-dl16-sigrok-cli.sh](/home/adam/work/atk-logic/tools/test-dl16-sigrok-cli.sh:1)

What it does:

- builds and installs the patched local `libsigrok` into `.sigrok-local/`
- clones `sigrok-cli` into `./sigrok-cli/` if it is not already present
- builds and installs `sigrok-cli` against that local `libsigrok`
- configures `sigrok-cli` without `libsigrokdecode`, so scan/capture can be
  exercised even if the local decoder library is on an incompatible API
- runs a DL16 scan
- optionally runs a short binary capture smoke test

Examples:

```bash
# Build local libsigrok and local sigrok-cli.
./tools/test-dl16-sigrok-cli.sh build-sigrok-cli

# Scan for the device using the locally built stack.
./tools/test-dl16-sigrok-cli.sh scan

# Run a short smoke capture.
SAMPLERATE=100m SAMPLES=100000 ./tools/test-dl16-sigrok-cli.sh capture

# Full flow.
./tools/test-dl16-sigrok-cli.sh all
```

Useful environment overrides:

```bash
PREFIX_DIR=/tmp/sigrok-local
SIGROK_CLI_DIR=/path/to/sigrok-cli
LIBSIGROK_DIR=/path/to/libsigrok
BUILD_JOBS=8
SAMPLERATE=50m
SAMPLES=50000
OUTPUT_FILE=/tmp/dl16.bin
```

Notes:

- The DL16 driver is still early-stage. Scan and identify should work more
  reliably than capture.
- The capture path currently targets a simple immediate one-shot acquisition.
- `sigrok-cli` is not installed on this machine globally, so the harness builds
  a local copy and runs it via the local prefix.
- Decoder support is intentionally disabled in this harness build. That keeps
  the smoke test focused on the hardware driver path rather than protocol
  decoders.
