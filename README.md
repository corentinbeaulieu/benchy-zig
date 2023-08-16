# benchy-zig

Automated benching tool written in zig. The first aim of this project is to learn a bit more about zig.
The application runs commands given in a configuration file multiple times and gives metrics on the execution time.

## TO DO

- [ ] Take a proper configuration file (yaml, json ?)
- [ ] Take the number of time the programs will be launch
- [ ] Return the data (csv)
- [ ] Generate a script to plot the results
- [ ] Enhance memory management (it is a bit leaky)

## Installation

```bash
$ zig build
```
The executatble is located in `zig-out/bin/`

## Usage

The program reads a `benchy.yml` (it is not a yaml file yet) file describing the bench to run.
Here is an example

```
2          <---- number of prorams to run
./my_prog  <---- commands to run
./my_prog2 
```

It outputs the results to the standard output for the moment.

## Ideas

### Yaml configuration file

The yaml may look like something like this :

```yaml
bench1:
  number_of_programs: 2
  number_of_runs: 32
  programs: [ {name: 'my_prog', argv: "./my_prog"}, {name: 'my_prog2', argv: "./my_prog2"}]
  output: "path/to/output.csv"
bench2:
```

The idea is to have multiple bench suites and the difference computation will made only whithin those.
