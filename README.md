# Benchy

Automated benching tool written in zig. The first goal of this project is to learn a bit more about zig.
The application runs commands given in a configuration file multiple times and gives metrics on the execution time.

It is thought to compare different version of a given program.

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

 
        --no_script
            Don't write a gnuplot script template (automatically selected if no csv is requested)       
        
        --no_stdout
            Don't print the results on the standard output

    -o, --csv_filename <str>
            Name to give to the output csv
```

The program reads a `benchy.yml` file describing the bench to run.
This file must be located in the current working directory when invoking the program.

<details>
<summary> Here is all possible options: </summary>

```yaml
nb_runs: 2                          # Number of runs per program
warmup: 2                           # Number of warm_ups to do
names: [ test1, my_super_test ]     # names of the tests
argvs: [ "./a.out 1", "./my_test" ] # Commands to run
```

</details>

It outputs the results to the standard output.
It also generates a csv file in `./benchy-output/`. The file is timestamped by default.
By default, a simple gnuplot script is generated to plot the csv.

## TO DO

### Features

- [X] Take a proper configuration file as input (yaml, JSON, zon ?)
- [X] Take the number of time the programs will be launch
- [X] Return the data (csv)
- [ ] Possibility to give a path to the config file we want
- [x] Possibility to do warm-up runs
- [X] Generate a script to plot the results
- [ ] Make the timestamp human-readable (`DD-MM-YYYY-hh-mm-ss`)
- Options
    - [X] Change the csv name
    - [X] Don't generate csv or stdout
    - [X] Don't generate script
    - [ ] Choose script format ? (gnuplot? python? ...?)
    - [ ] Change script, plot name
    - [X] Display help
    - [ ] Throw the stdout of the measured programs
- Add other metrics
    - [ ] memory usage
    - [ ] binary size

### Debug

- [ ] Enhance (memory management, idiomatic zig, builtins... )
- [ ] Issue with the name display
    - On the SIMD test, we have only the two first names
- [ ] Script named after the csv if given with option
- [ ] Get the `CLOCK_MONOTONIC_RAW` clock for measure
- [ ] Add tests
- [ ] Fix the gnuplot script (placement issue)
- [ ] Fix size retrievement on non-local file (`which` and absolute path ?)

## Ideas

### Configuration file

We will use [zig-yaml](https://github.com/kubkon/zig-yaml) to parse the input yaml file.

#### Zon

**This solution needs us to find a deserializer or make one**

The zon will look like the input structure:

<details>
<summary> Option 1 </summary>

```zig
.{
    .name = "name of the bench",
    .nb_run = number_of_runs,
    .names = .{ "name of", "the programs" },
    .argvs = .{ 
        .{"./prog1"}, 
        .{"./prog2", "arg1", "arg2"}
    },
}
```

</details>

<details>
<summary> Option 2 </summary>

```zig
.{
    .name = "name of the bench",
    .nb_run = number_of_runs,
    .tests = .{
        .{
            .name = "name of",
            .argv = .{"./prog1"},
        },
        .{
            .name = "the program",
            .argv = .{ "./prog1", "arg1", "arg2" },
        },
    },
}
```

</details>

We may use [eggzon](https://github.com/ziglibs/eggzon) or find the standard one or write our own.

#### JSON

### Change the clock

The standard library has a timer meant to measure this kind of events.
It can be a good idea to use it instead of the `clock_gettime`.
- [Timer](https://ziglang.org/documentation/master/std/#A;std:time.Timer)

### Call directly gnuplot

We can use [gnuzplot](https://github.com/BlueAlmost/gnuzplot) to avoid using an intermediate script.

### Investigate package managers

- [official](https://kassane.github.io/2023/05/03/zig-pkg/) (Where is the official doc?)
- [gyro](https://github.com/mattnite/gyro) → closed
- [zigmod](https://github.com/nektro/zigmod)
- [zpm](https://github.com/zigtools/zpm)

## Alternatives

You may be interested in more advanced projects such as
- [hyperfine](https://github.com/sharkdp/hyperfine)
- [bench](https://github.com/Gabriella439/bench)
