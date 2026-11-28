"""Export the gallery's ArkUI audit page from the actual OpenHarmony Previewer.

Requires Pillow and websocket-client, the SDK 12 Previewer, a compiled gallery
modules.abc directory, and the resource directory containing resources.index.
"""
import argparse
import io
import json
from pathlib import Path
import shutil
import socket
import tempfile
import subprocess
import threading
import time

from PIL import Image
import websocket

repo = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--previewer", type=Path, required=True)
parser.add_argument("--ets", type=Path, required=True)
parser.add_argument("--resources", type=Path, required=True)
parser.add_argument("--out", type=Path, default=repo / ".build/shadcn-audit/harmony")
parser.add_argument("--theme", choices=["light", "dark", "both"], default="both")
parser.add_argument("--dark-resource-compiler", type=Path, metavar="RESTOOL",
                    help="Pin the gallery's dark-qualified resources for SDK Previewers which resolve the default palette in dark mode.")
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=True)
samples = json.loads((repo / "Sources/AIElementsCatalog/Resources/shadcn-catalog.json").read_text())

def drain_pipe(name):
    path = Path("/tmp") / name
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
        server.bind(str(path))
        server.listen(1)
        server.settimeout(80)
        try:
            stream, _ = server.accept()
            with stream:
                while stream.recv(65536):
                    pass
        except (OSError, TimeoutError):
            pass
        finally:
            path.unlink(missing_ok=True)

def identify(image):
    # JPEG's chroma subsampling affects the edges. Read the center of each block.
    for y in range(64, image.height - 6):
        r, g, b = image.getpixel((8, y))
        gr, gg, gb = image.getpixel((136, y))
        if r > 190 and b > 190 and g < 70 and gg > 170 and max(gr, gb) < 80:
            index = sum(1 << bit for bit in range(7) if image.getpixel((24 + 16 * bit, y + 3))[0] > 128)
            if index < len(samples):
                return index, y

def dark_resources(directory):
    # API 12 desktop Previewer may use default values for app.color resources when
    # -cm dark is active. The device HAP keeps its normal resource qualifiers.
    source = directory / "input"
    out = directory / "compiled"
    out.mkdir()
    modules = [repo / "HarmonyOS/AppScope/resources",
               repo / "HarmonyOS/aielements/src/main/resources",
               repo / "HarmonyOS/gallery/src/main/resources"]
    for resources in modules:
        for file in resources.rglob("*"):
            if not file.is_file():
                continue
            target = source / "resources" / file.relative_to(resources)
            target.parent.mkdir(parents=True, exist_ok=True)
            if file.parent.name == "element" and target.exists():
                existing = json.loads(target.read_text())
                for kind, entries in json.loads(file.read_text()).items():
                    merged = {item["name"]: item for item in existing.get(kind, [])}
                    merged.update({item["name"]: item for item in entries})
                    existing[kind] = list(merged.values())
                target.write_text(json.dumps(existing))
            else:
                shutil.copyfile(file, target)
    for element in (source / "resources/dark/element").glob("*.json"):
        default = source / "resources/base/element" / element.name
        values = json.loads(default.read_text())
        for kind, entries in json.loads(element.read_text()).items():
            replacements = {item["name"]: item for item in entries}
            values[kind] = [replacements.get(item["name"],item) for item in values[kind]]
        default.write_text(json.dumps(values))
    metadata = source / "module.json"
    shutil.copyfile(args.resources / "module.json", metadata)
    table = out / "ResourceTable.txt"
    subprocess.run([str(args.dark_resource_compiler.resolve()), "-i", str(source), "-o", str(out),
                    "-p", "dev.aielements.gallery", "-j", str(metadata), "-r", str(table), "-f"],check=True)
    original = args.resources / "ResourceTable.txt"
    if original.exists() and set(original.read_text().splitlines()) != set(table.read_text().splitlines()):
        raise RuntimeError("Preview resource identifiers differ from the gallery bytecode's resource table")
    return out

def capture(theme, resource_dir):
    with socket.socket() as free_port:
        free_port.bind(("127.0.0.1", 0))
        port = free_port.getsockname()[1]
    tag = "aie" + str(port)
    for pipe in [tag, tag + "_commandPipe", tag + "_trace"]:
        threading.Thread(target=drain_pipe, args=(pipe,), daemon=True).start()
    executable = args.previewer.resolve()
    command = [str(executable), "-j", str(args.ets.resolve()), "-arp", str(resource_dir.resolve()),
               "-url", "pages/ShadcnAuditDark" if theme == "dark" else "pages/ShadcnAudit", "-or", "360", "760", "-cr", "360", "760",
               "-av", "ACE_2_0", "-device", "phone", "-s", tag, "-ts", tag + "_trace", "-lws", str(port),
               "-pm", "Stage", "-bn", "dev.aielements.gallery", "-projectID", "AIElements",
               "-sd", "160", "-cm", theme, "-sm", "dynamic", "-l", "en_US", "-pages", "main_pages"]
    seen = set()
    with (args.out / ("previewer-" + theme + ".log")).open("wb") as log:
        engine = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, cwd=executable.parent)
        client = None
        try:
            for _ in range(70):
                try:
                    client = websocket.create_connection("ws://127.0.0.1:" + str(port), timeout=2)
                    break
                except OSError:
                    time.sleep(.1)
            if client is None:
                raise RuntimeError("Previewer WebSocket did not open")
            deadline = time.monotonic() + 125
            while time.monotonic() < deadline and engine.poll() is None:
                try:
                    data = client.recv()
                except websocket.WebSocketTimeoutException:
                    continue
                if not isinstance(data, bytes):
                    continue
                start = data.find(b"\xff\xd8\xff")
                if start < 0:
                    continue
                frame = Image.open(io.BytesIO(data[start:])).convert("RGB")
                found = identify(frame)
                if found:
                    index, height = found
                    background = frame.getpixel((frame.width-5, frame.height-5))
                    if (theme == "dark" and max(background)>64) or (theme == "light" and min(background)<192):
                        raise RuntimeError(f"The renderer returned {background} for the {theme} canvas.")
                    frame.crop((0, 0, frame.width, height)).save(args.out / (samples[index]["id"]+"-"+theme+".png"))
                    seen.add(index)
                    if len(seen) == len(samples):
                        break
        finally:
            if client:
                client.close()
            engine.terminate()
            try:
                engine.wait(timeout=3)
            except subprocess.TimeoutExpired:
                engine.kill()
                engine.wait()
    if "FIX THIS APPLICATION ERROR" in (args.out / ("previewer-" + theme + ".log")).read_text(errors="replace"):
        raise RuntimeError(f"ArkUI reported a component error in {theme}. Inspect the Previewer log.")
    missing = [sample["id"] for i,sample in enumerate(samples) if i not in seen]
    if missing:
        raise RuntimeError(f"{theme}: missing {', '.join(missing)}")
    print(f"{theme}: {len(seen)} ArkUI previews", flush=True)

with tempfile.TemporaryDirectory() as scratch:
    for theme in (["light", "dark"] if args.theme == "both" else [args.theme]):
        resource_dir = dark_resources(Path(scratch)) if theme == "dark" and args.dark_resource_compiler else args.resources
        capture(theme, resource_dir)
