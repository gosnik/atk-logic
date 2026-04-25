# Local PulseView integration

This repo contains:

- a local `libsigrok/` tree with the `alientek-dl16` driver
- a local `pulseview/` tree
- a local install prefix at `.sigrok-local/`

Use the helper script from the repo root:

```bash
./tools/build-pulseview-local.sh
```

That will:

1. rebuild `libsigrok` into `.sigrok-local/` with shared libraries and `libsigrokcxx`
2. configure `pulseview/` against that local prefix
3. build `pulseview/build-local/pulseview`

Run the built binary with:

```bash
LD_LIBRARY_PATH="/home/adam/work/atk-logic/.sigrok-local/lib:$LD_LIBRARY_PATH" \
  /home/adam/work/atk-logic/pulseview/build-local/pulseview
```

Notes:

- `libsigrokdecode` is currently resolved from `/usr/local`.
- The local PulseView binary has a runpath pointing at `.sigrok-local/lib`, so `LD_LIBRARY_PATH` is mainly useful for explicit testing.
- Decoder warnings such as malformed `tags` attributes come from installed protocol decoders and are separate from the DL16 hardware driver.
