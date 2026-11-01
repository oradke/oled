# OLED Status Display

A small Linux status display for a 128x32 SSD1306 OLED connected over I2C. It shows the device hostname and CPU temperature in the header, then cycles through the IPv4 addresses of active network interfaces. The final page remains on the OLED after the program exits.

The program is designed to run briefly from cron rather than stay running continuously. The installer schedules an update every five minutes, so the display refreshes regularly without leaving a Python process running between updates.

## Requirements

- A Linux single-board computer with Python 3 and I2C support.
- A 128x32 SSD1306 I2C OLED, wired to the board's I2C SDA/SCL pins and correct supply voltage.
- The OLED reachable on I2C bus `1` at address `0x3C` (the defaults in `oled_status.py`).
- An available `i2c` system group and permissions for the account that will run the job.
- `python3`, `python3-venv`, `pip`, `crontab`, `flock`, `getent`, `usermod`, and `sudo`/root access for installation. The installer also needs `runuser` if invoked through `sudo`.
- A cron daemon installed and running so the scheduled refreshes execute.
- The `ip` command and a readable `/sys/class/thermal/thermal_zone0/temp` file for the network and temperature readings.

The Python dependencies (`luma.oled` and `Pillow`) are listed in `requirements.txt` and installed into the project-local `.venv` by the installer.

## Install

Enable I2C for your board first, connect the OLED, and make sure the `i2c` group exists. From the project directory, run the installer as the account that should own the scheduled job:

```sh
sudo ./install.sh
```

The installer creates `.venv`, installs `requirements.txt`, adds the account to the `i2c` group, and adds a marked cron entry that runs `update_oled.sh` every five minutes. It preserves unrelated cron entries. Log out and back in (or reboot) for the new I2C group membership to take effect.

To trigger an update manually:

```sh
./update_oled.sh
```

## Uninstall

Run this as the same account used for installation:

```sh
sudo ./uninstall.sh
```

The uninstaller removes only this project's marked cron entry and keeps other cron jobs. It does not remove `.venv`, project files, or the user's `i2c` group membership; remove those separately if desired.

## Configuration

The display settings are at the top of `oled_status.py`:

- `I2C_PORT`: I2C bus number, default `1`.
- `I2C_ADDRESS`: OLED address, default `0x3C`.
- `PAGE_SECONDS`: how long each page is shown before advancing, default `3` seconds.
- `LINES_PER_PAGE`: number of network interfaces shown on each page, default `2`.

The display dimensions and controller are currently fixed to SSD1306 at 128x32. Other resolutions, controllers, I2C addresses, or host-specific thermal sensor paths require configuration or code changes. The temperature sensor is read from `/sys/class/thermal/thermal_zone0/temp`; on systems with a different sensor path, update `cpu_temp()` accordingly.
