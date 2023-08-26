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

const io = @import("benchy-io");
const compute = io.compute;

// External dependencies
const clap = @import("clap");

const yaml = @import("yaml");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help               Display this help and exit
        \\--no-csv                 Don't write a csv file of the results
        \\--no-script              Don't write a gnuplot script template (automatically selected if no csv is requested)
        \\--no-stdout              Don't print the results on the standard output
        \\-o, --csv-filename <str> Name to give to the output csv
    );
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        clap.help(std.io.getStdOut().writer(), clap.Help, &params, .{}) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdOut().writer(), clap.Help, &params, .{});

    //Read config file
    const yml_input = try read_yaml(allocator);
    for (yml_input.names) |name| {
        std.debug.print("{s}\n", .{name});
    }
    const input = try io.get_argv(allocator, yml_input);
    defer allocator.free(input.cmds);
    defer allocator.free(input.names);

    //Run benchies
    const my_results = try compute.run_benchies(allocator, input.cmds, input.nb_run, yml_input.warmup);
    defer allocator.free(my_results);

    for (my_results, input.names) |*result, name| {
        result.name = name;
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

fn read_yaml(allocator: Allocator) !io.YamlRepr {
    const file = try std.fs.cwd().openFile("./benchy.yml", std.fs.File.OpenFlags{});
    defer file.close();
    const reader = file.reader();

    const read_buffer = try reader.readAllAlloc(allocator, 4096);
    defer allocator.free(read_buffer);

    var untyped = try yaml.Yaml.load(allocator, read_buffer);
    defer untyped.deinit();

    const deserialize = try untyped.parse(io.YamlRepr);

    return deserialize;
}

test "Allocation Test" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help               Display this help and exit
        \\--no_csv                 Don't write a csv file of the results
        \\--no_script              Don't write a gnuplot script template (automatically selected if no csv is requested)
        \\--no_stdout              Don't print the results on the standard output
        \\-o, --csv_filename <str> Name to give to the output csv
    );
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        clap.help(std.io.getStdOut().writer(), clap.Help, &params, .{}) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdOut().writer(), clap.Help, &params, .{});

    //Read config file
    const yml_input = try read_yaml(allocator);
    const input = try io.get_argv(allocator, yml_input);
    defer allocator.free(input.cmds);
    defer allocator.free(input.names);

    //Run benchies
    const my_results = try compute.run_benchies(allocator, input.cmds, input.nb_run);
    defer allocator.free(my_results);

    for (my_results, input.names) |*result, name| {
        result.name = name;
    }

    //Print the Results
    if (res.args.no_stdout == 0)
        try io.print_stdout(my_results);

    //Print the Results
    if (res.args.no_csv == 0) {
        const script: bool = res.args.no_script == 0;
        if (res.args.csv_filename) |filename| {
            try io.print_csv(my_results, filename, script);
        } else {
            try io.print_csv(my_results, null, script);
        }
    }
}
