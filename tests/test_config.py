# vitrainstall config tests - (c) 2026 34 & Claude - GPL-3.0-or-later
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from vitrainstall import config  # noqa: E402

GIB = 1024**3


def good(**kw):
    c = config.Choices(disk="/dev/nvme0n1", disk_size=500 * GIB, username="stefan", password="pw", **kw)
    return c


def test_builds_valid_json():
    cfg, creds = config.build(good())
    json.dumps(cfg), json.dumps(creds)
    assert cfg["silent"] is True
    assert cfg["mirror_config"]["custom_repositories"][0]["name"] == "vitra"
    assert "vtx" in cfg["packages"] and "glassy-shell" in cfg["packages"]
    assert creds["users"][0]["username"] == "stefan" and creds["users"][0]["sudo"] is True
    assert "pw" not in json.dumps(cfg), "password must never be in the main config"


def test_layout_fills_disk():
    cfg, _ = config.build(good())
    dm = cfg["disk_config"]["device_modifications"][0]
    boot, root = dm["partitions"]
    assert dm["device"] == "/dev/nvme0n1" and dm["wipe"] is True
    assert boot["mountpoint"] == "/boot" and boot["fs_type"] == "fat32" and "esp" in boot["flags"]
    end = root["start"]["value"] + root["size"]["value"]
    assert end <= 500 * 1024 - 1, "root must not run past the disk end"
    assert end >= 500 * 1024 - 2


def test_btrfs_subvolumes_and_ext4():
    cfg, _ = config.build(good(filesystem="btrfs"))
    root = cfg["disk_config"]["device_modifications"][0]["partitions"][1]
    assert root["mountpoint"] is None and {v["mountpoint"] for v in root["btrfs"]} >= {"/", "/home"}
    cfg, _ = config.build(good(filesystem="ext4"))
    root = cfg["disk_config"]["device_modifications"][0]["partitions"][1]
    assert root["mountpoint"] == "/" and root["btrfs"] == []


def test_bios_uses_grub():
    cfg, _ = config.build(good(uefi=False))
    assert cfg["bootloader_config"]["bootloader"] == "Grub"
    assert "esp" not in cfg["disk_config"]["device_modifications"][0]["partitions"][0]["flags"]


def test_platform_profile_written_for_user():
    cfg, _ = config.build(good(platform="windows"))
    cmds = "\n".join(cfg["custom_commands"])
    assert "su - stefan" in cmds and 'PROFILE="windows"' in cmds and "vtx -y deploy" in cmds


def test_language_and_keyboard():
    cfg, _ = config.build(good(language="de", keyboard="de", timezone="Europe/Vienna"))
    assert cfg["locale_config"] == {"kb_layout": "de", "sys_enc": "UTF-8", "sys_lang": "de_AT"}
    assert cfg["timezone"] == "Europe/Vienna"


def test_rejects_bad_input():
    bad = [
        dict(username=""), dict(username="Root"), dict(username="root"), dict(username="1abc"),
        dict(username="a b"), dict(password=""), dict(disk="sda"), dict(disk_size=10 * GIB),
        dict(hostname="bad host"), dict(platform="amiga"), dict(filesystem="ntfs"), dict(gfx_driver="x"),
    ]
    for b in bad:
        kw = dict(disk="/dev/sda", disk_size=500 * GIB, username="stefan", password="pw")
        kw.update(b)
        try:
            config.build(config.Choices(**kw))
        except config.ChoiceError:
            continue
        raise AssertionError(f"accepted bad input {b}")


def test_shell_injection_in_username_impossible():
    # usernames are restricted to [a-z0-9_-], so nothing can break out of su -c
    for name in ["a;rm -rf /", "a$(x)", "a'b", 'a"b', "a`b`"]:
        try:
            config.build(good() if False else config.Choices(disk="/dev/sda", disk_size=500 * GIB, username=name, password="p"))
        except config.ChoiceError:
            continue
        raise AssertionError(name)


if __name__ == "__main__":
    n = 0
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn(); n += 1; print("ok", name)
    print(f"{n} passed")
