# Benchy

Automated benching tool written in zig. The first goal of this project is to learn a bit more about zig.
The application runs commands given in a configuration file multiple times and gives metrics on the execution time.

It is thought to compare different version of a given program.

## TO DO

- [ ] Take a proper configuration file as input (yaml, json ?)
- [x] Take the number of time the programs will be launch
- [x] Return the data (csv)
- Options
    - [x] Change the csv name
    - [x] Don't generate csv or stdout
    - [x] Display help
    - [x] Throw the stdout of the measured programs
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

The available options :
```
benchy --help
    -h, --help
            Display this help and exit

        --no_csv
            Don't write a csv file of the results

        --no_stdout
            Don't print the results on the standard output

    -o, --csv_filename <str>
            Name to give to the output csv
```

The program reads a `benchy.yml` (it is not a yaml file yet) file describing the bench to run.
This file must be located in the current working directory when invoking the program.

<details>
<summary> Here is an example: </summary>

```
10         <---- number of run for each program
2          <---- number of prorams to run
./my_prog  <---- commands to run
./my_prog2 
```

</details>

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
bench2: ...
```

The idea is to have multiple bench suites and the difference computation will be made only within those.
We will use [zig-yaml](https://github.com/kubkon/zig-yaml).

### Zon configuration file

The zon will look like the input structure:

```zig
.{
    .name = "name of the bench",
    .nb_run = nombre de runs,
    .names = .{ "name of", "the programs" },
    .argvs = .{ 
        .{"./prog1"}, 
        .{"./prog2", "arg1", "arg2"}
    },
}
```

We may use [eggzon](https://github.com/ziglibs/eggzon) or find the standard one or write our own.

### Change the clock

The standard library has a timer meant to measure this kind of events.
It can be a good idea to use it instead of the `clock_gettime`.
- [Timer](https://ziglang.org/documentation/master/std/#A;std:time.Timer)

### Investigate package managers

- [official](https://kassane.github.io/2023/05/03/zig-pkg/) (Where is the official doc)
- [gyro](https://github.com/mattnite/gyro) -> closed
- [zigmod](https://github.com/nektro/zigmod)
- [zpm](https://github.com/zigtools/zpm)
