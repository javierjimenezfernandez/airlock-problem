const std = @import("std");
const debug = std.debug;
const time = std.time;
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const Condition = Thread.Condition;

const Chamber = enum { pressurized, depressurized, changing };

const Airlock = struct {
    mutex: Mutex = .{},
    cond: Condition = .{},
    outside_door: bool = false,
    inside_door: bool = false,
    chamber: Chamber = .pressurized,

    /// ISS -> EVA: waits for pressurized chamber, depressurizes, exits
    fn exit(self: *Airlock, pressurize_duration_ms: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Rule: inside door only opens when chamber is pressurized and outside door is closed
        while (self.chamber != .pressurized or self.outside_door) {
            debug.print("[exit]  waiting — chamber={s}\n", .{@tagName(self.chamber)});
            self.cond.wait(&self.mutex);
        }
        self.inside_door = true;
        debug.print("[exit]  inside door OPEN\n", .{});
        self.inside_door = false;
        debug.print("[exit]  inside door CLOSED\n", .{});
        debug.print("[exit]  astronaut inside chamber\n", .{});

        // Rule: (de-)pressurize only when both doors are closed
        self.chamber = .changing;
        debug.print("[exit]  chamber DEPRESSURIZING...\n", .{});
        self.mutex.unlock();
        time.sleep(pressurize_duration_ms * time.ns_per_ms);
        self.mutex.lock();
        self.chamber = .depressurized;
        debug.print("[exit]  chamber DEPRESSURIZED\n", .{});
        self.cond.broadcast();

        // Rule: outside door only opens when chamber is depressurized
        self.outside_door = true;
        debug.print("[exit]  outside door OPEN — astronaut in EVA\n", .{});
        self.outside_door = false;
        debug.print("[exit]  outside door CLOSED\n", .{});
        self.cond.broadcast();
    }

    /// EVA -> ISS: waits for depressurized chamber, pressurizes, enters
    fn enter(self: *Airlock, pressurize_duration_ms: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Rule: outside door only opens when chamber is depressurized and inside door is closed
        while (self.chamber != .depressurized or self.inside_door) {
            debug.print("[enter] waiting — chamber={s}\n", .{@tagName(self.chamber)});
            self.cond.wait(&self.mutex);
        }
        self.outside_door = true;
        debug.print("[enter] outside door OPEN\n", .{});
        self.outside_door = false;
        debug.print("[enter] outside door CLOSED\n", .{});
        debug.print("[enter] astronaut inside chamber\n", .{});

        // Rule: (de-)pressurize only when both doors are closed
        self.chamber = .changing;
        debug.print("[enter] chamber PRESSURIZING...\n", .{});
        self.mutex.unlock();
        time.sleep(pressurize_duration_ms * time.ns_per_ms);
        self.mutex.lock();
        self.chamber = .pressurized;
        debug.print("[enter] chamber PRESSURIZED\n", .{});
        self.cond.broadcast();

        // Rule: inside door only opens when chamber is pressurized
        self.inside_door = true;
        debug.print("[enter] inside door OPEN — astronaut inside ISS\n", .{});
        self.inside_door = false;
        debug.print("[enter] inside door CLOSED\n", .{});
        self.cond.broadcast();
    }
};

const AstronautArgs = struct {
    airlock: *Airlock,
    eva_duration_ms: u64,
    pressurize_duration_ms: u64,
    cycles: u32,
};

// Astronaut A: starts inside ISS, each cycle crosses the airlock once (exit then enter alternating)
fn astronautA(args: *AstronautArgs) void {
    var inside = true;
    for (0..args.cycles) |_| {
        time.sleep(args.eva_duration_ms * time.ns_per_ms);
        if (inside) {
            debug.print("[astronaut A] wants to EXIT to EVA\n", .{});
            args.airlock.exit(args.pressurize_duration_ms);
            debug.print("[astronaut A] now in EVA\n", .{});
        } else {
            debug.print("[astronaut A] wants to ENTER from EVA\n", .{});
            args.airlock.enter(args.pressurize_duration_ms);
            debug.print("[astronaut A] now inside ISS\n", .{});
        }
        inside = !inside;
    }
}

// Astronaut B: starts in EVA, each cycle crosses the airlock once (enter then exit alternating)
fn astronautB(args: *AstronautArgs) void {
    var inside = false;
    for (0..args.cycles) |_| {
        time.sleep(args.eva_duration_ms * time.ns_per_ms);
        if (inside) {
            debug.print("[astronaut B] wants to EXIT to EVA\n", .{});
            args.airlock.exit(args.pressurize_duration_ms);
            debug.print("[astronaut B] now in EVA\n", .{});
        } else {
            debug.print("[astronaut B] wants to ENTER from EVA\n", .{});
            args.airlock.enter(args.pressurize_duration_ms);
            debug.print("[astronaut B] now inside ISS\n", .{});
        }
        inside = !inside;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const raw_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, raw_args);

    var cycles: u32 = 3;
    var eva_duration_ms: u64 = 200;
    var pressurize_duration_ms: u64 = 300;

    var i: usize = 1;
    while (i < raw_args.len) : (i += 1) {
        if (std.mem.eql(u8, raw_args[i], "--cycles") and i + 1 < raw_args.len) {
            i += 1;
            cycles = try std.fmt.parseInt(u32, raw_args[i], 10);
        } else if (std.mem.eql(u8, raw_args[i], "--eva-duration") and i + 1 < raw_args.len) {
            i += 1;
            eva_duration_ms = try std.fmt.parseInt(u64, raw_args[i], 10);
        } else if (std.mem.eql(u8, raw_args[i], "--pressurize-duration") and i + 1 < raw_args.len) {
            i += 1;
            pressurize_duration_ms = try std.fmt.parseInt(u64, raw_args[i], 10);
        }
    }

    var airlock = Airlock{};
    var thread_args = AstronautArgs{
        .airlock = &airlock,
        .eva_duration_ms = eva_duration_ms,
        .pressurize_duration_ms = pressurize_duration_ms,
        .cycles = cycles,
    };

    const ta = try Thread.spawn(.{}, astronautA, .{&thread_args});
    const tb = try Thread.spawn(.{}, astronautB, .{&thread_args});

    ta.join();
    tb.join();

    debug.print("\nAll cycles complete.\n", .{});
}
