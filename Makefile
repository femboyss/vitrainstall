# vitrainstall - (c) 2026 34 & Claude - GPL-3.0-or-later
PREFIX  ?= /usr
DESTDIR ?=

.PHONY: install test shots
install:
	install -d "$(DESTDIR)$(PREFIX)/lib/vitrainstall"
	cp -r vitrainstall "$(DESTDIR)$(PREFIX)/lib/vitrainstall/"
	cp VERSION "$(DESTDIR)$(PREFIX)/lib/vitrainstall/vitrainstall/VERSION"
	find "$(DESTDIR)$(PREFIX)/lib/vitrainstall" -name __pycache__ -prune -exec rm -rf {} +
	install -Dm755 bin/vitrainstall "$(DESTDIR)$(PREFIX)/bin/vitrainstall"
	install -Dm644 data/vitrainstall.desktop "$(DESTDIR)$(PREFIX)/share/applications/vitrainstall.desktop"
	install -Dm644 LICENSE "$(DESTDIR)$(PREFIX)/share/licenses/vitrainstall/LICENSE"
	install -Dm644 README.md "$(DESTDIR)$(PREFIX)/share/doc/vitrainstall/README.md"

test:
	python3 tests/test_config.py

shots:
	rm -rf shots && mkdir shots
	QT_QPA_PLATFORM=offscreen python3 -m vitrainstall --shot shots
