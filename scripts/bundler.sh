#!/bin/bash

# Copyright (C) Contributors to the Suwayomi project
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

main() {
  POSITIONAL_ARGS=()
  OUTPUT_DIR=.
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -o|--output-dir)
        OUTPUT_DIR="$(readlink -e "$2" || exit 1)"
        shift
        shift
        ;;
      *)
        POSITIONAL_ARGS+=("$1")
        shift
        ;;
    esac
  done
  # restore positional parameters
  set -- "${POSITIONAL_ARGS[@]}"

  OS="$1"
  JAR="$(ls server/build/*.jar | tail -n1)"
  RELEASE_NAME="$(echo "${JAR%.*}" | xargs basename)-$OS"
  RELEASE_VERSION="$(tmp="${JAR%-*}"; echo "${tmp##*-}" | tr -d v)"
  #RELEASE_REVISION_NUMBER="$(tmp="${JAR%.*}" && echo "${tmp##*-}" | tr -d r)"
  local electron_version="v14.0.0"

  # clean temporary directory on function return
  trap "rm -rf $RELEASE_NAME/" RETURN
  mkdir "$RELEASE_NAME/"

  case "$OS" in
    debian-all)
      RELEASE="$RELEASE_NAME.deb"
      make_deb_package
      move_release_to_output_dir
      ;;
    linux-assets)
      RELEASE="$RELEASE_NAME.tar.gz"
      copy_linux_package_assets_to "$RELEASE_NAME/"
      tar -I "gzip -9" -cvf "$RELEASE" "$RELEASE_NAME/"
      move_release_to_output_dir
      ;;
    linux-x64)
      JRE="OpenJDK8U-jre_x64_linux_hotspot_8u302b08.tar.gz"
      JRE_URL="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u302-b08/$JRE"
      ELECTRON="electron-$electron_version-linux-x64.zip"
      ELECTRON_URL="https://github.com/electron/electron/releases/download/$electron_version/$ELECTRON"
      download_jre_and_electron

      RELEASE="$RELEASE_NAME.tar.gz"
      make_linux_bundle
      move_release_to_output_dir
      ;;
    macOS-x64)
      JRE="OpenJDK8U-jre_x64_mac_hotspot_8u302b08.tar.gz"
      JRE_URL="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u302-b08/$JRE"
      ELECTRON="electron-$electron_version-darwin-x64.zip"
      ELECTRON_URL="https://github.com/electron/electron/releases/download/$electron_version/$ELECTRON"
      download_jre_and_electron

      RELEASE="$RELEASE_NAME.zip"
      make_macos_bundle
      move_release_to_output_dir
      ;;
    macOS-arm64)
      JRE="zulu8.56.0.23-ca-jre8.0.302-macosx_aarch64.tar.gz"
      JRE_URL="https://cdn.azul.com/zulu/bin/$JRE"
      ELECTRON="electron-$electron_version-darwin-arm64.zip"
      ELECTRON_URL="https://github.com/electron/electron/releases/download/$electron_version/$ELECTRON"
      download_jre_and_electron

      RELEASE="$RELEASE_NAME.zip"
      make_macos_bundle
      move_release_to_output_dir
      ;;
    windows-x86)
      JRE="OpenJDK8U-jre_x86-32_windows_hotspot_8u292b10.zip"
      JRE_URL="https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u292-b10/$JRE"
      ELECTRON="electron-$electron_version-win32-ia32.zip"
      ELECTRON_URL="https://github.com/electron/electron/releases/download/$electron_version/$ELECTRON"
      download_jre_and_electron

      RELEASE="$RELEASE_NAME.zip"
      make_windows_bundle
      move_release_to_output_dir

      RELEASE="$RELEASE_NAME.msi"
      make_windows_package
      move_release_to_output_dir
      ;;
    windows-x64)
      JRE="OpenJDK8U-jre_x64_windows_hotspot_8u302b08.zip"
      JRE_URL="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u302-b08/$JRE"
      ELECTRON="electron-$electron_version-win32-x64.zip"
      ELECTRON_URL="https://github.com/electron/electron/releases/download/$electron_version/$ELECTRON"
      download_jre_and_electron

      RELEASE="$RELEASE_NAME.zip"
      make_windows_bundle
      move_release_to_output_dir

      RELEASE="$RELEASE_NAME.msi"
      make_windows_package
      move_release_to_output_dir
      ;;
    *)
      error $LINENO "Unsupported operating system: $OS" 2
      ;;
  esac
}

move_release_to_output_dir() {
   # clean up from possible previous runs
   if [ -f "$OUTPUT_DIR/$RELEASE" ]; then
     rm "$OUTPUT_DIR/$RELEASE"
   fi
   mv "$RELEASE" "$OUTPUT_DIR/"
}

download_jre_and_electron() {
  if [ ! -f "$JRE" ]; then
    curl -L "$JRE_URL" -o "$JRE"
  fi
  if [ ! -f "$ELECTRON" ]; then
    curl -L "$ELECTRON_URL" -o "$ELECTRON"
  fi

  mkdir -p "$RELEASE_NAME/jre/"
  local ext="${JRE##*.}"
  local jre_dir
  if [ "$ext" = "zip" ]; then
    jre_dir="$(unzip "$JRE" | sed -n '2p' | cut -d: -f2 | xargs basename)"
    mv -T "$jre_dir" "$RELEASE_NAME/jre"
  else
    # --strip-components=1: untar an archive without the root folder
    tar xvf "$JRE" --strip-components=1 -C "$RELEASE_NAME/jre/"
  fi
  unzip "$ELECTRON" -d "$RELEASE_NAME/electron/"
}

copy_linux_package_assets_to() {
  local output_dir
  output_dir="$(readlink -e "$1" || exit 1)"

  cp "scripts/resources/pkg/tachidesk-server-browser-launcher.sh" "$output_dir/"
  cp "scripts/resources/pkg/tachidesk-server-debug-launcher.sh" "$output_dir/"
  cp "scripts/resources/pkg/tachidesk-server-electron-launcher.sh" "$output_dir/"
  cp "scripts/resources/pkg/tachidesk-server.desktop" "$output_dir/"
  cp "scripts/resources/pkg/systemd"/* "$output_dir/"
  cp "server/src/main/resources/icon/faviconlogo.png" \
    "$output_dir/tachidesk-server.png"
}

make_linux_bundle() {
  cp "$JAR" "$RELEASE_NAME/Tachidesk-Server.jar"
  cp "scripts/resources/tachidesk-server-browser-launcher.sh" "$RELEASE_NAME/"
  cp "scripts/resources/tachidesk-server-debug-launcher.sh" "$RELEASE_NAME/"
  cp "scripts/resources/tachidesk-server-electron-launcher.sh" "$RELEASE_NAME/"

  tar -I "gzip -9" -cvf "$RELEASE" "$RELEASE_NAME/"
}

make_macos_bundle() {
  cp "$JAR" "$RELEASE_NAME/Tachidesk-Server.jar"
  cp "scripts/resources/Tachidesk Browser Launcher.command" "$RELEASE_NAME/"
  cp "scripts/resources/Tachidesk Debug Launcher.command" "$RELEASE_NAME/"
  cp "scripts/resources/Tachidesk Electron Launcher.command" "$RELEASE_NAME/"

  zip -9 -r "$RELEASE" "$RELEASE_NAME/"
}

# https://wiki.debian.org/SimplePackagingTutorial
# https://www.debian.org/doc/manuals/packaging-tutorial/packaging-tutorial.pdf
make_deb_package() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap "rm -rf $temp_dir" RETURN

  cp "$JAR" "$RELEASE_NAME/Tachidesk-Server.jar"
  tar -I "gzip" -cvf "$RELEASE_NAME.tar.gz" "$RELEASE_NAME/"
  #behind $RELEASE_VERSION is underscore "_"
  local upstream_source="tachidesk-server_$RELEASE_VERSION.orig.tar.gz"
  mv "$RELEASE_NAME.tar.gz" "$temp_dir/$upstream_source"

  cp -r "scripts/resources/deb/" "$RELEASE_NAME/debian/"
  copy_linux_package_assets_to "$RELEASE_NAME/debian/"
  sed -i "s/\$pkgver/$RELEASE_VERSION/" "$RELEASE_NAME/debian/changelog"
  sed -i "s/\$pkgrel/1/"                "$RELEASE_NAME/debian/changelog"
  #behind $RELEASE_VERSION is hyphen "-"
  local source_dir="tachidesk-server-$RELEASE_VERSION"
  mv "$RELEASE_NAME/" "$temp_dir/$source_dir/"

  sudo apt install devscripts build-essential dh-exec
  cd "$temp_dir/$source_dir/"
  dpkg-buildpackage --no-sign --build=all
  cd -

  local deb="tachidesk-server_$RELEASE_VERSION-1_all.deb"
  mv "$temp_dir/$deb" "$RELEASE"
}

make_windows_bundle() {
  ## I disabled this section until someone find a solution to this error:
  ##E: Unable to correct problems, you have held broken packages.
  ##./bundler.sh: line 250: wine: command not found

  ## check if running under github actions
  #if [ "$CI" = true ]; then
    ## change electron executable's icon
    #sudo dpkg --add-architecture i386
    #wget -qO - https://dl.winehq.org/wine-builds/winehq.key \
        #| sudo apt-key add -
    #sudo add-apt-repository ppa:cybermax-dexter/sdl2-backport
    #sudo apt-add-repository "deb https://dl.winehq.org/wine-builds/ubuntu \
        #$(lsb_release -cs) main"
    #sudo apt install --install-recommends winehq-stable
  #fi
  ## this script assumes that wine is installed here on out

  #local rcedit="rcedit-x85.exe"
  #local rcedit_url="https://github.com/electron/rcedit/releases/download/v0.1.1/$rcedit"
  ## change electron's icon
  #if [ ! -f "$rcedit" ]; then
    #curl -L "$rcedit_url" -o "$rcedit"
  #fi

  #local icon="server/src/main/resources/icon/faviconlogo.ico"
  #WINEARCH=win32 wine "$rcedit" "$RELEASE_NAME/electron/electron.exe" \
  #    --set-icon "$icon"

  cp "$JAR" "$RELEASE_NAME/Tachidesk-Server.jar"
  cp "scripts/resources/Tachidesk Browser Launcher.bat" "$RELEASE_NAME"
  cp "scripts/resources/Tachidesk Debug Launcher.bat" "$RELEASE_NAME"
  cp "scripts/resources/Tachidesk Electron Launcher.bat" "$RELEASE_NAME"

  zip -9 -r "$RELEASE" "$RELEASE_NAME"
}

make_windows_package() {
  if [ "$CI" = true ]; then
    sudo apt install -y wixl
  fi

  find "$RELEASE_NAME/jre" \
  | wixl-heat --var var.SourceDir -p "$RELEASE_NAME/" \
    --directory-ref jre --component-group jre >"$RELEASE_NAME/jre.wxs"
  find "$RELEASE_NAME/electron" \
  | wixl-heat --var var.SourceDir -p "$RELEASE_NAME/" \
    --directory-ref electron --component-group electron >"$RELEASE_NAME/electron.wxs"

  local icon="server/src/main/resources/icon/faviconlogo.ico"
  local arch=${OS##*-}

  wixl -D ProductVersion="$RELEASE_VERSION" -D SourceDir="$RELEASE_NAME" \
    -D Icon="$icon" --arch "$arch" "scripts/resources/msi/tachidesk-server-$arch.wxs" \
    "$RELEASE_NAME/jre.wxs" "$RELEASE_NAME/electron.wxs" -o "$RELEASE"
}

# Error handler
# set -u: Treat unset variables as an error when substituting.
# set -o pipefail: Prevents errors in pipeline from being masked.
# set -e: Immediatly exit if any command has a non-zero exit status.
# set -E: Inherit the trap ERR function before exiting by set.
#
# set -e is not recommended and unpredictable.
# see https://stackoverflow.com/questions/64786/error-handling-in-bash
# and http://mywiki.wooledge.org/BashFAO/105
set -uo pipefail
error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  if [ -z "$message" ]; then
      echo "$0: line $parent_lineno: exiting with status $code"
  else
      echo "$0: line $parent_lineno: $message: exiting with status $code"
  fi
  exit "$code"
}
trap 'error $LINENO ""' ERR

main "$@"; exit

