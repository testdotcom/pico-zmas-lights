const std = @import("std");
const microzig = @import("microzig");

const rp2xxx = microzig.hal;
const gpio = rp2xxx.gpio;
const Pio = rp2xxx.pio.Pio;
const StateMachine = rp2xxx.pio.StateMachine;

const ws2812_program = blk: {
    @setEvalBranchQuota(10_000);
    break :blk rp2xxx.pio.assemble(
        \\;
        \\; Copyright (c) 2020 Raspberry Pi (Trading) Ltd.
        \\;
        \\; SPDX-License-Identifier: BSD-3-Clause
        \\;
        \\.program ws2812
        \\.side_set 1
        \\
        \\.define public T1 2
        \\.define public T2 5
        \\.define public T3 3
        \\
        \\.wrap_target
        \\bitloop:
        \\    out x, 1       side 0 [T3 - 1] ; Side-set still takes place when instruction stalls
        \\    jmp !x do_zero side 1 [T1 - 1] ; Branch on the bit we shifted out. Positive pulse
        \\do_one:
        \\    jmp  bitloop   side 1 [T2 - 1] ; Continue driving high, for a long pulse
        \\do_zero:
        \\    nop            side 0 [T2 - 1] ; Or drive low, for a short pulse
        \\.wrap
    , .{}).get_program_by_name("ws2812");
};

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

const RED   = Color{ .r = 255, .g = 0,   .b = 0 };
const BLUE  = Color{ .r = 0,   .g = 0,   .b = 255 };
const GREEN = Color{ .r = 0,   .g = 255, .b = 0 };
const GOLD  = Color{ .r = 255, .g = 215, .b = 0 };

const NUM_LEDS = 20;
const CHRISTMAS_PATTERN = [_]Color{ RED, BLUE, GREEN, GOLD };

// Encode Color to the u32 format expected by the PIO (GRB << 8)
fn encode_pixel(color: Color, brightness: u8) u32 {
    // Apply brightness scaling (0-255)
    // Cast to before multiply to avoid overflow.
    const r = (@as(u32, color.r) * brightness) / 255;
    const g = (@as(u32, color.g) * brightness) / 255;
    const b = (@as(u32, color.b) * brightness) / 255;

    // Pack into 32-bit integer for PIO left-shift output
    // Standard WS2812 order is GRB
    // The PIO shifts left, so we place data in the top 24 bits:
    // [GGGGGGGG RRRRRRRR BBBBBBBB 00000000].
    return (g << 24) | (r << 16) | (b << 8);
}

pub fn main() !void {
    const pio: Pio = rp2xxx.pio.num(0);
    const sm: StateMachine = .sm0;
    const led_pin = gpio.num(14);

    pio.gpio_init(led_pin);
    pio.sm_set_pindir(sm, @intCast(@intFromEnum(led_pin)), 1, .out);

    const cycles_per_bit: comptime_int = ws2812_program.defines[0].value + //T1
        ws2812_program.defines[1].value + //T2
        ws2812_program.defines[2].value; //T3
    const div = @as(f32, @floatFromInt(rp2xxx.clock_config.sys.?.frequency())) /
        (800_000 * cycles_per_bit);

    pio.sm_load_and_start_program(sm, ws2812_program, .{
        .clkdiv = rp2xxx.pio.ClkDivOptions.from_float(div),
        .pin_mappings = .{
            .side_set = .{
                .base = @intCast(@intFromEnum(led_pin)),
                .count = 1,
            },
        },
        .shift = .{
            .out_shiftdir = .left,
            .autopull = true,
            .pull_threshold = 24,
            .join_tx = true,
        },
    }) catch unreachable;
    pio.sm_set_enabled(sm, true);

    // Breathing animation
    var brightness: i32 = 0;    // Start dim
    var delta: i32 = 1;         // Fade direction
    const min_bright = 0;
    const max_bright = 150;

    while (true) {
        brightness += delta;
        if (brightness >= max_bright) {
            delta = -1;
            brightness = max_bright;
        } else if (brightness <= min_bright) {
            delta = 1;
            brightness = min_bright;
        }

        var i: usize = 0;
        while (i < NUM_LEDS) : (i += 1) {
            // Select color based on position in pattern.
            const base_color = CHRISTMAS_PATTERN[i % CHRISTMAS_PATTERN.len];
            const pixel_data = encode_pixel(base_color, @intCast(brightness));
            pio.sm_blocking_write(sm, pixel_data);
        }

        // This is the reset time (>50us) for the strip 
        // and controls the animation speed.
        rp2xxx.time.sleep_ms(20);   // 50fps
    }
}
