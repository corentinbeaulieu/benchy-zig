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

pub const Results = struct {
    name: []const u8,
    mean: f64,
    min: f64,
    max: f64,
    stddev: f64,
    median: f64,
    diff: f64,
};

/// Measures the benchies and aggregate the results
pub fn run_benchies(allocator: Allocator, argv_list: []*ArrayList([]const u8), count: u16) ![]Results {
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
