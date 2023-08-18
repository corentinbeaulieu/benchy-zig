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

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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
    const input = try io.get_argv(allocator);
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

test "Allocation test" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    const allocator = arena.allocator();

    //Read config file
    var input = try io.get_argv(allocator);
    defer allocator.free(input);

    //Run benchies
    const my_results = try compute.run_benchies(allocator, input, 2);
    defer allocator.free(my_results);

    //Print (or save) Results
    try io.print_stdout(my_results);
}
