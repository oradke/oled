#!/usr/bin/env python3
"""Show hostname, CPU temp and active interface IPs on a 128x32 SSD1306 OLED."""
import socket
import subprocess
import time

from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1306
from PIL import ImageFont

I2C_PORT = 1
I2C_ADDRESS = 0x3C
PAGE_SECONDS = 3
LINES_PER_PAGE = 2  # line 0 is the header (hostname + temp)


def cpu_temp():
    with open("/sys/class/thermal/thermal_zone0/temp") as f:
        return int(f.read()) / 1000.0


def active_interfaces():
    """Return [(ifname, ipv4)] for interfaces that are up, excluding loopback."""
    out = subprocess.run(
        ["ip", "-4", "-o", "addr", "show", "up", "scope", "global"],
        capture_output=True, text=True,
    ).stdout
    result = []
    for line in out.splitlines():
        parts = line.split()
        result.append((parts[1], parts[3].split("/")[0]))
    return result


def main():
    device = ssd1306(i2c(port=I2C_PORT, address=I2C_ADDRESS), width=128, height=32)
    device.persist = True
    font = ImageFont.load_default()
    hostname = socket.gethostname()[:14]
    temperature = f"{cpu_temp():.1f}C"
    ifaces = active_interfaces() or [("no", "network")]
    pages = [ifaces[i:i + LINES_PER_PAGE] for i in range(0, len(ifaces), LINES_PER_PAGE)]

    for page_index, page in enumerate(pages):
        with canvas(device) as draw:
            draw.text((0, 0), hostname, font=font, fill="white")
            draw.text((128, 0), temperature, font=font, fill="white", anchor="rt")
            for row, (name, ip) in enumerate(page, start=1):
                draw.text((0, row * 11), name[:5], font=font, fill="white")
                draw.text((128, row * 11), ip, font=font, fill="white", anchor="rt")
        if page_index < len(pages) - 1:
            time.sleep(PAGE_SECONDS)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
