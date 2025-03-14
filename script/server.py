import os
import subprocess
import sys
import tkinter as tk
from tkinter import filedialog
import webbrowser

# 1. Sicherstellen, dass das Skript die lokale Python-Version nutzt
def get_python_executable():
    script_dir = os.path.dirname(os.path.abspath(__file__))  # Ordner des Skripts
    python_exe = os.path.join(script_dir, "..", "python", "python", "python.exe")  # Windows
    if not os.path.exists(python_exe):  # Falls auf macOS/Linux
        python_exe = os.path.join(script_dir, "..", "python", "bin", "python3")
    return python_exe

# 2. Ordner über GUI auswählen
def choose_folder():
    root = tk.Tk()
    root.withdraw()  # Versteckt das Hauptfenster
    folder_selected = filedialog.askdirectory(title="Wähle einen Ordner mit HTML-Datei")
    return folder_selected

# 3. HTML-Datei ändern
def modify_html(folder_path, filename="index.html"):
    file_path = os.path.join(folder_path, filename)
    
    # Zu ersetzende Texte
    old_text_canvas = "OpenLIME.Viewer('#openlime', { background:'black' })"
    new_text_canvas = "OpenLIME.Viewer('#openlime', { background:'black', canvas: { preserveDrawingBuffer: true}})"
    
    old_text_snapshot = "ui.actions.layers.display = true;"
    new_text_snapshot = "ui.actions.layers.display = true;\n    ui.actions.snapshot.display = true;"

    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as file:
            content = file.read()

        # Ersetzen der Texte
        
        content = content.replace(old_text_canvas, new_text_canvas)
        if "ui.actions.snapshot.display = true;" not in content:
            content = content.replace(old_text_snapshot, new_text_snapshot)

        with open(file_path, "w", encoding="utf-8") as file:
            file.write(content)

        print(f"{filename} wurde erfolgreich geändert.")
    else:
        print(f"{filename} nicht gefunden.")

# 4. Lokalen Server starten
def start_server(folder_path, port=8000):
    os.chdir(folder_path)  # Wechsle ins Verzeichnis
    python_exe = get_python_executable()  # Lokale Python-Version verwenden
    return subprocess.Popen([python_exe, "-m", "http.server", str(port)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# 5. Hauptfunktion
def main():
    folder = choose_folder()
    if not folder:
        print("Kein Ordner ausgewählt. Beende das Programm.")
        return

    modify_html(folder)

    # Server starten
    server_process = start_server(folder)
    
    # Browser öffnen
    url = f"http://localhost:8000"
    webbrowser.open(url)
    print(f"Server läuft unter {url}")

    # Server sauber beenden
    try:
        while True:
            pass  # Halte das Skript am Laufen
    except KeyboardInterrupt:
        print("\nServer wird gestoppt...")
        server_process.terminate()

if __name__ == "__main__":
    main()
