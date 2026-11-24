# vitrainstall: the Vitra installer
# (c) 2026 34 & Claude - GPL-3.0-or-later
#
#   vitrainstall            fullscreen (live ISO)
#   vitrainstall --window   in a normal window
#   vitrainstall --test     click through everything, nothing is installed
#   vitrainstall --shot DIR save a screenshot of every page and quit (needs --test)

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from .backend import Backend

HERE = Path(__file__).resolve().parent


def main() -> int:
    ap = argparse.ArgumentParser(prog="vitrainstall", description="The Vitra installer")
    ap.add_argument("--test", action="store_true", help="test mode: nothing is installed")
    ap.add_argument("--window", action="store_true", help="run in a window instead of fullscreen")
    ap.add_argument("--lang", choices=["en", "de"], help="start language")
    ap.add_argument("--shot", metavar="DIR", help="save screenshots of all pages (test mode)")
    args = ap.parse_args()

    if not args.test and os.geteuid() != 0:
        print("vitrainstall must run as root (it partitions disks). Try: vitrainstall --test", file=sys.stderr)
        return 1

    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("vitrainstall")
    app.setOrganizationName("Vitra")

    backend = Backend(test_mode=args.test or bool(args.shot))
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    lang = args.lang or ("de" if os.environ.get("LANG", "").startswith("de") else "en")
    engine.rootContext().setContextProperty("startLanguage", lang)
    engine.rootContext().setContextProperty("startWindowed", args.window or bool(args.shot))
    engine.rootContext().setContextProperty("shotDir", args.shot or "")
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        return 1

    if args.shot:
        root = engine.rootObjects()[0]
        QTimer.singleShot(0, lambda: root.startShots())

    code = app.exec()
    del engine  # QML first, then the backend it uses
    return code


if __name__ == "__main__":
    sys.exit(main())
