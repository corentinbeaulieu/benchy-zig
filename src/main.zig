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
const clap = @import("clap");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

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

    //Print (or save) Results
    try io.print_stdout(my_results);

    try io.print_csv(my_results);
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
