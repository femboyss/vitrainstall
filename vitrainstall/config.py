# vitrainstall: builds the archinstall configuration from the installer choices
# (c) 2026 34 & Claude - GPL-3.0-or-later
#
# Pure functions, no Qt and no root needed, so they are easy to test.
# The format follows archinstall 4.5 (examples/config-sample.json).

from __future__ import annotations

import shlex
import uuid
from dataclasses import dataclass, field

VITRA_REPO = {
    "name": "vitra",
    "url": "https://github.com/femboyss/vitra-repo/releases/download/$arch",
    "sign_check": "Optional",
    "sign_option": "TrustAll",
}

# what every Vitra system gets on top of archinstall's Hyprland profile
VITRA_PACKAGES = [
    "vtx",
    "cmaal",
    "glassy-shell",
    "glassy-wallpapers",
    "networkmanager",
    "bluez",
    "bluez-utils",
    "pipewire",
    "pipewire-pulse",
    "wireplumber",
    "firefox",
    "git",
    "base-devel",
    "sudo",
]

PLATFORMS = ("linux", "windows", "mac")
FILESYSTEMS = ("btrfs", "ext4")
GFX_DRIVERS = (
    "All open-source",
    "AMD / ATI (open-source)",
    "Intel (open-source)",
    "Nvidia (open kernel module for newer GPUs, Turing+)",
    "Nvidia (open-source nouveau driver)",
    "VirtualBox (open-source)",
)

MIB = 1024 * 1024


@dataclass
class Choices:
    """Everything the user picks in the installer."""

    language: str = "en"  # en | de  (installer + system language)
    platform: str = "linux"  # linux | windows | mac
    keyboard: str = "us"  # X11 / console layout
    timezone: str = "UTC"
    disk: str = ""  # /dev/sdX or /dev/nvme0n1
    disk_size: int = 0  # bytes
    sector_size: int = 512
    filesystem: str = "btrfs"
    hostname: str = "vitra"
    fullname: str = ""
    username: str = ""
    password: str = ""
    gfx_driver: str = "All open-source"
    uefi: bool = True  # False: old BIOS machine -> GRUB, no ESP flag
    extra_packages: list[str] = field(default_factory=list)


class ChoiceError(ValueError):
    """A choice is missing or invalid (message is shown to the user)."""


USERNAME_OK = set("abcdefghijklmnopqrstuvwxyz0123456789_-")


def validate(c: Choices) -> None:
    if c.platform not in PLATFORMS:
        raise ChoiceError("platform")
    if c.filesystem not in FILESYSTEMS:
        raise ChoiceError("filesystem")
    if not c.disk.startswith("/dev/"):
        raise ChoiceError("disk")
    if c.disk_size < 20 * 1024 * MIB:
        raise ChoiceError("disk_small")
    if not c.username or c.username[0] in "-0123456789" or not set(c.username) <= USERNAME_OK or len(c.username) > 32:
        raise ChoiceError("username")
    if c.username == "root":
        raise ChoiceError("username")
    if len(c.password) < 1:
        raise ChoiceError("password")
    if not c.hostname or not all(ch.isalnum() or ch == "-" for ch in c.hostname) or c.hostname.startswith("-"):
        raise ChoiceError("hostname")
    if c.gfx_driver not in GFX_DRIVERS:
        raise ChoiceError("gfx")


def _size(value: int, unit: str, sector_size: int) -> dict:
    return {
        "sector_size": {"unit": "B", "value": sector_size},
        "unit": unit,
        "value": value,
    }


def disk_layout(c: Choices) -> dict:
    """Wipe the whole disk: GPT, 1 GiB EFI /boot, rest is / (btrfs with subvolumes or ext4).

    Same layout archinstall itself suggests (default_layouts.py).
    """
    total_mib = c.disk_size // MIB
    boot_start, boot_size = 1, 1024
    root_start = boot_start + boot_size
    # leave 1 MiB at the end for the backup GPT and alignment
    root_size = total_mib - root_start - 1

    boot = {
        "btrfs": [],
        "dev_path": None,
        "flags": ["boot", "esp"] if c.uefi else ["boot"],
        "fs_type": "fat32",
        "mount_options": [],
        "mountpoint": "/boot",
        "obj_id": str(uuid.uuid4()),
        "size": _size(boot_size, "MiB", c.sector_size),
        "start": _size(boot_start, "MiB", c.sector_size),
        "status": "create",
        "type": "primary",
    }
    root = {
        "btrfs": [],
        "dev_path": None,
        "flags": [],
        "fs_type": c.filesystem,
        "mount_options": [],
        "mountpoint": "/",
        "obj_id": str(uuid.uuid4()),
        "size": _size(root_size, "MiB", c.sector_size),
        "start": _size(root_start, "MiB", c.sector_size),
        "status": "create",
        "type": "primary",
    }
    if c.filesystem == "btrfs":
        root["mountpoint"] = None
        root["mount_options"] = ["compress=zstd"]
        root["btrfs"] = [
            {"name": "@", "mountpoint": "/"},
            {"name": "@home", "mountpoint": "/home"},
            {"name": "@log", "mountpoint": "/var/log"},
            {"name": "@pkg", "mountpoint": "/var/cache/pacman/pkg"},
        ]
    return {
        "config_type": "default_layout",
        "device_modifications": [
            {"device": c.disk, "partitions": [boot, root], "wipe": True},
        ],
    }


def locale_for(language: str) -> str:
    return {"de": "de_AT", "en": "en_US"}.get(language, "en_US")


def post_install_commands(c: Choices) -> list[str]:
    """Run by archinstall inside the new system (arch-chroot, as root)."""
    u = shlex.quote(c.username)
    profile = shlex.quote(f'PROFILE="{c.platform}"')
    as_user = lambda cmd: f"su - {u} -c {shlex.quote(cmd)}"  # noqa: E731
    return [
        # groups glassy needs (brightness, input, i2c for monitor brightness)
        "getent group i2c >/dev/null || groupadd i2c",
        f"usermod -aG video,input,i2c {u}",
        "echo i2c-dev > /etc/modules-load.d/i2c-dev.conf",
        # first login: Hyprland preselected in the login screen
        "mkdir -p /var/lib/sddm && printf '[Last]\\nSession=/usr/share/wayland-sessions/hyprland.desktop\\n' > /var/lib/sddm/state.conf",
        "chown -R sddm:sddm /var/lib/sddm 2>/dev/null || true",
        # platform profile + set up glassy in the new user's home
        as_user(f"mkdir -p ~/.config/vitra && printf '%s\\n' {profile} > ~/.config/vitra/profile"),
        as_user("vtx -y deploy"),
        # a note about who made this
        "printf 'Vitra - installed with vitrainstall\\n(c) 2026 34 & Claude\\n' > /etc/vitra-release",
    ]


def build(c: Choices) -> tuple[dict, dict]:
    """-> (user_configuration, user_credentials) for archinstall --config/--creds."""
    validate(c)
    lang = locale_for(c.language)
    config = {
        "archinstall-language": "German" if c.language == "de" else "English",
        "app_config": {"audio_config": {"audio": "pipewire"}, "bluetooth_config": {"enabled": True}},
        "bootloader_config": {"bootloader": "Systemd-boot" if c.uefi else "Grub", "uki": False, "removable": False},
        "custom_commands": post_install_commands(c),
        "debug": False,
        "disk_config": disk_layout(c),
        "hostname": c.hostname,
        "kernels": ["linux"],
        "locale_config": {"kb_layout": c.keyboard, "sys_enc": "UTF-8", "sys_lang": lang},
        "mirror_config": {
            "custom_repositories": [VITRA_REPO],
            "custom_servers": [],
            "mirror_regions": {},
            "optional_repositories": ["multilib"],
        },
        "network_config": {"type": "nm"},
        "no_pkg_lookups": False,
        "ntp": True,
        "offline": False,
        "packages": VITRA_PACKAGES + [p for p in c.extra_packages if p not in VITRA_PACKAGES],
        "pacman_config": {"color": True, "parallel_downloads": 5},
        "profile_config": {
            "gfx_driver": c.gfx_driver,
            "greeter": "sddm",
            "profile": {
                "custom_settings": {"Hyprland": {"seat_access": "systemd-logind"}},
                "details": ["Hyprland"],
                "main": "Desktop",
            },
        },
        "script": "guided",
        "silent": True,
        "swap": {"enabled": True, "algorithm": "zstd"},
        "timezone": c.timezone,
        "version": "4.5",
    }
    creds = {
        "users": [
            {
                "username": c.username,
                "!password": c.password,
                "sudo": True,
                "groups": ["wheel"],
            }
        ],
        # root stays locked: no password, use sudo
    }
    return config, creds
