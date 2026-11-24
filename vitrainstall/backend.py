# vitrainstall: Qt bridge between the QML pages and the install logic
# (c) 2026 34 & Claude - GPL-3.0-or-later

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import tempfile
import threading
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
    wifiNetworks = Signal("QVariantList")  # scan result
    wifiResult = Signal(str)  # '' = connected and online, else an error key

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
        self._choices_obj: config.Choices | None = None
        self._wifi: tuple[str, str] | None = None  # (ssid, password) that worked in the live system
        self._failure_log = ""

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
        if self._test:  # VITRAINSTALL_TEST_OFFLINE=1 shows the Wi-Fi picker in test mode
            return os.environ.get("VITRAINSTALL_TEST_OFFLINE") != "1"
        return system.has_internet()

    # ---------------------------------------------------------------- Wi-Fi
    @Slot(result=str)
    def wifiDevice(self) -> str:
        return "wlan0" if self._test else system.wifi_device()

    @Slot()
    def wifiScan(self) -> None:
        """Scans in the background, answers with wifiNetworks."""
        if self._test:
            QTimer.singleShot(1200, lambda: self.wifiNetworks.emit([
                {"ssid": "FRITZ!Box 7590 XY", "security": "psk", "secure": True, "signal": 4, "connected": False},
                {"ssid": "Schule-Gast", "security": "open", "secure": False, "signal": 2, "connected": False},
                {"ssid": "Nachbar", "security": "psk", "secure": True, "signal": 1, "connected": False},
            ]))
            return
        dev = system.wifi_device()
        threading.Thread(target=lambda: self.wifiNetworks.emit(system.wifi_scan(dev)), daemon=True).start()

    @Slot(str, str)
    def wifiConnect(self, ssid: str, password: str) -> None:
        """Connects in the background, answers with wifiResult ('' = online)."""
        if self._test:
            err = "wifi_wrong_password" if password == "wrong" else ""
            if not err:
                self._wifi = (ssid, password)
            QTimer.singleShot(1500, lambda: self.wifiResult.emit(err))
            return
        dev = system.wifi_device()

        def work() -> None:
            err = system.wifi_connect(dev, ssid, password)
            if not err:
                self._wifi = (ssid, password)
            self.wifiResult.emit(err)

        threading.Thread(target=work, daemon=True).start()

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

        self._choices_obj = self._choices(choices)
        self._failure_log = ""
        self._progress = 0
        self._set_running(True)
        self._set_progress(2, "prepare")

        if self._test:
            self._fake_install()
            return

        # a failed earlier try may still have the new disk mounted
        subprocess.run(["umount", "-R", "/mnt"], capture_output=True, check=False)

        # 1) fast mirrors near the user (the default list sometimes has a dead one first)
        self._set_progress(4, "mirrors")
        self._feed("[vitrainstall] looking for fast package mirrors (reflector) ...")
        args = system.reflector_command(self._choices_obj.timezone)
        mirrors = QProcess(self)
        mirrors.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        self._proc = mirrors
        mirrors.readyReadStandardOutput.connect(self._read)

        def after_mirrors(code: int, _status) -> None:  # noqa: ANN001
            self._feed("[vitrainstall] mirrors ready" if code == 0 else "[vitrainstall] reflector failed, using the default mirrors")
            self._start_archinstall(cfg_path, creds_path)

        mirrors.finished.connect(after_mirrors)
        mirrors.errorOccurred.connect(lambda _e: after_mirrors(1, None) if mirrors.state() == QProcess.ProcessState.NotRunning else None)
        QTimer.singleShot(90_000, lambda: mirrors.kill() if mirrors.state() != QProcess.ProcessState.NotRunning else None)
        mirrors.start(args[0], args[1:])

    def _start_archinstall(self, cfg_path: Path, creds_path: Path) -> None:
        if self._proc and self._proc.program() == "archinstall":
            return  # already started (errorOccurred + finished both fired)
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
            if not self._test:
                self._carry_over_wifi()
            self._set_progress(100, "done")
            self.finished.emit(True, "")
            return
        logs = [str(self._log), "/var/log/archinstall/install.log"]
        self._failure_log = system.log_tail(logs) if not self._test else "[test] error: failed retrieving file 'x' : Operation too slow"
        try:
            whole = "\n".join(Path(p).read_text(errors="replace")[-20000:] for p in logs if Path(p).exists())
        except OSError:
            whole = self._failure_log
        self.finished.emit(False, system.classify_failure(whole or self._failure_log))

    @Slot(result=str)
    def failureLog(self) -> str:
        return self._failure_log

    def _carry_over_wifi(self) -> None:
        """Put the Wi-Fi that worked here into the new system (NetworkManager keyfile, root only)."""
        c = self._choices_obj
        if not self._wifi or not c:
            return
        ssid, password = self._wifi
        part = c.disk + ("p2" if c.disk[-1].isdigit() else "2")
        target = Path(tempfile.mkdtemp(prefix="vitra-target-"))
        mount = ["mount", "-o", "subvol=@", part, str(target)] if c.filesystem == "btrfs" else ["mount", part, str(target)]
        if subprocess.run(mount, capture_output=True, check=False).returncode != 0:
            self._feed("[vitrainstall] could not save the Wi-Fi for the new system")
            return
        try:
            d = target / "etc/NetworkManager/system-connections"
            d.mkdir(parents=True, exist_ok=True)
            safe = re.sub(r"[^A-Za-z0-9._-]", "_", ssid) or "wifi"
            f = d / f"{safe}.nmconnection"
            fd = os.open(f, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "w") as out:
                out.write(system.nm_wifi_profile(ssid, password))
            self._feed(f"[vitrainstall] Wi-Fi '{ssid}' saved for the new system")
        finally:
            subprocess.run(["umount", str(target)], capture_output=True, check=False)
            target.rmdir()

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
            fail = bool(self._choices_obj and self._choices_obj.username == "fail")
            self._done(not fail, self._workdir / "user_credentials.json")
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
