// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "youyong5/racedelta"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/youyong5/RaceDelta"

license = "MIT"

keywords = [
  "motorsport",
  "race-strategy",
  "simulation",
  "data-analysis",
  "cli",
]

preferred_target = "native"

description = "Deterministic race strategy simulation and crossover analysis in MoonBit."

import {
  "moonbitlang/async@0.20.2",
}
