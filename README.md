# Papaj

Animowany gadżet na pulpit Windows z Janem Pawłem II (PowerShell + WPF).
Działa w tle i co jakiś czas pokazuje się na pulpicie.

## Instalacja (jedna linijka)

W **PowerShell** wklej i uruchom:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Funkrypt/Papaj/main/install.ps1 | iex"
```

Instalator pobiera projekt do `%LOCALAPPDATA%\Papaj`, dodaje autostart i od razu uruchamia gadżet.
Nie wymaga gita. Plik `organy.wav` generuje się sam przy pierwszym starcie.

## Zachowanie
- Domyślnie **ukryty**, działa w tle.
- **Co 10 minut**: krótki „peek" — wysuwa się z dołu na ~2,5 s (bez dźwięku) i chowa.
- **Co 30 minut, na zmianę**:
  - **cytat** — wysuwa się z dymkiem, gra organy, lektor czyta cytat, po czym się chowa;
  - **raport RAM/CPU** — wysuwa się i humorystycznie czyta aktualne zużycie zasobów.
- Lektor: **OneCore TTS** (widzi nowoczesne głosy Windows). Preferuje polski głos
  (Paulina/Adam); jeśli systemu brak polskiego głosu, **instalator doinstaluje go**
  automatycznie, a gdyby się nie udało — gadżet użyje głosu domyślnego.
- Klik na widocznego papieża = schowaj; prawy przycisk (gdy widoczny) = menu.

## Pliki
- `Papaj.ps1` — główny skrypt gadżetu.
- `papaj.gif` — animacja postaci.
- `papaj_cytaty.txt` — baza cytatów (format: `treść|źródło`).
- `start.vbs` — uruchamia gadżet bez okna konsoli (przenośny, z własnego folderu).
- `install.ps1` — instalator (pobranie + autostart + uruchomienie).

## Pliki generowane (poza repo)
- `organy.wav` — syntezowany programowo przy pierwszym starcie.

## Wymagania
Windows 10/11, PowerShell 5+, głos TTS „Microsoft Paulina Desktop" (opcjonalnie).
