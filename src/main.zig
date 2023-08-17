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

const Input = struct {
    names: []const []const u8,
    cmds: []*ArrayList([]const u8),
    nb_run: u16,
};

const Results = struct {
    name: []const u8,
    mean: f64,
    min: f64,
    max: f64,
    stddev: f64,
    median: f64,
    diff: f64,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    //Read config file
    const input = try get_argv(allocator);
    defer allocator.free(input.cmds);
    defer allocator.free(input.names);

    //Run benchies
    const my_results = try run_benchies(allocator, input.cmds, input.nb_run);
    defer allocator.free(my_results);

    for (my_results, input.names) |*result, name| {
        result.name = name;
    }

    //Print (or save) Results
    try print_stdout(my_results);

    try print_csv(my_results);
}

/// Parses and formates the input file
fn get_argv(allocator: Allocator) !Input {
    const file = try std.fs.cwd().openFile("./benchy.yml", std.fs.File.OpenFlags{});
    const reader = file.reader();

    var read_buffer: [1024]u8 = undefined;

    _ = try reader.readAll(&read_buffer);

    var it = std.mem.tokenizeAny(u8, &read_buffer, "\n");
    const nb_run = try std.fmt.parseInt(u16, it.next().?, 10);
    const nb_prog = try std.fmt.parseInt(u32, it.next().?, 10);

    const ret_cmds: []*ArrayList([]const u8) = try allocator.alloc(*ArrayList([]const u8), nb_prog);
    const ret_names: [][]u8 = try allocator.alloc([]u8, nb_prog);

    var i: u32 = 0;

    while (it.next()) |line| {
        ret_names[i] = try allocator.alloc(u8, line.len);
        @memcpy(ret_names[i], line);
        ret_cmds[i] = try allocator.create(ArrayList([]const u8));
        ret_cmds[i].* = ArrayList([]const u8).init(allocator);
        var iter = std.mem.tokenizeAny(u8, line, " \"");
        while (iter.next()) |item| {
            var to_store = try allocator.alloc(u8, item.len);
            @memcpy(to_store, item);
            try ret_cmds[i].append(to_store);
        }
        i += 1;
        if (i == nb_prog) break;
    }
    //const fake_ret_cmds: [1][:0]const u8 = .{"./a.out"};
    return .{ .names = ret_names, .cmds = ret_cmds, .nb_run = nb_run };
}

/// Measures the benchies and aggregate the results
fn run_benchies(allocator: Allocator, argv_list: []*ArrayList([]const u8), count: u16) ![]Results {
    var begin: std.os.timespec = undefined;
    var end: std.os.timespec = undefined;
    const measures = try allocator.alloc(f64, count);
    defer allocator.free(measures);
    @memset(measures, 0);

    var first: bool = true;
    var reference: f64 = undefined;
    const rets = try allocator.alloc(Results, argv_list.len);
    var i: u32 = 0;

    for (argv_list, rets) |argv, *ret| {
        for (measures) |*measure| {
            const pid = try std.os.fork();
            if (pid == 0) {
                {
                    var argv_owned = try argv.toOwnedSlice();
                    const exec_error = std.process.execv(allocator, argv_owned);
                    if (exec_error == std.os.ExecveError.FileNotFound) return exec_error;
                }
                std.process.exit(0);
            } else {
                try std.os.clock_gettime(0, &begin);
                _ = std.os.waitpid(pid, 0);
                try std.os.clock_gettime(0, &end);

                measure.* = @as(f64, @floatFromInt(end.tv_sec - begin.tv_sec)) + (@as(f64, @floatFromInt(end.tv_nsec - begin.tv_nsec)) * 1e-9);
            }
        }

        std.sort.heap(f64, measures, {}, std.sort.asc(f64));
        const mean = compute_mean(measures);
        if (first) {
            reference = mean;
            first = false;
        }

        ret.* = .{
            .name = undefined,
            .mean = mean,
            .min = measures[0],
            .max = measures[count - 1],
            .stddev = compute_stddev(measures, mean),
            .median = compute_median(measures, true),
            .diff = ((mean - reference) / reference) * 100,
        };
        i += 1;
    }
    allocator.free(argv_list);
    return rets;
}

/// Compute the mean of the values in a vector
fn compute_mean(vec: []const f64) f64 {
    var sum: f64 = 0.0;

    for (vec) |elem| {
        sum += elem;
    }

    return sum / @as(f64, @floatFromInt(vec.len));
}

/// Compute the standard deviation of the values in a vector
fn compute_stddev(vec: []const f64, mean: f64) f64 {
    var sum: f64 = 0.0;

    for (vec) |elem| {
        var tmp: f64 = elem - mean;
        sum += tmp * tmp;
    }

    return ((@sqrt(sum / @as(f64, @floatFromInt(vec.len)))) / mean) * 100;
}

/// Compute the median of the values in a vector
fn compute_median(vec: []f64, is_sorted: bool) f64 {
    if (!is_sorted) {
        std.sort.heap(f64, vec, {}, std.sort.asc(f64));
    }

    const is_even: bool = ((vec.len & 0x1) == 1);

    if (!is_even) {
        return (vec[vec.len / 2] + vec[vec.len / 2 - 1]) / 2;
    } else {
        return vec[vec.len / 2];
    }
}

/// Print the results on the standard output
fn print_stdout(results_arr: []const Results) !void {
    const stdout = std.io.getStdOut();
    const tty_conf = std.io.tty.detectConfig(stdout);
    const writer = stdout.writer();

    try writer.print("{s:^40}|{s:^26}|{s:^15}|{s:^15}|{s:^15}|{s:^9}\n", .{ "name", "mean", "min", "max", "median", "diff" });
    try writer.print("{s}\n", .{"-" ** 40 ++ "+" ++ "-" ** 26 ++ "+" ++ "-" ** 15 ++ "+" ++ "-" ** 15 ++ "+" ++ "-" ** 15 ++ "+" ++ "-" ** 9});
    for (results_arr) |result| {
        try writer.print(" {s: <38} | {d: >11.6}s", .{ result.name, result.mean });

        if (result.stddev > 5.0) {
            try tty_conf.setColor(writer, .red);
        } else {
            try tty_conf.setColor(writer, .green);
        }

        try writer.print(" +/- {d: >6.2}% ", .{result.stddev});
        try tty_conf.setColor(writer, .white);
        try writer.print("| {d: >12.6}s | {d: >12.6}s | {d: >12.6}s | ", .{ result.min, result.max, result.median });

        if (result.diff == 0.0) {
            try tty_conf.setColor(writer, .yellow);
            try writer.print(" {s: ^5} \n", .{"ref"});
        } else {
            if (result.diff > 0.0) {
                try tty_conf.setColor(writer, .red);
            }
            if (result.diff < 0.0) {
                try tty_conf.setColor(writer, .green);
            }
            try writer.print(" {d: >5.2}% \n", .{result.diff});
        }
        try tty_conf.setColor(writer, .white);
    }
}

/// Print the results in a csv file
fn print_csv(results_arr: []const Results) !void {
    var directory = try std.fs.cwd().makeOpenPath("./benchy-output", std.fs.Dir.OpenDirOptions{});

    var tmp_buf: [46]u8 = undefined;
    const timestamp = std.time.microTimestamp();
    const filename = try std.fmt.bufPrint(@as([]u8, &tmp_buf), "./benchy-output/benchy-{d}.csv", .{timestamp});
    const file = try std.fs.cwd().createFile(filename, std.fs.File.CreateFlags{});
    const writer = file.writer();

    try writer.print("{s:^40};{s:^14};{s:^14};{s:^14};{s:^14};{s:^14};{s:^10};\n", .{ "name", "mean (s)", "stddev (s)", "min (s)", "max (s)", "median (s)", "diff (%)" });
    for (results_arr) |result| {
        try writer.print(" {s: <38} ; {d: >12.6} ; {d: >12.6} ; {d: >12.6} ; {d: >12.6} ; {d: >12.6} ; {d: >8.3} ;\n", .{ result.name, result.mean, (result.stddev / 100.0) * result.mean, result.min, result.max, result.median, result.diff });
    }

    file.close();
    directory.close();
}

test "Allocation test" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    const allocator = arena.allocator();

    //Read config file
    var input = try get_argv(allocator);
    defer allocator.free(input);

    //Run benchies
    const my_results = try run_benchies(allocator, input, 2);
    defer allocator.free(my_results);

    //Print (or save) Results
    try print_stdout(my_results);
}
