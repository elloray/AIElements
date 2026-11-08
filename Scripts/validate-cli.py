#!/usr/bin/env python3
"""End-to-end CLI checks and compilation of every shipped example. macOS + Xcode."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--ios", action="store_true", help="Also compile examples for a generic iOS Simulator")
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]


def run(*command, **kwargs):
    return subprocess.run(command, check=True, text=True, **kwargs)


run("swift", "build", "--package-path", str(repo), "--product", "aielements")
build = Path(run("swift", "build", "--package-path", str(repo), "--show-bin-path", capture_output=True).stdout.strip())
cli = build / "aielements"


def invoke(*arguments):
    return run(str(cli), *arguments, capture_output=True).stdout


# Verify the executable's stdout/stderr/exit-code contract, not just library calls.
failure = subprocess.run([str(cli), "show", "does-not-exist", "--json"], text=True, capture_output=True)
assert failure.returncode == 2 and failure.stdout == "", failure
assert json.loads(failure.stderr)["exitCode"] == 2
catalog = json.loads(invoke("list", "--json"))
assert catalog["schemaVersion"] == 1 and len(catalog["components"]) == 37

scratch = repo / ".build" / "cli-validation"
scratch.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="run-", dir=scratch) as temporary:
    root = Path(temporary)
    # Validate each complete document and the progressive JSONL example through
    # the executable, including raw-artifact output when --json is supplied.
    documents = ["dashboard"] + [c["id"] for c in catalog["components"] if c.get("protocolType")]
    for name in documents:
        data = invoke("ui", "example", name)
        assert data == invoke("ui", "example", name, "--json")
        path = root / (name + ".json")
        path.write_text(data)
        assert json.loads(invoke("ui", "validate", str(path), "--json"))["valid"]
    stream = root / "report.jsonl"
    stream.write_text(invoke("ui", "stream"))
    assert json.loads(invoke("ui", "validate", str(stream), "--json"))["valid"]
    stream.write_text("\n".join(stream.read_text().splitlines()[:-1]))
    incomplete = subprocess.run([str(cli), "ui", "validate", str(stream), "--json"], text=True, capture_output=True)
    assert incomplete.returncode != 0 and incomplete.stdout == ""
    assert json.loads(incomplete.stderr)["exitCode"] != 0
    # The alias catches local-package identity assumptions and Swift string escaping.
    alias = root / 'local library "quoted"'
    alias.symlink_to(repo, target_is_directory=True)
    feature = root / "AssistantUI"
    invoke("init", "--path", str(feature), "--local-package", str(alias), "--dry-run", "--json")
    assert not feature.exists()
    invoke("init", "--path", str(feature), "--local-package", str(alias))
    sources = feature / "Sources" / "AssistantUI"
    for component in catalog["components"]:
        code = invoke("example", component["id"])
        (sources / component["exampleFile"]).write_text(code)
        for path in component["sourceFiles"]:
            assert (repo / path).is_file(), path
    run("swift", "build", "--package-path", str(feature))

    # Also parse the pinned remote manifest without fetching/executing its code.
    pinned = root / "Pinned"
    revision = run("git", "-C", str(repo), "rev-parse", "HEAD", capture_output=True).stdout.strip()
    invoke("init", "--path", str(pinned), "--revision", revision)
    manifest = json.loads(run("swift", "package", "--package-path", str(pinned), "dump-package", capture_output=True).stdout)
    assert manifest["dependencies"][0]["sourceControl"][0]["requirement"]["revision"] == [revision]

    for folder in [".agents", ".claude"]:
        skill = root / folder / "skills" / "aielements-swiftui"
        invoke("skill", "install", "--path", str(skill))
        assert (skill / "SKILL.md").read_text() == invoke("skill", "print")

    if args.ios:
        run("xcodebuild", "-scheme", "AssistantUI", "-destination", "generic/platform=iOS Simulator",
            "-derivedDataPath", str(root / "DerivedData"), "CODE_SIGNING_ALLOWED=NO", "build", cwd=feature)

print("CLI validation passed: JSON/error contracts, 37 Swift examples, 16 UI documents, complete/incomplete JSONL, generated package, revision pin, and skill installation"
      + ("; macOS + iOS Simulator compilation." if args.ios else "; macOS compilation."))
