#!/bin/sh
# Installs the binary together with its SwiftPM resource bundle. No sudo needed.
set -eu

if [ "$#" -ne 2 ] || [ "$1" != "--prefix" ] || [ -z "$2" ]; then
    echo 'Usage: sh Scripts/install-cli.sh --prefix "$HOME/.local"' >&2
    exit 2
fi
case "$2" in
    /*) prefix=$2 ;;
    *) prefix="$PWD/$2" ;;
esac
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
destination="$prefix/lib/aielements"
launcher="$prefix/bin/aielements"
if [ -e "$destination" ] || [ -L "$destination" ] || [ -e "$launcher" ] || [ -L "$launcher" ]; then
    echo "Refusing to overwrite an existing installation under $prefix. Choose a new prefix." >&2
    exit 2
fi

swift build --package-path "$repo" -c release --product aielements
build=$(swift build --package-path "$repo" -c release --show-bin-path)
bundle="$build/AIElements_AIElementsCLIKit.bundle"
if [ ! -d "$bundle" ]; then
    echo "Missing resource bundle: $bundle" >&2
    exit 1
fi
mkdir -p "$prefix/lib" "$prefix/bin"
staging=$(mktemp -d "$prefix/lib/.aielements-install.XXXXXX")
trap 'rm -rf "$staging"' EXIT HUP INT TERM
cp "$build/aielements" "$staging/aielements"
cp -R "$bundle" "$staging/AIElements_AIElementsCLIKit.bundle"
cp -R "$build/AIElements_AIElementsUIProtocol.bundle" "$staging/AIElements_AIElementsUIProtocol.bundle"
# Test the relocated executable before exposing it through PATH.
"$staging/aielements" list --json > /dev/null
"$staging/aielements" ui stream > /dev/null
# mkdir claims the final directory without overwriting a concurrently created path.
mkdir "$destination"
cp -R "$staging/." "$destination/"
# noclobber also protects an existing launcher if another install raced us.
(set -C; cat > "$launcher" <<'LAUNCHER'
#!/bin/sh
exec "$(dirname -- "$0")/../lib/aielements/aielements" "$@"
LAUNCHER
)
chmod +x "$launcher"
printf 'Installed %s\nAdd %s/bin to PATH if needed.\n' "$launcher" "$prefix"
