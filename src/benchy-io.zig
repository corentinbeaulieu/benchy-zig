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

pub const YamlRepr = struct {
    names: [][]const u8,
    argvs: [][]const u8,
    nb_runs: u16,
    warmup: ?u8,
};

/// Parses and formates the input file
pub fn get_argv(allocator: Allocator, yml_input: YamlRepr) !Input {
    const ret_cmds: []*ArrayList([]const u8) = try allocator.alloc(*ArrayList([]const u8), yml_input.argvs.len);
    const ret_names: [][]u8 = try allocator.alloc([]u8, yml_input.names.len);

    var i: u32 = 0;

    for (yml_input.names, yml_input.argvs) |name, argv| {
        ret_names[i] = try allocator.alloc(u8, name.len);
        @memcpy(ret_names[i], name);
        ret_cmds[i] = try allocator.create(ArrayList([]const u8));
        ret_cmds[i].* = ArrayList([]const u8).init(allocator);
        var iter = std.mem.tokenizeAny(u8, argv, " ");
        while (iter.next()) |item| {
            var to_store = try allocator.alloc(u8, item.len);
            @memcpy(to_store, item);
            try ret_cmds[i].append(to_store);
        }
        i += 1;
    }
    //const fake_ret_cmds: [1][:0]const u8 = .{"./a.out"};
    return .{ .names = ret_names, .cmds = ret_cmds, .nb_run = yml_input.nb_runs };
}
/// Print the results on the standard output
pub fn print_stdout(results_arr: []const Results) !void {
    const stdout = std.io.getStdOut();
    const tty_conf = std.io.tty.detectConfig(stdout);
    const writer = stdout.writer();

    try writer.print("{s:^40}|{s:^26}|{s:^15}|{s:^15}|{s:^15}|{s:^9}|{s:^16}|{s:^10}\n", .{ "name", "mean", "min", "max", "median", "diff time", "size", "diff size" });
    try writer.print("{s}\n", .{"-" ** 40 ++ "+" ++ "-" ** 26 ++ "+" ++ "-" ** 15 ++ "+" ++ "-" ** 15 ++ "+" ++ "-" ** 15 ++ "+" ++ "-" ** 9 ++ "+" ++ "-" ** 16 ++ "+" ++ "-" ** 10});
    for (results_arr) |result| {
        try writer.print(" {s: <38} | {d: >11.6}s", .{ result.name, result.mean });

        if (result.stddev > 5.0) {
            try tty_conf.setColor(writer, .red);
        } else {
            try tty_conf.setColor(writer, .green);
        }

        try writer.print(" +/- {d: >6.2}% ", .{result.stddev});
        try tty_conf.setColor(writer, .white);
        try writer.print("| {d: >12.6}s | {d: >12.6}s | {d: >12.6}s |", .{ result.min, result.max, result.median });

        if (result.diff_time == 0.0) {
            try tty_conf.setColor(writer, .yellow);
            try writer.print(" {s: ^7} ", .{"ref"});
        } else {
            if (result.diff_time > 0.0) {
                try tty_conf.setColor(writer, .red);
            }
            if (result.diff_time < 0.0) {
                try tty_conf.setColor(writer, .green);
            }
            try writer.print(" {d: >6.2}% ", .{result.diff_time});
        }
        try tty_conf.setColor(writer, .white);

        try writer.print("| {d: >13}B |", .{result.size});

        if (result.diff_size == 0.0) {
            try tty_conf.setColor(writer, .yellow);
            try writer.print(" {s: ^5} \n", .{"ref"});
        } else {
            if (result.diff_size > 0.0) {
                try tty_conf.setColor(writer, .red);
            }
            if (result.diff_size < 0.0) {
                try tty_conf.setColor(writer, .green);
            }
            try writer.print(" {d: >5.2}% \n", .{result.diff_size});
        }
        try tty_conf.setColor(writer, .white);
    }
}

/// Print the results in a csv file
pub fn print_csv(results_arr: []const Results, given_filename: ?[]const u8, generate_script: bool) !void {
    const dirname = "./benchy-output";
    var directory = try std.fs.cwd().makeOpenPath(dirname, std.fs.Dir.OpenDirOptions{});

    var tmp_csv: [128]u8 = undefined;
    const timestamp = std.time.microTimestamp();
    var filename_csv: []u8 = undefined;
    if (given_filename == null) {
        filename_csv = try std.fmt.bufPrint(@as([]u8, &tmp_csv), "{s}/benchy-{d}.csv", .{ dirname, timestamp });
    } else {
        filename_csv = try std.fmt.bufPrint(@as([]u8, &tmp_csv), "{s}/{s}", .{ dirname, given_filename.? });
    }
    var file = try std.fs.cwd().createFile(filename_csv, std.fs.File.CreateFlags{});
    var writer = file.writer();

    try writer.print("{s:^40};{s:^14};{s:^14};{s:^14};{s:^14};{s:^14};{s:^13};{s:^15};{s:^13};\n", .{ "name", "mean (s)", "stddev (s)", "min (s)", "max (s)", "median (s)", "diff time (%)", "size (B)", "diff size (%)" });
    for (results_arr) |result| {
        try writer.print(" {s: <38} ; {d: >12.6} ; {d: >12.6} ; {d: >12.6} ; {d: >12.6} ; {d: >12.6} ; {d: >11.3} ; {d: >13} ; {d: >11.3} ;\n", .{ result.name, result.mean, (result.stddev / 100.0) * result.mean, result.min, result.max, result.median, result.diff_time, result.size, result.diff_size });
    }

    file.close();

    if (generate_script) {
        var tmp_gp: [128]u8 = undefined;
        var filename_gp = try std.fmt.bufPrint(@as([]u8, &tmp_gp), "{s}/plot-{d}.gp", .{ dirname, timestamp });
        file = try std.fs.cwd().createFile(filename_gp, std.fs.File.CreateFlags{});
        writer = file.writer();

        try writer.print(
            \\set terminal png size 1920, 1280
            \\set output "./bency-output/benchy-plot-{d}.png"
            \\
            \\set grid y
            \\set auto x
            \\set xlabel "Program"
            \\set ylabel "Execution Time (s)"
            \\set yrange [0:]
            \\
            \\set style data histogram
            \\set style histogram errorbars gap 2 lw 1
            \\
            \\unset xtics
            \\set xtics rotate by -45 scale 0
            \\set datafile separator ";"
            \\
            \\set style fill solid 0.8 noborder 
            \\set errorbars linecolor black
            \\set bars front
            \\set key left top
            \\
            \\plot "{s}" u 2:3:xtic(1) notitle
        , .{ timestamp, filename_csv });

        file.close();
    }
    directory.close();
}
