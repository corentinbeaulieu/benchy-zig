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
    size: u64,
    diff_size: f64,
};

pub const computeError = error{
    EmptyArray,
};

/// Measures the benchies and aggregate the results
pub fn run_benchies(allocator: Allocator, argv_list: []*ArrayList([]const u8), count: u16) ![]Results {
    const rets = try allocator.alloc(Results, argv_list.len);
    var reference_time: f64 = 0.0;

    for (argv_list, rets) |argv, *ret| {
        const argv_owned = try argv.toOwnedSlice();
        defer allocator.free(argv_owned);

        const measures = try measure_executions(allocator, argv_owned, count);

        ret.* = try aggregate_measures(measures, false, &reference_time);
    }

    return rets;
}

/// Run the programs and fill a slice with the measures
fn measure_executions(allocator: Allocator, argv: [][]const u8, nb_runs: u32) ![]f64 {
    var begin: std.os.timespec = undefined;
    var end: std.os.timespec = undefined;
    const measures = try allocator.alloc(f64, nb_runs);
    @memset(measures, 0);

    for (measures) |*measure| {
        const pid = try std.os.fork();
        if (pid == 0) {
            const exec_error = std.process.execv(allocator, argv);
            if (exec_error == std.os.ExecveError.FileNotFound) return exec_error;
            std.process.exit(0);
        } else {
            try std.os.clock_gettime(0, &begin);
            _ = std.os.waitpid(pid, 0);
            try std.os.clock_gettime(0, &end);

            measure.* = @as(f64, @floatFromInt(end.tv_sec - begin.tv_sec)) + (@as(f64, @floatFromInt(end.tv_nsec - begin.tv_nsec)) * 1e-9);
        }
    }
    return measures;
}

/// Performs stastistical analysis on a slice of measures
fn aggregate_measures(measures: []f64, doSize: bool, reference_time: *f64) !Results {
    _ = doSize;

    std.sort.heap(f64, measures, {}, std.sort.asc(f64));
    const mean = try compute_mean(measures);

    // var reference_size: u64 = undefined;
    // if(dosize) {
    // const file = try std.fs.cwd().openFile(argv_owned[0], .{});
    // const size = (try file.stat()).size;
    // file.close();
    // }

    if (reference_time.* == 0.0) {
        reference_time.* = mean;
        // reference_size = size;
    }

    return Results{
        .name = undefined,
        .mean = mean,
        .min = measures[0],
        .max = measures[measures.len - 1],
        .stddev = compute_stddev(measures, mean),
        .median = compute_median(measures, true),
        .diff_time = ((mean - reference_time.*) / reference_time.*) * 100,
        .size = 0,
        .diff_size = 0, // (@as(f64, @floatFromInt(size - reference_size)) / @as(f64, @floatFromInt(reference_size))) * 100,
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

test compute_median {}
