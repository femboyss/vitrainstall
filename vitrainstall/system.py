# vitrainstall: reads what the machine has (disks, layouts, timezones, GPU)
# (c) 2026 34 & Claude - GPL-3.0-or-later

from __future__ import annotations

import json
import os
import re
import subprocess
import urllib.request
import zoneinfo

# shown when localectl is not available (e.g. tests); the most common ones
FALLBACK_LAYOUTS = ["us", "de", "at", "ch", "gb", "fr", "es", "it", "nl", "pl", "se", "no", "dk", "fi", "pt", "br", "ru", "jp", "tr", "cz"]


def _run(cmd: list[str], timeout: int = 10) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=False).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def live_medium() -> str:
    """The disk the live ISO runs from: never offered as install target."""
    try:
        with open("/proc/mounts") as f:
            for line in f:
                dev, mnt = line.split()[:2]
                if mnt in ("/run/archiso/bootmnt", "/run/archiso/img_dev"):
                    return re.sub(r"p?\d+$", "", dev) if not dev.startswith("/dev/loop") else ""
    except OSError:
        pass
    return ""


def disks() -> list[dict]:
    """Disks you can install to: no loop/zram/cdrom, not read-only, not the live USB."""
    out = _run(["lsblk", "-J", "-b", "-d", "-o", "NAME,PATH,SIZE,MODEL,TYPE,RM,RO,TRAN,LOG-SEC"])
    try:
        devices = json.loads(out).get("blockdevices", [])
    except json.JSONDecodeError:
        return []
    skip = live_medium()
    result = []
    for d in devices:
        if d.get("type") != "disk" or d.get("ro") in (True, "1", 1):
            continue
        path = d.get("path") or f"/dev/{d.get('name')}"
        if path == skip or re.match(r"/dev/(zram|loop|sr)", path):
            continue
        size = int(d.get("size") or 0)
        if size <= 0:
            continue
        result.append(
            {
                "path": path,
                "model": (d.get("model") or "").strip() or ("NVMe SSD" if (d.get("tran") or "") == "nvme" else "Disk"),
                "size": size,
                "sizeText": human_size(size),
                "transport": (d.get("tran") or "").upper(),
                "removable": d.get("rm") in (True, "1", 1),
                "sectorSize": int(d.get("log-sec") or 512),
            }
        )
    return result


def human_size(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1000 or unit == "TB":
            return f"{n:.0f} {unit}" if unit in ("B", "KB") else f"{n:.1f} {unit}"
        n /= 1000
    return str(n)


def keyboard_layouts() -> list[str]:
    out = _run(["localectl", "list-x11-keymap-layouts"])
    layouts = [line.strip() for line in out.splitlines() if line.strip()]
    return layouts or FALLBACK_LAYOUTS


def timezones() -> list[str]:
    zones = sorted(z for z in zoneinfo.available_timezones() if "/" in z and not z.startswith(("Etc/", "SystemV/", "posix/", "right/")))
    return zones or ["UTC"]


def guess_timezone() -> str:
    """Best guess for the timezone: online lookup (2 s), else what the live system says."""
    try:
        with urllib.request.urlopen("https://ipapi.co/timezone", timeout=2) as r:
            tz = r.read().decode().strip()
            if tz in zoneinfo.available_timezones():
                return tz
    except Exception:  # noqa: BLE001 - offline is fine
        pass
    link = os.path.realpath("/etc/localtime")
    if "zoneinfo/" in link:
        return link.split("zoneinfo/", 1)[1]
    return "UTC"


def guess_gfx_driver() -> str:
    """Pick archinstall's graphics driver option from lspci."""
    out = _run(["lspci", "-nn"]).lower()
    vga = "\n".join(line for line in out.splitlines() if re.search(r"vga|3d controller|display controller", line))
    if "nvidia" in vga:
        return "Nvidia (open kernel module for newer GPUs, Turing+)"
    if "virtualbox" in vga or "vmware" in vga:
        return "VirtualBox (open-source)"
    if "amd" in vga or "ati " in vga or "radeon" in vga:
        return "AMD / ATI (open-source)"
    if "intel" in vga:
        return "Intel (open-source)"
    return "All open-source"


def has_internet() -> bool:
    try:
        urllib.request.urlopen("https://archlinux.org", timeout=4)
        return True
    except Exception:  # noqa: BLE001
        return False


def is_uefi() -> bool:
    return os.path.isdir("/sys/firmware/efi")
