#!/bin/zsh

set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)

# The app's name people see: the .app, Finder, Login Items, the Settings
# title and every sentence that names the app (AppInfo.name reads it from the
# bundle). Change it here, or with AGENTBAR_APP_NAME, to rename the app.
# Internal names (bundle ID, ~/.agentbar data, agent-bar module) stay fixed so a
# rename keeps settings and accounts.
app_name="${AGENTBAR_APP_NAME:-Limi}"
bundle_name="$app_name.app"
bundle_path="$repo_dir/$bundle_name"
install_dir="$HOME/Applications"
install_path="$install_dir/$bundle_name"
build_configuration="release"
should_install=0
signing_identity="${AGENTBAR_CODE_SIGN_IDENTITY:-}"
# Pro unless asked otherwise. Free and Pro ship through different channels;
# the edition is compiled in (AGENTBAR_FREE), see Sources/agent-bar/Core/AppEdition.swift.
edition="pro"
usage="Usage: ./scripts/build-app.sh [--install] [--edition free|pro]"

while (( $# > 0 )); do
  case "$1" in
    --install)
      should_install=1
      ;;
    --edition)
      shift
      edition="${1:-}"
      ;;
    --edition=*)
      edition="${1#--edition=}"
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "$usage" >&2
      exit 1
      ;;
  esac
  shift
done

edition_flags=()
case "$edition" in
  pro) ;;
  free) edition_flags=(-Xswiftc -DAGENTBAR_FREE) ;;
  *)
    echo "Unknown edition: $edition" >&2
    echo "$usage" >&2
    exit 1
    ;;
esac

echo "Building agent-bar ($build_configuration, $edition edition)..."
swift build -c "$build_configuration" --product agent-bar "${edition_flags[@]}"

bin_dir=$(swift build -c "$build_configuration" --show-bin-path)
binary_path="$bin_dir/agent-bar"

if [[ ! -x "$binary_path" ]]; then
  echo "Built binary not found: $binary_path" >&2
  exit 1
fi

echo "Creating app bundle at $bundle_path"
rm -rf "$bundle_path"
mkdir -p "$bundle_path/Contents/MacOS"
mkdir -p "$bundle_path/Contents/Resources"

cp "$binary_path" "$bundle_path/Contents/MacOS/agent-bar"
# App icon; regenerate with scripts/make-app-icons.sh. The free edition's
# wears a FREE ribbon.
icon_file="AppIcon.icns"
if [[ "$edition" == "free" ]]; then icon_file="AppIcon-Free.icns"; fi
cp "$repo_dir/assets/$icon_file" "$bundle_path/Contents/Resources/AppIcon.icns"
# Korean UI; English is the text in the code. See assets/ko.lproj.
cp -R "$repo_dir/assets/ko.lproj" "$bundle_path/Contents/Resources/ko.lproj"
mkdir -p "$bundle_path/Contents/Resources/en.lproj"

cat > "$bundle_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>ko</string>
  </array>
  <key>CFBundleDisplayName</key>
  <string>APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>agent-bar</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>dev.chenjing.agent-bar</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.3.0</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

# APP_NAME above stands for the app name; set it from app_name.
plutil -replace CFBundleName -string "$app_name" "$bundle_path/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "$app_name" "$bundle_path/Contents/Info.plist"
# Antigravity's local language server answers plain HTTP on 127.0.0.1.
plutil -insert NSAppTransportSecurity -json '{"NSAllowsLocalNetworking":true}' "$bundle_path/Contents/Info.plist"

printf 'APPL????' > "$bundle_path/Contents/PkgInfo"

# Where the free edition's PRO badges and menu link send people to buy Pro.
# Without it they show, but the link waits for a purchase page.
if [[ -n "${AGENTBAR_PURCHASE_URL:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Add :AgentBarPurchaseURL string $AGENTBAR_PURCHASE_URL" "$bundle_path/Contents/Info.plist"
fi

if [[ -z "$signing_identity" ]]; then
  for candidate in "FreshRestart Local Code Signing" "Screen Translate Local Code Signing"; do
    if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"$candidate\""; then
      signing_identity="$candidate"
      break
    fi
  done
fi
if [[ -z "$signing_identity" ]]; then signing_identity="-"; fi
echo "Signing with: $signing_identity"
codesign --force --deep -s "$signing_identity" "$bundle_path" >/dev/null

if [[ "$should_install" -eq 1 ]]; then
  umask 077
  mkdir -p "$install_dir"
  backup_dir="$HOME/Library/Application Support/AgentBar/Backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup_dir"
  if [[ -d "$install_path" ]]; then
    ditto "$install_path" "$backup_dir/$bundle_name"
  fi
  defaults export dev.chenjing.agent-bar "$backup_dir/settings.plist" >/dev/null 2>&1 || true
  if [[ -d "$HOME/.agentbar/multi-account-v1" ]]; then
    ditto "$HOME/.agentbar/multi-account-v1" "$backup_dir/multi-account-v1"
  fi
  staging_dir=$(mktemp -d "$install_dir/.AgentBar-install.XXXXXX")
  ditto "$bundle_path" "$staging_dir/new.app"
  codesign --verify --deep --strict "$staging_dir/new.app"
  if [[ -d "$install_path" ]]; then
    # The installer requires the running app to be closed before replacement.
    if pgrep -f "^$install_path/Contents/MacOS/agent-bar$" >/dev/null; then
      echo "$app_name is still running; installation stopped. Backup: $backup_dir" >&2
      exit 1
    fi
    mv "$install_path" "$staging_dir/previous.app"
  fi
  if ! mv "$staging_dir/new.app" "$install_path"; then
    if [[ -d "$staging_dir/previous.app" ]]; then mv "$staging_dir/previous.app" "$install_path"; fi
    echo "Installation failed; previous app restored. Backup: $backup_dir" >&2
    exit 1
  fi
  rm -rf "$staging_dir"
  echo "Backup: $backup_dir"
  echo "Installed to $install_path"
else
  echo "Built $bundle_path"
fi

echo "You can launch it with:"
if [[ "$should_install" -eq 1 ]]; then
  echo "open \"$install_path\""
else
  echo "open \"$bundle_path\""
fi
