import json, sys, shutil, pathlib, os, zipfile

ROOT_PATH = pathlib.Path(__file__).resolve().parent
INFO_JSON = ROOT_PATH / "data/info.json"
TARGET_FOLDER = ROOT_PATH / "data"

if not INFO_JSON.exists(): sys.exit(f"ERROR: info.json not found")

with open(INFO_JSON, "r", encoding="utf-8") as f: info = json.load(f)

file_name = f"{info.get("name")}_{info.get("version")}"
archive_path = ROOT_PATH / f"{file_name}.zip"

with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as zf:
    for path in TARGET_FOLDER.rglob("*"):
        # construct zip with parent folder containing all files as required by factorio mods
        zf.write(path, pathlib.Path(file_name) / path.relative_to(TARGET_FOLDER))

# move new archive to appdata factorio mods folder
shutil.copy(archive_path, str(os.path.join(os.getenv('APPDATA'), "Factorio\\mods")))