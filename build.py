import json, sys, shutil, pathlib, os

ROOT_PATH = pathlib.Path(__file__).resolve().parent
INFO_JSON = ROOT_PATH / "factory_zones/info.json"
TARGET_FOLDER = str(ROOT_PATH / "factory_zones")

if not INFO_JSON.exists(): sys.exit(f"ERROR: info.json not found")

with open(INFO_JSON, "r", encoding="utf-8") as f: info = json.load(f)

mod_name = info.get("name")
mod_version = info.get("version")

if not mod_name: sys.exit('ERROR: info.json has no "name" field.')
if not mod_version: sys.exit('ERROR: info.json has no "version" field.')

archive_path = str(ROOT_PATH / f"{mod_name}_{mod_version}")

shutil.make_archive(archive_path, "zip", TARGET_FOLDER)
shutil.copy(f"{archive_path}.zip", str(os.path.join(os.getenv('APPDATA'), "Factorio\\mods")))