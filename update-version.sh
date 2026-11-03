#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_dir"

api_url="https://api.github.com/repos/Euro-Office/DesktopEditors/releases/latest"
latest_json="$(mktemp)"
tmp_dir="$(mktemp -d)"
cleanup() {
  rm -f "$latest_json"
  if [[ -n "${tmp_dir:-}" && -d "$tmp_dir" ]]; then
    rm -rf "$tmp_dir"
  fi
}
trap cleanup EXIT

curl -fsSL -H "Accept: application/vnd.github+json" -H "User-Agent: nix-euro-office-updater" "$api_url" > "$latest_json"

tag_name="$(python3 - "$latest_json" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
print(data.get('tag_name', '').strip())
PY
)"

if [[ -z "$tag_name" ]]; then
  echo "Failed to determine the latest upstream release tag." >&2
  exit 1
fi

version="${tag_name#v}"

python3 - "$latest_json" "$repo_dir" "$version" "$tmp_dir" <<'PY'
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

latest_json = Path(sys.argv[1])
repo_dir = Path(sys.argv[2])
version = sys.argv[3]

download_dir = Path(sys.argv[4])

with latest_json.open('r', encoding='utf-8') as handle:
    data = json.load(handle)

assets = data.get('assets', [])
linux_assets = [
    asset['name']
    for asset in assets
    if asset.get('name', '').endswith('.tar.xz') and ('x86_64' in asset.get('name', '') or 'aarch64' in asset.get('name', ''))
]

if len(linux_assets) < 2:
    raise SystemExit('No suitable Linux tar.xz assets found in the latest release.')

asset_x86 = next(name for name in linux_assets if 'x86_64' in name)
asset_aarch = next(name for name in linux_assets if 'aarch64' in name)

download_url = f"https://github.com/Euro-Office/DesktopEditors/releases/download/{data['tag_name']}/"

def fetch_asset(asset_name: str) -> str:
    target = download_dir / asset_name
    target.parent.mkdir(parents=True, exist_ok=True)
    url = download_url + asset_name
    with urllib.request.urlopen(url) as response, open(target, 'wb') as out:
        out.write(response.read())
    return str(target)

x86_path = fetch_asset(asset_x86)
aarch_path = fetch_asset(asset_aarch)

x86_hash = subprocess.check_output(['nix', 'hash', 'file', x86_path], text=True).strip()
aarch_hash = subprocess.check_output(['nix', 'hash', 'file', aarch_path], text=True).strip()

package_path = repo_dir / 'package.nix'
text = package_path.read_text(encoding='utf-8')

text = re.sub(
    r'(?m)^(\s*version\s*=\s*")[^"]+(";)',
    rf'\1{version}\2',
    text,
    count=1,
)

src_block = f'''  srcBySystem = {{
    x86_64-linux = {{
      asset = "{asset_x86}";
      hash = "{x86_hash}";
    }};
    aarch64-linux = {{
      asset = "{asset_aarch}";
      hash = "{aarch_hash}";
    }};
  }};'''

text, count = re.subn(
    r'(?ms)^\s*srcBySystem\s*=\s*\{.*?^\s*\};',
    src_block,
    text,
    count=1,
)
if count != 1:
    raise SystemExit('Unable to update the srcBySystem block in package.nix.')

package_path.write_text(text, encoding='utf-8')

print(f'Updated package to v{version}')
print(f'  x86_64 asset: {asset_x86}')
print(f'  aarch64 asset: {asset_aarch}')
PY

# Keep the script output straightforward for future automation.
printf '\nPackage version updated to %s.\n' "$version"
printf 'Run: nix build .#euro-office-desktopeditors --dry-run\n'