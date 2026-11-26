# vitrainstall

The graphical installer of **Vitra**, an Arch-based Linux distribution.

(c) 2026 34 & Claude. Licensed under GPL-3.0-or-later.

- Own interface (Python + Qt/QML), own look, no top bar until you pick your style
- Asks: language, style (Linux / Windows / Mac), keyboard, time zone, disk, user
- The risky part (partitioning, boot loader, users) is done by **archinstall**:
  vitrainstall writes an archinstall config and runs `archinstall --silent`
- Afterwards in the new system: [vitra] repo, vtx, cmaal, glassy-shell, vitra-branding,
  your style profile and `vtx deploy` for your user
- Mirrors just work: the list shipped in the ISO is used first, reflector only adds faster
  ones (max. 35 s), a retry after download problems starts with other mirrors
- The keyboard layout you pick changes the live session right away (sway kiosk)

```
vitrainstall --test --window    click through everything, nothing is installed
sudo vitrainstall               real install (live ISO)
make test                       config tests
make shots                      screenshots of every page (test mode, offscreen)
```

---

## Deutsch

Der grafische Installer von **Vitra**. Eigene Oberfläche (Python + Qt/QML), den riskanten Teil
(Partitionieren, Bootloader, Benutzer) macht archinstall im Hintergrund. Danach kommen [vitra],
vtx, cmaal, glassy-shell, vitra-branding, dein Stil-Profil und `vtx deploy` ins neue System.
Mirrors funktionieren ohne Befehle von Hand, und das gewaehlte Tastaturlayout gilt sofort.

`vitrainstall --test --window` zum Durchklicken, ohne dass etwas installiert wird.

(c) 2026 34 & Claude. Lizenz: GPL-3.0-or-later.
