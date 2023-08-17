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

pub const compute = @import("benchy-compute.zig");
const Results = compute.Results;

const Input = struct {
    names: []const []const u8,
    cmds: []*ArrayList([]const u8),
    nb_run: u16,
};

/// Parses and formates the input file
pub fn get_argv(allocator: Allocator) !Input {
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
/// Print the results on the standard output
pub fn print_stdout(results_arr: []const Results) !void {
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
pub fn print_csv(results_arr: []const Results) !void {
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