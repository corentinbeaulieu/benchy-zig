# Benchy

Automated benching tool written in zig. The first aim of this project is to learn a bit more about zig.
The application runs commands given in a configuration file multiple times and gives metrics on the execution time.

Its goal is to compare different version of a given program.

## TO DO

- [ ] Take a proper configuration file as input (yaml, json ?)
- [x] Take the number of time the programs will be launch
- [x] Return the data (csv)
- Options
    - [ ] Change the csv name
    - [ ] Don't generate csv or stdout
    - [ ] Display help
- [ ] Generate a script to plot the results
- [ ] Add tests
- Add other metrics
    - [ ] memory usage
    - [ ] binary size
- [ ] Get the `CLOCK_MONOTONIC_RAW` clock for measure
- [ ] Enhance (memory management, idiomatic zig, builtins... )

## Installation

```bash
$ zig build
```
The executable is located in `zig-out/bin/`

## Usage

The program reads a `benchy.yml` (it is not a yaml file yet) file describing the bench to run.
This file must be located in the current working directory when invoking the program.
Here is an example

```
10         <---- number of run for each program
2          <---- number of prorams to run
./my_prog  <---- commands to run
./my_prog2 
```

It outputs the results to the standard output for the moment.
It also generates a csv file in `./benchy-output/`. The file is timestamped by default.

## Ideas

### Yaml configuration file

The yaml may look like this :

```yaml
bench1:
  number_of_programs: 2
  number_of_runs: 32
  programs: [ {name: 'my_prog', argv: "./my_prog"}, {name: 'my_prog2', argv: "./my_prog2"}]
  output: "path/to/output.csv"
bench2:
```

The idea is to have multiple bench suites and the difference computation will be made only within those.

### Change the clock

The standard library has a timer meant to measure this kind of events.
It can be a good idea to use it instead of the `clock_gettime`
- [Timer](https://ziglang.org/documentation/master/std/#A;std:time.Timer)
