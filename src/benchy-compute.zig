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
const testing = std.testing;

pub const Results = struct {
    name: []const u8,
    mean: f64,
    min: f64,
    max: f64,
    stddev: f64,
    median: f64,
    diff_time: f64,
};

const MeasuresInfo = struct {
    name: []const u8,
    argv: [][]const u8,
    nb_runs: u32,
    warmup: u8,
    cmd_output: bool,
};

pub const computeError = error{
    EmptyArray,
};

/// Measures the benchies and aggregate the results
pub fn run_benchies(
    allocator: Allocator,
    names: []const []const u8,
    argv_list: []*ArrayList([]const u8),
    count: u16,
    warmup: ?u8,
    cmd_output: bool,
) ![]Results {
    const rets = try allocator.alloc(Results, argv_list.len);
    var reference_time: f64 = 0.0;

    _ = try std.io.getStdOut().writer().write("\n");

    for (argv_list, rets, names) |argv, *ret, name| {
        const info = MeasuresInfo{
            .name = name,
            .argv = try argv.toOwnedSlice(),
            .nb_runs = count,
            .warmup = warmup orelse 0,
            .cmd_output = cmd_output,
        };

        const measures = try measure_executions(allocator, info);
        defer allocator.free(measures);

        ret.* = try aggregate_measures(measures, false, &reference_time);
    }

    return rets;
}

/// Run the programs and fill a slice with the measures
fn measure_executions(allocator: Allocator, info: MeasuresInfo) ![]f64 {
    var chrono = try std.time.Timer.start();
    const measures = try allocator.alloc(f64, info.nb_runs);
    @memset(measures, 0);
    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    try progressbar_update(stdout, info.name, 0.0);

    for (info.warmup, 1..) |_, completed| {
        const pid = try std.os.fork();
        if (pid == 0) {
            if (!info.cmd_output) {
                const null_out = try std.fs.openFileAbsolute("/dev/null", std.fs.File.OpenFlags{ .mode = .write_only });
                defer null_out.close();
                try std.os.dup2(null_out.handle, std.os.STDOUT_FILENO);
            }

            const exec_error = std.process.execv(allocator, info.argv);
            if (exec_error == std.os.ExecveError.FileNotFound) return exec_error;
            std.process.exit(0);
        } else {
            _ = std.os.waitpid(pid, 0);
            try progressbar_update(stdout, info.name, @as(f32, @floatFromInt(completed)) / @as(f32, @floatFromInt(info.nb_runs + info.warmup)) * 100.0);
        }
    }

    for (measures, 1..) |*measure, completed| {
        const pid = try std.os.fork();
        if (pid == 0) {
            if (!info.cmd_output) {
                const null_out = try std.fs.openFileAbsolute("/dev/null", std.fs.File.OpenFlags{ .mode = .write_only });
                defer null_out.close();
                try std.os.dup2(null_out.handle, std.os.STDOUT_FILENO);
            }

            const exec_error = std.process.execv(allocator, info.argv);
            if (exec_error == std.os.ExecveError.FileNotFound) return exec_error;
            std.process.exit(0);
        } else {
            chrono.reset();
            _ = std.os.waitpid(pid, 0);
            measure.* = @as(f64, @floatFromInt(chrono.read())) * 1e-9;
            try progressbar_update(stdout, info.name, @as(f32, @floatFromInt(completed + info.warmup)) / @as(f32, @floatFromInt(info.nb_runs + info.warmup)) * 100.0);
        }
    }

    try writer.print("\n", .{});
    return measures;
}

fn progressbar_update(file: std.fs.File, name: []const u8, accomplished: f32) !void {
    const writer = file.writer();
    const width = 100;
    const erase = "\u{8}" ** width;
    const tty_conf = std.io.tty.detectConfig(file);

    _ = try writer.write(erase);

    const nb_completed = @as(u8, @intFromFloat(40.0 * (accomplished / 100.0)));

    var completed_bar: [120]u8 = undefined;
    _ = try std.fmt.bufPrint(&completed_bar, "{s}", .{"━" ** 40});
    @memset(completed_bar[(nb_completed * 3)..], 0);

    var non_completed: [120]u8 = undefined;
    _ = try std.fmt.bufPrint(&non_completed, "{s}", .{"─" ** 40});
    @memset(non_completed[(120 - nb_completed * 3)..], 0);

    try writer.print(" {s:<40}{s}", .{ name, " " ** 11 });

    try tty_conf.setColor(writer, .green);
    try writer.print("{s}", .{completed_bar});
    try tty_conf.setColor(writer, .reset);

    try writer.print("{s} {d:>6.2}%", .{ non_completed, accomplished });
}

/// Performs stastistical analysis on a slice of measures
fn aggregate_measures(measures: []f64, doSize: bool, reference_time: *f64) !Results {
    _ = doSize;

    std.sort.heap(f64, measures, {}, std.sort.asc(f64));
    const mean = try compute_mean(measures);

    if (reference_time.* == 0.0) {
        reference_time.* = mean;
        // reference_size = size;
    }

    return Results{
        .name = undefined,
        .mean = mean,
        .min = measures[0],
        .max = measures[measures.len - 1],
        .stddev = try compute_stddev(measures, mean),
        .median = try compute_median(measures, true),
        .diff_time = ((mean - reference_time.*) / reference_time.*) * 100,
    };
}

/// Compute the mean of the values in a vector
fn compute_mean(vec: []const f64) computeError!f64 {
    if (vec.len == 0) return computeError.EmptyArray;

    var sum: f64 = 0.0;

    for (vec) |elem| {
        sum += elem;
    }

    return sum / @as(f64, @floatFromInt(vec.len));
}

test compute_mean {
    const vec1: [1]f64 = .{1.0};
    const mean1 = try compute_mean(&vec1);
    try testing.expectEqual(mean1, 1.0);

    const vec2: [2]f64 = .{ -1.0, 1.0 };
    const mean2 = try compute_mean(&vec2);
    try testing.expectEqual(mean2, 0.0);

    const vec3: [0]f64 = .{};
    try testing.expectError(computeError.EmptyArray, compute_mean(&vec3));

    const vec4: [513]f64 = std.simd.iota(f64, 513);
    const mean4 = try compute_mean(&vec4);
    try testing.expectEqual(mean4, 256.0);
}

/// Compute the standard deviation of the values in a vector
fn compute_stddev(vec: []const f64, mean: f64) computeError!f64 {
    if (vec.len == 0) return computeError.EmptyArray;

    var sum: f64 = 0.0;

    for (vec) |elem| {
        const tmp: f64 = elem - mean;
        sum += tmp * tmp;
    }

    return ((@sqrt(sum / @as(f64, @floatFromInt(vec.len)))) / mean) * 100;
}

test compute_stddev {
    const vec1: [1]f64 = .{1.0};
    const stddev1 = try compute_stddev(&vec1, vec1[0]);
    try testing.expectEqual(stddev1, 0.0);

    const vec3: [0]f64 = .{};
    const mean3: f64 = 0.0;
    try testing.expectError(computeError.EmptyArray, compute_stddev(&vec3, mean3));
}

/// Compute the median of the values in a vector
fn compute_median(vec: []f64, is_sorted: bool) computeError!f64 {
    if (vec.len == 0) return computeError.EmptyArray;

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

test compute_median {
    var vec1: [1]f64 = .{1.0};
    const median1 = try compute_median(&vec1, true);
    try testing.expectEqual(median1, 1.0);

    var vec2: [2]f64 = .{ -1.0, 1.0 };
    const median2 = try compute_median(&vec2, true);
    try testing.expectEqual(median2, 0.0);

    var vec3: [0]f64 = .{};
    try testing.expectError(computeError.EmptyArray, compute_median(&vec3, true));

    var vec4: [513]f64 = std.simd.iota(f64, 513);
    const median4 = try compute_median(&vec4, true);
    try testing.expectEqual(median4, 256.0);

    var vec5: [5]f64 = .{ 2.0, 2.0, 5.0, 5.0, 5.0 };
    const median5 = try compute_median(&vec5, true);
    try testing.expectEqual(median5, 5.0);

    var vec6: [5]f64 = .{ 1.0, 3.0, 12.0, 1.0, 3.0 };
    const median6 = try compute_median(&vec6, false);
    try testing.expectEqual(median6, 3.0);
}
