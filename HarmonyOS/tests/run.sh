#!/bin/sh
set -eu
harmony_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT HUP INT TERM

python3 "$harmony_dir/sync-fixtures.py" --check
npm exec --yes --package=typescript@5.8.3 -- tsc --strict --target es2020 --module commonjs \
  --outDir "$scratch" "$harmony_dir/aielements/src/main/ets/protocol/Store.ts" \
  "$harmony_dir/aielements/src/main/ets/ui/Surface.ts" "$harmony_dir/aielements/src/main/ets/ui/Markdown.ts" \
  "$harmony_dir/aielements/src/main/ets/ui/ChartGeometry.ts" "$harmony_dir/aielements/src/main/ets/shadcn/TableRows.ts"
AI_ELEMENTS_TEST_BUILD="$scratch" node --test "$harmony_dir/tests/protocol.test.cjs"
