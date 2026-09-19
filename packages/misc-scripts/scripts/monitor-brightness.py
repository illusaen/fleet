#!/usr/bin/env python3
import re
import subprocess
import sys

MIN_BRIGHTNESS = 10
MAX_BRIGHTNESS = 50
INPUTS = {
    "down": "-",
    "up": "+",
    "status": "status",
}


def find_lg_bus():
    result = subprocess.run(
        ["ddcutil", "detect"], capture_output=True, text=True, check=True
    )
    bus = None
    for line in result.stdout.splitlines():
        m = re.search(r"/dev/i2c-(\d+)", line)
        if m:
            bus = m.group(1)
        if "mfg id" in line.lower() and "gsm" in line.lower():
            return bus
    sys.exit("Error: no LG monitor detected")


def find_current_brightness(bus):
    result = subprocess.run(
        ["ddcutil", "getvcp", "10", "-b", str(bus)],
        capture_output=True,
        text=True,
        check=True,
    )
    # VCP code 0x10 (Brightness                    ): current value =    40, max value =   100
    for line in result.stdout.splitlines():
        m = re.search(r"current value = \s*(\d+),", line)
        if m:
            try:
                return int(m.group(1))
            except ValueError:
                sys.exit(f"Could not parse {m.group(1)} into an integer.")
    sys.exit("Error: failed to parse current brightness value")


def setCommand(bus, cmd):
    result = subprocess.run(
        ["ddcutil", "setvcp", "10", cmd, "5", "-b", str(bus)], check=True
    )
    if result.returncode == 0:
        print(find_current_brightness(bus))


def send(bus, cmd):
    if cmd == "status":
        return print(find_current_brightness(bus))

    current = find_current_brightness(bus)
    if (cmd == "-" and current >= MIN_BRIGHTNESS + 5) or (
        cmd == "+" and current <= MAX_BRIGHTNESS - 5
    ):
        return setCommand(bus, cmd)
    sys.exit(
        f"Could not {'increase' if cmd == '+' else 'decrease'} brightness, already at {current}."
    )


if len(sys.argv) != 2 or sys.argv[1] not in INPUTS:
    print(f"Usage: {sys.argv[0]} [{' | '.join(INPUTS)}]")
    sys.exit(1)

send(find_lg_bus(), INPUTS[sys.argv[1]])
