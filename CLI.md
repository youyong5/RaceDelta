# RaceDelta Native CLI

RaceDelta's executable is an offline Native CLI. It reads a CSV v1 race file, replays one explicit counterfactual pit plan, explains the result, and renders one Markdown report. The calculation pipeline remains in the root library package; `cmd/main` only handles arguments, files, and terminal streams.

## Setup and validation

The project declares the official `moonbitlang/async@0.20.2` dependency in `moon.mod` and sets `preferred_target = "native"`. It uses the package's public `fs` and `stdio` APIs; no HTTP package is imported.

```sh
moon fmt
moon check --target native
moon test --target native
moon build --target native cmd/main
```

## Usage

```text
racedelta <input.csv> --driver <DRIVER> --opponent <DRIVER> --stops <PLAN> [-o <report.md>]
```

Run from the repository root with MoonBit:

```sh
moon run cmd/main -- examples/basic_race.csv --driver ALP --opponent BRV --stops 2:MEDIUM
```

MoonBit reserves an unseparated `--help` for `moon run` itself. To show the RaceDelta program help, forward it after MoonBit's separator:

```sh
moon run cmd/main -- --help
```

`--driver` is the target whose pit plan is replaced. `--opponent` is the driver used for signed-gap comparison.

### PLAN

- `none` — replay with no planned pit stops.
- `12:MEDIUM` — pit at the end of lap 12; use MEDIUM from the next lap.
- `12:MEDIUM,28:HARD` — two planned stops.

Laps must be positive decimal integers. Compounds are exactly `SOFT`, `MEDIUM`, `HARD`, `INTERMEDIATE`, or `WET`. The parser rejects empty entries, whitespace-padded entries, missing or extra colons, invalid compounds, and repeated pit laps. M4 remains the single authority for race-specific lap range, plan ordering normalization, selected-driver existence, and full strategy validity.

### Output

With no output option, stdout contains only the Markdown report:

```sh
moon run cmd/main -- examples/basic_race.csv --driver ALP --opponent BRV --stops none
```

Use `-o` or `--output` to create or overwrite a UTF-8 Markdown file. The completion notice goes to stderr so the report stream remains clean:

```powershell
moon run cmd/main -- examples/basic_race.csv --driver ALP --opponent BRV --stops 2:MEDIUM -o "C:\Temp\RaceDelta report.md"
```

The CLI passes argv values through unchanged. Therefore Windows absolute paths and paths containing spaces work when the shell quotes them normally. It never creates missing parent directories; an unreadable input or unwritable output is reported as an error.

## Errors and exit status

Argument and PLAN failures are reported before file access. File I/O, CSV validation, unknown drivers, invalid M4 strategy requests, and explanation failures are also reported with a concise `error:` message on stderr.

`moonbitlang/async@0.20.2` has no public supported API for choosing an exit status. After writing the user-facing error, the command propagates a public MoonBit error through the official async-main boundary; the Native runtime terminates nonzero. This toolchain does not provide a supported way to distinguish usage status `2` from operational status `1` without private APIs or custom FFI, neither of which RaceDelta uses. The dependency's current native async boundary also emits a short `Failure(...)` diagnostic to stdout on failure; successful report and file-output modes keep stdout and stderr separate.

## Current limitations

- The CLI accepts one explicit plan; it does not automatically search for a better strategy.
- It writes Markdown only; it does not read stdin, write HTML, create directories, or provide a graphical interface.
- File paths are local only. The CLI makes no network requests and does not use a real-time F1 API.
- The pace and pit-loss values are illustrative teaching parameters, not official F1 data for any circuit, tyre, or driver. Reports are explanatory counterfactuals, not precise real-race predictions.
