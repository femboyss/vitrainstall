#!/usr/bin/env python3
# Let archinstall itself read the config vitrainstall builds. READ-ONLY, nothing is changed.
# (c) 2026 34 & Claude - GPL-3.0-or-later
#
#   sudo python3 tests/check_archinstall.py            uses the first disk vitrainstall offers
#   sudo python3 tests/check_archinstall.py /dev/sdb   a specific disk
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from vitrainstall import config, system  # noqa: E402

try:
    from archinstall.lib.args import ArchConfig, Arguments
except ImportError:
    sys.exit("archinstall is not installed: sudo pacman -S archinstall")

disks = system.disks()
want = sys.argv[1] if len(sys.argv) > 1 else (disks[0]["path"] if disks else "")
disk = next((d for d in disks if d["path"] == want), None)
if not disk:
    sys.exit(f"disk not found: {want!r} (offered: {[d['path'] for d in disks]})")

ok = True
for fs in ("btrfs", "ext4"):
    c = config.Choices(
        language="de", platform="windows", keyboard="de", timezone="Europe/Vienna",
        disk=disk["path"], disk_size=disk["size"], sector_size=disk["sectorSize"],
        filesystem=fs, username="test", password="test", uefi=system.is_uefi(),
        gfx_driver=system.guess_gfx_driver(),
    )
    cfg, creds = config.build(c)
    arch = ArchConfig.from_config({**cfg, **creds}, Arguments())
    mods = arch.disk_config.device_modifications if arch.disk_config else []
    print(f"== {fs} on {disk['path']} ({disk['sizeText']})")
    if not mods:
        print("   FAIL: archinstall dropped the disk (device not found) - it would install NOTHING")
        ok = False
        continue
    for p in mods[0].partitions:
        subs = ", ".join(str(s.mountpoint) for s in p.btrfs_subvols)
        print(f"   {p.fs_type.value if p.fs_type else '?':6} start {p.start.format_highest()}  size {p.length.format_highest()}"
              f"  mount {p.mountpoint or '-'}  {subs}")
    print(f"   bootloader {arch.bootloader_config.bootloader.value if arch.bootloader_config else '?'}, "
          f"profile {arch.profile_config.profile.name if arch.profile_config and arch.profile_config.profile else '?'}, "
          f"gfx {arch.profile_config.gfx_driver.value if arch.profile_config and arch.profile_config.gfx_driver else '?'}")
    print(f"   repos {[r.name for r in arch.mirror_config.custom_repositories] if arch.mirror_config else []}, "
          f"users {[u.username for u in arch.auth_config.users] if arch.auth_config else []}, "
          f"packages {len(arch.packages)}, custom commands {len(arch.custom_commands)}")
print("\nALL OK - archinstall accepts the config" if ok else "\nPROBLEMS FOUND")
sys.exit(0 if ok else 1)
