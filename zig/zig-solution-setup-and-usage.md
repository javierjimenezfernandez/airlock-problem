# Zig Airlock — Setup & Usage

## Environment Setup

This project uses a **local Zig installation** — no system-wide install required.

1. Download the Zig 0.13.0 tarball for your platform from https://ziglang.org/download/
   (grab the `0.13.0` release, not master)

2. Extract it inside the **project root** (one level above `zig/`):
   ```sh
   tar xf zig-linux-x86_64-0.13.0.tar.xz
   ```

3. Create a symlink inside the `zig/` folder for convenience:
   ```sh
   ln -s ../zig-linux-x86_64-0.13.0/zig zig/zig
   ```

4. Verify the installation:
   ```sh
   cd zig
   ./zig version
   # expected: 0.13.0
   ```

> If you use VS Code with the Zig extension, make sure to point it at the local binary
> (`zig-linux-x86_64-0.13.0/zig`) in the extension settings, otherwise it will download
> and use its own version which may differ.

## Compilation

From inside the `zig/` folder:

```sh
./zig build-exe airlock.zig
```

This produces an `airlock` executable in the `zig/` folder.

## Usage

```sh
./airlock [--cycles N] [--eva-duration MS] [--pressurize-duration MS]
```

| Flag                    | Description                                              | Default |
|-------------------------|----------------------------------------------------------|---------|
| `--cycles N`            | Number of full round trips each astronaut performs       | `3`     |
| `--eva-duration MS`     | Time (ms) an astronaut waits before requesting the airlock | `200` |
| `--pressurize-duration MS` | Time (ms) to (de-)pressurize the chamber             | `300`   |

### Example

```sh
./airlock --cycles 5 --eva-duration 100 --pressurize-duration 200
```

### Sample output

```
[astronaut A] wants to EXIT to EVA
[exit]  inside door OPEN
[exit]  inside door CLOSED
[exit]  astronaut inside chamber
[exit]  chamber DEPRESSURIZING...
[exit]  chamber DEPRESSURIZED
[exit]  outside door OPEN — astronaut in EVA
[exit]  outside door CLOSED
...
All cycles complete.
```

Output is written to **stderr** and is protected by the airlock mutex, so lines from
concurrent threads never interleave.
