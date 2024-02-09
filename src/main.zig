//MIT License

//Copyright (c) 2023 Corentin Beaulieu

//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:

//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.

//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const io = @import("benchy-io.zig");
const compute = io.compute;

// External dependencies
const clap = @import("clap");

const yaml = @import("yaml");

const BenchyError = error{
    WrongNumberOfArgs,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help                Display this help and exit
        \\--no-csv                  Don't write a csv file of the results
        \\--no-script               Don't write a gnuplot script template (automatically selected if no csv is requested)
        \\--no-stdout               Don't print the results on the standard output
        \\--cmd-output              Print measured program standard output
        \\-o, --csv-filename <NAME> Name to give to the output csv
        \\<PATH>                    Path to configuration file
    );
    var diag = clap.Diagnostic{};
    const clap_parsers = comptime .{ .PATH = clap.parsers.string, .NAME = clap.parsers.string };
    var res = clap.parse(clap.Help, &params, clap_parsers, .{
        .allocator = allocator,
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{}) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdOut().writer(), clap.Help, &params, .{});

    if (res.positionals.len > 1) {
        clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{}) catch {};
        return BenchyError.WrongNumberOfArgs;
    }

    var config_name: ?[]const u8 = null;

    if (res.positionals.len == 1) config_name = res.positionals[0];

    var cmd_output = false;
    if (res.args.@"cmd-output" != 0) cmd_output = true;

    //Read config file
    const yml_input = try read_yaml(allocator, config_name);
    const input = try io.get_argv(allocator, yml_input);
    defer allocator.free(input.cmds);
    defer allocator.free(input.names);

    //Run benchies
    const my_results = try compute.run_benchies(allocator, input.names, input.cmds, input.nb_run, yml_input.warmup, cmd_output);
    defer allocator.free(my_results);

    for (my_results, input.names) |*result, name| {
        result.*.name = name;
    }

    //Print the Results
    if (res.args.@"no-stdout" == 0)
        try io.print_stdout(my_results);

    //Print the Results
    if (res.args.@"no-csv" == 0) {
        const script: bool = res.args.@"no-script" == 0;
        if (res.args.@"csv-filename") |filename| {
            try io.print_csv(my_results, filename, script);
        } else {
            try io.print_csv(my_results, null, script);
        }
    }
}

fn read_yaml(allocator: Allocator, configName: ?[]const u8) !io.YamlRepr {
    const filename = configName orelse "./benchy.yml";
    const file = try std.fs.cwd().openFile(filename, std.fs.File.OpenFlags{});
    defer file.close();
    const reader = file.reader();

    const read_buffer = try reader.readAllAlloc(allocator, 4096);
    defer allocator.free(read_buffer);

    var untyped = try yaml.Yaml.load(allocator, read_buffer);
    defer untyped.deinit();

    const deserialize = try untyped.parse(io.YamlRepr);

    return deserialize;
}

test "memory" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var names: [2][]const u8 = .{ "yes", "no" };
    var argvs: [2][]const u8 = .{ "/usr/bin/ls", "/usr/bin/lsd" };

    const yml_input = io.YamlRepr{
        .nb_runs = 2,
        .warmup = 1,
        .names = &names,
        .argvs = &argvs,
    };
    const input = try io.get_argv(allocator, yml_input, false);
    defer allocator.free(input.cmds);
    defer allocator.free(input.names);

    const my_results = try compute.run_benchies(allocator, input.cmds, input.nb_run, yml_input.warmup);
    defer allocator.free(my_results);
}
