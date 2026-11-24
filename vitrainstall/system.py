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


# ---------------------------------------------------------------- Wi-Fi (iwd, like on the Arch ISO)
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
WIFI_LINE = re.compile(r"^\s*(?P<cur>>)?\s*(?P<ssid>.+?)\s{2,}(?P<sec>psk|open|8021x|wep|sae|owe)\s+(?P<rssi>-?\d+)\s*$")


def wifi_device() -> str:
    """First wireless interface (wlan0, wlp2s0 ...), '' when there is none."""
    try:
        for name in sorted(os.listdir("/sys/class/net")):
            if os.path.isdir(f"/sys/class/net/{name}/wireless"):
                return name
    except OSError:
        pass
    return ""


def parse_networks(text: str) -> list[dict]:
    """Parse `iwctl station <dev> get-networks rssi-dbms` (signal in 1/100 dBm)."""
    nets: dict[str, dict] = {}
    for raw in text.splitlines():
        line = ANSI.sub("", raw)
        m = WIFI_LINE.match(line)
        if not m:
            continue
        ssid = m.group("ssid").strip()
        if not ssid or ssid.lower() == "network name":
            continue
        dbm = int(m.group("rssi")) / 100
        # -50 dBm and better = full, -90 = nothing
        bars = max(0, min(4, int((dbm + 90) / 10)))
        net = {"ssid": ssid, "security": m.group("sec"), "secure": m.group("sec") != "open",
               "signal": bars, "connected": bool(m.group("cur"))}
        if ssid not in nets or net["signal"] > nets[ssid]["signal"]:
            nets[ssid] = net
    return sorted(nets.values(), key=lambda n: (not n["connected"], -n["signal"], n["ssid"].lower()))


def wifi_scan(dev: str) -> list[dict]:
    import time

    if not dev:
        return []
    _run(["iwctl", "station", dev, "scan"], timeout=10)
    time.sleep(3)  # the scan runs in the background
    return parse_networks(_run(["iwctl", "station", dev, "get-networks", "rssi-dbms"], timeout=10))


def wifi_connect(dev: str, ssid: str, password: str) -> str:
    """'' when connected and online, else a short error key."""
    import time

    if not dev or not ssid:
        return "wifi_failed"
    cmd = ["iwctl"]
    if password:
        cmd += ["--passphrase", password]
    cmd += ["station", dev, "connect", ssid]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=30, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return "wifi_failed"
    out = ANSI.sub("", (r.stdout or "") + (r.stderr or "")).lower()
    if r.returncode != 0:
        if "passphrase" in out or "invalid" in out or "authentication" in out or "operation failed" in out:
            return "wifi_wrong_password"
        return "wifi_failed"
    # iwd is connected; give DHCP (systemd-networkd on the ISO) a moment
    for _ in range(15):
        if has_internet():
            return ""
        time.sleep(1)
    return "wifi_no_internet"


def nm_wifi_profile(ssid: str, password: str) -> str:
    """NetworkManager keyfile, so the installed system is online on first boot."""
    lines = ["[connection]", f"id={ssid}", "type=wifi", "", "[wifi]", "mode=infrastructure", f"ssid={ssid}", ""]
    if password:
        lines += ["[wifi-security]", "key-mgmt=wpa-psk", f"psk={password}", ""]
    lines += ["[ipv4]", "method=auto", "", "[ipv6]", "method=auto", ""]
    return "\n".join(lines)


# ---------------------------------------------------------------- mirrors
def country_for_timezone(tz: str) -> str:
    """Europe/Vienna -> AT, from the tzdata tables ('' when unknown)."""
    for table in ("/usr/share/zoneinfo/zone1970.tab", "/usr/share/zoneinfo/zone.tab"):
        try:
            with open(table) as f:
                for line in f:
                    if line.startswith("#"):
                        continue
                    parts = line.rstrip("\n").split("\t")
                    if len(parts) >= 3 and parts[2] == tz:
                        return parts[0].split(",")[0]
        except OSError:
            continue
    return ""


def reflector_command(tz: str, save_to: str = "/etc/pacman.d/mirrorlist") -> list[str]:
    """Fast HTTPS mirrors near the user (plus big neighbours as backup)."""
    countries = []
    for cc in (country_for_timezone(tz), "DE", "NL", "FR", "SE", "US"):
        if cc and cc not in countries:
            countries.append(cc)
    return ["reflector", "--protocol", "https", "--age", "24", "--latest", "25", "--fastest", "12",
            "--sort", "rate", "--download-timeout", "4", "--country", ",".join(countries), "--save", save_to]


# ---------------------------------------------------------------- after a failed install
DOWNLOAD_ERRORS = ("failed retrieving file", "operation too slow", "could not resolve host",
                   "failed to retrieve some files", "connection timed out", "download timed out")


def log_tail(paths: list[str], lines: int = 14) -> str:
    """Last lines of the most recently written log, without Python traceback noise."""
    best = ""
    newest = -1.0
    for p in paths:
        try:
            st = os.stat(p)
        except OSError:
            continue
        if st.st_mtime > newest and st.st_size > 0:
            newest, best = st.st_mtime, p
    if not best:
        return ""
    with open(best, errors="replace") as f:
        text = ANSI.sub("", f.read()[-20000:])
    keep = [l for l in text.splitlines() if l.strip() and not l.lstrip().startswith(("File \"", "^", "~"))]
    return "\n".join(keep[-lines:])


def classify_failure(text: str) -> str:
    low = text.lower()
    if any(e in low for e in DOWNLOAD_ERRORS):
        return "download"
    if "unable to satisfy dependency" in low or "target not found" in low:
        return "packages"
    return "install_failed"
