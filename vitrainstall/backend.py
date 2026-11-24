# vitrainstall: Qt bridge between the QML pages and the install logic
# (c) 2026 34 & Claude - GPL-3.0-or-later

from __future__ import annotations

import json
import os
import re
import shutil
import tempfile
from pathlib import Path

from PySide6.QtCore import Property, QObject, QProcess, QTimer, Signal, Slot

from . import config, system

# archinstall output -> (progress %, step key). The QML side translates the step key.
STEPS = [
    (r"wip(e|ing)|partition|format", 8, "disk"),
    (r"mount", 14, "mount"),
    (r"mirror|pacman\.conf|repositor", 18, "mirrors"),
    (r"pacstrap|installing packages|base system", 25, "base"),
    (r"kernel|mkinitcpio|initramfs", 55, "kernel"),
    (r"bootloader|systemd-boot|grub|bootctl", 65, "boot"),
    (r"profile|hyprland|greeter|sddm|graphics|driver", 72, "desktop"),
    (r"additional packages|installing.*(vtx|glassy)", 82, "vitra"),
    (r"user|password|sudo", 88, "user"),
    (r"custom command", 92, "setup"),
    (r"installation completed|installation finished|you can now reboot", 100, "done"),
]


class Backend(QObject):
    progressChanged = Signal()
    stepChanged = Signal()
    logLine = Signal(str)
    finished = Signal(bool, str)  # success, error key / message
    stateChanged = Signal()

    def __init__(self, test_mode: bool = False, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._test = test_mode
        self._progress = 0
        self._step = "prepare"
        self._running = False
        self._proc: QProcess | None = None
        self._workdir = Path(tempfile.mkdtemp(prefix="vitrainstall-"))
        self._log = self._workdir / "install.log"
        self._fake_timer: QTimer | None = None
        self._fake_lines: list[str] = []

    # ---------------------------------------------------------------- info for the pages
    @Property(bool, constant=True)
    def testMode(self) -> bool:
        return self._test

    @Property(str, constant=True)
    def version(self) -> str:
        for v in (Path(__file__).with_name("VERSION"), Path(__file__).parent.parent / "VERSION"):
            if v.exists():
                return v.read_text().strip()
        return "dev"

    @Slot(result="QVariantList")
    def disks(self) -> list:
        found = system.disks()
        if self._test and not found:
            found = [{"path": "/dev/vda", "model": "Test-Platte (Test mode)", "size": 64_000_000_000,
                      "sizeText": "64.0 GB", "transport": "VIRTIO", "removable": False, "sectorSize": 512}]
        return found

    @Slot(result="QStringList")
    def keyboardLayouts(self) -> list:
        return system.keyboard_layouts()

    @Slot(result="QStringList")
    def timezones(self) -> list:
        return system.timezones()

    @Slot(result=str)
    def guessTimezone(self) -> str:
        return system.guess_timezone()

    @Slot(result=str)
    def guessGfxDriver(self) -> str:
        return system.guess_gfx_driver()

    @Slot(result=bool)
    def hasInternet(self) -> bool:
        return True if self._test else system.has_internet()

    @Slot(result=bool)
    def isUefi(self) -> bool:
        return True if self._test else system.is_uefi()

    @Slot(str, result=str)
    def setKeyboard(self, layout: str) -> str:
        """Switch the live session's keyboard right away, so typing the password matches."""
        if self._test or layout not in system.keyboard_layouts():
            return layout
        import subprocess

        for cmd in (["hyprctl", "keyword", "input:kb_layout", layout], ["localectl", "set-x11-keymap", layout]):
            if shutil.which(cmd[0]):
                subprocess.run(cmd, capture_output=True, check=False)
        return layout

    @Property(int, notify=progressChanged)
    def progress(self) -> int:
        return self._progress

    @Property(str, notify=stepChanged)
    def step(self) -> str:
        return self._step

    @Property(bool, notify=stateChanged)
    def running(self) -> bool:
        return self._running

    @Property(str, constant=True)
    def logPath(self) -> str:
        return str(self._log)

    # ---------------------------------------------------------------- checks + install
    @Slot("QVariantMap", result=str)
    def check(self, choices: dict) -> str:
        """'' when everything is fine, else an error key for the QML side."""
        try:
            config.build(self._choices(choices))
        except config.ChoiceError as e:
            return str(e)
        return ""

    @Slot("QVariantMap", result=str)
    def summary(self, choices: dict) -> str:
        """The generated archinstall config without the password (shown in 'details')."""
        try:
            cfg, _ = config.build(self._choices(choices))
        except config.ChoiceError as e:
            return f"error: {e}"
        return json.dumps(cfg, indent=2)

    @Slot("QVariantMap")
    def install(self, choices: dict) -> None:
        if self._running:
            return
        try:
            cfg, creds = config.build(self._choices(choices))
        except config.ChoiceError as e:
            self.finished.emit(False, str(e))
            return

        cfg_path = self._workdir / "user_configuration.json"
        creds_path = self._workdir / "user_credentials.json"
        cfg_path.write_text(json.dumps(cfg, indent=2))
        # credentials only readable by us, removed right after archinstall read them
        fd = os.open(creds_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            json.dump(creds, f)

        self._set_running(True)
        self._set_progress(2, "prepare")

        if self._test:
            self._fake_install()
            return

        self._proc = QProcess(self)
        self._proc.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        self._proc.readyReadStandardOutput.connect(self._read)
        self._proc.finished.connect(lambda code, _status: self._done(code == 0, creds_path))
        self._proc.start("archinstall", ["--config", str(cfg_path), "--creds", str(creds_path), "--silent"])

    def _choices(self, d: dict) -> config.Choices:
        c = config.Choices()
        for key, value in d.items():
            attr = re.sub(r"(?<!^)(?=[A-Z])", "_", key).lower()  # diskSize -> disk_size
            if hasattr(c, attr) and value is not None:
                cur = getattr(c, attr)
                setattr(c, attr, int(value) if isinstance(cur, int) and not isinstance(cur, bool) else value)
        return c

    def _read(self) -> None:
        if not self._proc:
            return
        text = bytes(self._proc.readAllStandardOutput().data()).decode(errors="replace")
        text = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", text)  # no colour codes in the log view
        with open(self._log, "a") as f:
            f.write(text)
        for line in text.splitlines():
            if line.strip():
                self._feed(line)

    def _feed(self, line: str) -> None:
        self.logLine.emit(line)
        low = line.lower()
        for pattern, pct, key in STEPS:
            if pct > self._progress and re.search(pattern, low):
                self._set_progress(pct, key)
                break

    def _done(self, ok: bool, creds_path: Path) -> None:
        creds_path.unlink(missing_ok=True)
        self._set_running(False)
        if ok:
            self._set_progress(100, "done")
            self.finished.emit(True, "")
        else:
            self.finished.emit(False, "install_failed")

    # test mode: walks through the steps without touching anything
    def _fake_install(self) -> None:
        self._fake_lines = [
            "[test] Wiping /dev/vda and creating partitions",
            "[test] Mounting filesystems",
            "[test] Writing pacman.conf with [vitra] repository",
            "[test] pacstrap: installing base system",
            "[test] Running mkinitcpio for the kernel",
            "[test] Installing bootloader systemd-boot",
            "[test] Installing profile Hyprland, greeter sddm, graphics driver",
            "[test] Installing additional packages: vtx glassy-shell cmaal",
            "[test] Creating user and setting password",
            "[test] Running custom commands: vtx deploy",
            "[test] Installation completed (nothing was changed - test mode)",
        ]
        self._fake_timer = QTimer(self)
        self._fake_timer.setInterval(700)
        self._fake_timer.timeout.connect(self._fake_tick)
        self._fake_timer.start()

    def _fake_tick(self) -> None:
        if not self._fake_lines:
            assert self._fake_timer is not None
            self._fake_timer.stop()
            self._done(True, self._workdir / "user_credentials.json")
            return
        self._feed(self._fake_lines.pop(0))

    @Slot()
    def reboot(self) -> None:
        if self._test:
            self.logLine.emit("[test] reboot")
            return
        import subprocess

        subprocess.run(["systemctl", "reboot"], check=False)

    @Slot()
    def quit(self) -> None:
        from PySide6.QtCore import QCoreApplication

        QCoreApplication.quit()

    def _set_progress(self, pct: int, step: str) -> None:
        self._progress = pct
        self._step = step
        self.progressChanged.emit()
        self.stepChanged.emit()

    def _set_running(self, value: bool) -> None:
        self._running = value
        self.stateChanged.emit()
