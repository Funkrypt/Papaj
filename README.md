# Papaj

Animowany gadżet na pulpit Windows z Janem Pawłem II (PowerShell + WPF).

## Funkcje
- Dymek z losowym cytatem (ponad 100 pozycji w `papaj_cytaty.txt`).
- Kliknięcie lewym = następny cytat + organy + lektor (głos „Paulina", TTS).
- Menu pod prawym przyciskiem: czytaj / następny / zatrzymaj / raport / zamknij.
- **Co 30 minut** głosowy, humorystyczny raport o zużyciu RAM i CPU.
- Animacja GIF odtwarzana **tylko wtedy, gdy papież mówi**.
- Okno trzymane w prawym dolnym rogu pulpitu, zawsze na wierzchu.

## Pliki
- `Papaj.ps1` — główny skrypt gadżetu.
- `papaj.gif` — animacja postaci.
- `papaj_cytaty.txt` — baza cytatów (format: `treść|źródło`).
- `start.vbs` — uruchamia gadżet bez okna konsoli (skrót w folderze Autostart).

## Pliki generowane (poza repo)
- `organy.wav` — syntezowany programowo przy pierwszym starcie, więc nie trzeba
  go dystrybuować; na nowym komputerze skrypt odtworzy go sam.

## Wymagania
Windows 10/11, PowerShell 5+, głos TTS „Microsoft Paulina Desktop" (opcjonalnie).
