Create a cross-platform install assistant.

Platform detection:
- Windows → uses winget, generates a PowerShell script
- Linux (Debian/Ubuntu) → uses apt, generates a Bash script
- Shows an error message for an unrecognized platform

Flow:
1. Automatically detect and display the platform
2. Show hostname, OS, RAM, CPU
3. Check each program for installation status: ✅ or ❌
4. Show a clear list of all missing programs
5. Ask for a single combined confirmation (Y/N)
6. Install all missing programs one after another
7. Final report: what was installed, what succeeded

Programs:
- Firefox, Google Chrome
- Notepad++ (Windows only)
- VLC, 7-Zip, VS Code, Git
- Python (show available versions and ask the user which one)

Output should be colorful, in English, and cleanly structured.
The generated script should be saved as a file.
