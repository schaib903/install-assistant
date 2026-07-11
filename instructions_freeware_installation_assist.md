Erstelle einen plattformübergreifenden Installationsassistenten.

Plattform-Erkennung:
- Windows → verwendet winget, erstellt PowerShell-Skript
- Linux (Debian/Ubuntu) → verwendet apt, erstellt Bash-Skript
- Gibt Fehlermeldung bei unbekannter Plattform

Ablauf:
1. Plattform automatisch erkennen und anzeigen
2. Hostname, OS, RAM, CPU anzeigen
3. Für jedes Programm prüfen ob installiert: ✅ oder ❌
4. Übersichtliche Liste aller fehlenden Programme anzeigen
5. Einmal gesammelt bestätigen (J/N)
6. Alle fehlenden Programme nacheinander installieren
7. Abschlussbericht: was wurde installiert, was hat geklappt

Programme:
- Firefox, Google Chrome
- Notepad++ (nur Windows)
- VLC, 7-Zip, VS Code, Git
- Python (Übersicht der Versionen und den User nach der Version fragen)

Ausgabe farbig, Deutsch, sauber strukturiert.
Das generierte Skript soll als Datei gespeichert werden.
