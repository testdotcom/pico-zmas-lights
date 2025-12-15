# README

Drive a NeoPixel strip of leds with the RPi Pico 2040.

## Hardware requirements

For the following project we assume a **ItsyBitsy 2040** board and a compatible **ws2812** strip of leds.

- (**recommended**) A 500-1k µF capacitor across Volt and Ground terminals, to buffer sudden changes in the current drawn by the strip
- (**recommended**) A 300-500 Ohm resistor on the Data line, to prevent voltage spikes

Warning: The source code declares a *20 leds strip*. Be sure to change the `NUM_LEDS` constant before compiling.

## Connections schema

The ws2812 IC is compatible with 5V *OR* 3.3V current, always refer to the provided documentation. For this project, we use a 5V NeoPixel strip, and the pin connections are:

- `G` (Ground)
- `USB` (VBUS) as Data output
- `D5` (GPIO14) to draw 5V directly from the USB

## Troubleshooting

- The The Pico 2040 has GPIO pins of `u5` size, while the microzig library allows for boards with more pins (Pico 2050 models). Thus, a `@intCast` is required when dealing with GPIO pins

## Resources

- https://ziglang.org/learn
- https://microzig.tech/docs/getting-started
- https://learn.adafruit.com/adafruit-neopixel-uberguide/best-practices
