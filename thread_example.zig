const std = @import("std");
const debug = std.debug;
const time = std.time;
const Thread = std.Thread;
const Mutex = std.Thread.Mutex;
//const RwLock = std.Thread.RwLock;

const Counter = struct {
    lock: Mutex = .{},
    // lock: RwLock = .{},
    count: u8 = 0,

    fn increment(self: *Counter) void {
        self.lock.lock();
        defer self.lock.unlock();

        const before = self.count;
        time.sleep(150 * time.ns_per_ms);
        self.count +%= 1;
        debug.print("write count: {} -> {}\n, ", .{ before, self.count });
    }

    fn print(self: *Counter) void {
        self.lock.lock();
        //self.lock.lockShared();
        defer self.lock.unlock();

        debug.print("read count: {}, ", .{self.count});
    }
};

fn incrementCounter(counter: *Counter) void {
    time.sleep(500 * time.ns_per_ms);
    counter.increment();
}

fn printCounter(counter: *Counter) void {
    time.sleep(250 * time.ns_per_ms);
    counter.print();
}

pub fn main() !void {
    var counter = Counter{};

    for (0..10) |_| {
        var thread = try std.Thread.spawn(.{}, incrementCounter, .{&counter});
        thread.detach();
    }
    for (0..100) |_| {
        var thread = try std.Thread.spawn(.{}, printCounter, .{&counter});
        thread.detach();
    }

    time.sleep(3 * time.ns_per_s);
    debug.print("\n", .{});
}
