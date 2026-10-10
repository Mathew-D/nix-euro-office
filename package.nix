{
  stdenv,
  lib,
  fetchurl,
  buildFHSEnv,
  autoPatchelfHook,
  makeWrapper,
  patchelfUnstable,
  qt6,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  atk,
  cairo,
  curl,
  dbus,
  dconf,
  firebird,
  fontconfig,
  gcc-unwrapped,
  gdk-pixbuf,
  glib,
  glibc,
  gsettings-desktop-schemas,
  gst_all_1,
  gtk2,
  gtk3,
  libGL,
  libdrm,
  libgbm,
  libmysqlclient,
  libnotify,
  libpulseaudio,
  libudev0-shim,
  libx11,
  libxcb,
  libxcb-cursor,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxtst,
  noto-fonts-cjk-sans,
  nspr,
  nss,
  pulseaudio,
  pipewire,
  xkeyboard_config,
}:
let
  version = "9.3.5-2";

  srcBySystem = {
    x86_64-linux = {
      asset = "euro-office-euro-office-${version}-x86_64.tar.xz";
      hash = "sha256-yEbT7KDslMn9H/4js/jQT3DrFYxzMsv6QmBW7KkyvFY=";
    };
    aarch64-linux = {
      asset = "euro-office-euro-office-${version}-aarch64.tar.xz";
      hash = "sha256-6ssDFIRWtFJEenYw7eloa5RZF3fFVx0IhRaZAGXH/ms=";
    };
  };

  srcSpec =
    srcBySystem.${stdenv.hostPlatform.system}
      or (throw "Unsupported system for euro-office-desktopeditors: ${stdenv.hostPlatform.system}");

  runtimeLibs = lib.makeLibraryPath [
    curl
    glibc
    gcc-unwrapped.lib
    libudev0-shim
    pulseaudio
  ];

  derivation = stdenv.mkDerivation {
    pname = "euro-office-desktopeditors";
    inherit version;

    src = fetchurl {
      url = "https://github.com/Euro-Office/DesktopEditors/releases/download/v${version}/${srcSpec.asset}";
      hash = srcSpec.hash;
    };

    sourceRoot = ".";

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
      patchelfUnstable
      wrapGAppsHook3
    ];

    buildInputs = [
      alsa-lib
      at-spi2-atk
      atk
      cairo
      dbus
      dconf
      firebird
      fontconfig
      gdk-pixbuf
      glib
      gsettings-desktop-schemas
      gst_all_1.gst-plugins-base
      gst_all_1.gstreamer
      gtk2
      gtk3
      libdrm
      libgbm
      libmysqlclient
      libnotify
      libpulseaudio
      libx11
      libxcb
      libxcb-cursor
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxscrnsaver
      libxtst
      nspr
      nss
      qt6.qtbase
      qt6.qtdeclarative
      qt6.qtquick3d
      qt6.qtsvg
      qt6.qtwayland
    ];

    dontWrapQtApps = true;
    dontStrip = true;

    autoPatchelfIgnoreMissingDeps = [
      "libmysqlclient.so.21"
      "libclntsh.so.23.1"
      "libmimerapi.so"
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/{bin,lib,share}

      cp -r usr/bin/* $out/bin/
      cp -r usr/share/* $out/share/
      cp -r opt/euro-office/euro-office $out/share/

      chmod 0755 $out/bin/euro-office-euro-office
      chmod 0755 $out/share/euro-office/DesktopEditors

      substituteInPlace $out/bin/euro-office-euro-office \
        --replace-fail "/opt/euro-office/" "$out/share/"

      ln -s $out/bin/euro-office-euro-office $out/bin/euro-office-desktopeditors
      ln -s $out/share/euro-office/DesktopEditors $out/bin/DesktopEditors

      runHook postInstall
    '';

    preFixup = ''
      gappsWrapperArgs+=(
        --prefix LD_LIBRARY_PATH : "${runtimeLibs}" \
        --set QT_XKB_CONFIG_ROOT "${xkeyboard_config}/share/X11/xkb" \
        --set QTCOMPOSE "${libx11.out}/share/X11/locale" \
        --set-default QT_QPA_PLATFORM "wayland;xcb" \
        --set QT_STYLE_OVERRIDE "Fusion"
      )
    '';

    meta = {
      description = "Euro-Office desktop editors";
      homepage = "https://github.com/Euro-Office/DesktopEditors";
      downloadPage = "https://github.com/Euro-Office/DesktopEditors/releases";
      changelog = "https://github.com/Euro-Office/DesktopEditors/releases/tag/v${version}";
      license = lib.licenses.agpl3Plus;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = builtins.attrNames srcBySystem;
      mainProgram = "euro-office-desktopeditors";
    };
  };
in
buildFHSEnv {
  inherit (derivation) pname version;

  extraPreBwrapCmds = ''
    # Euro-Office scans ~/.local/share/fonts. Build a merged cache there
    # (system + user fonts) with real files for reliable discovery.
    host_font_dir=""
    if [[ -d /run/current-system/sw/share/X11/fonts ]]; then
      host_font_dir=/run/current-system/sw/share/X11/fonts
    elif [[ -d /run/current-system/sw/share/fonts ]]; then
      host_font_dir=/run/current-system/sw/share/fonts
    fi

    if [[ -n "$host_font_dir" ]]; then
      cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}/euro-office-desktopeditors"
      merged_fonts="$cache_root/merged-local-fonts"
      stamp_file="$cache_root/merged-local-fonts.source"
      user_font_dir="$HOME/.local/share/fonts"
      host_id="$(readlink -f "$host_font_dir")"

      # Invalidate merged cache when user font files change.
      if [[ -d "$user_font_dir" ]]; then
        user_stamp="$(find "$user_font_dir" -maxdepth 1 -type f -printf '%f:%T@\n' 2>/dev/null | sort | sha256sum | cut -d' ' -f1)"
      else
        user_stamp="none"
      fi
      source_id="$host_id:$user_stamp"

      mkdir -p "$cache_root"
      if [[ ! -d "$merged_fonts" ]] || [[ ! -f "$stamp_file" ]] || [[ "$(cat "$stamp_file" 2>/dev/null)" != "$source_id" ]]; then
        rm -rf "$merged_fonts"
        mkdir -p "$merged_fonts"
        cp -Lr "$host_font_dir"/. "$merged_fonts"/
        if [[ -d "$user_font_dir" ]]; then
          cp -Lr "$user_font_dir"/. "$merged_fonts"/ 2>/dev/null || true
        fi

        # Force font list regeneration when source fonts change.
        rm -f "$HOME/.local/share/euro-office/desktopeditors/data/fonts/AllFonts.js"*
        rm -f "$HOME/.local/share/euro-office/desktopeditors/data/fonts/font_selection.bin"
        rm -f "$HOME/.local/share/euro-office/desktopeditors/data/fonts/fonts.log"
        rm -f "$HOME/.local/share/euro-office/desktopeditors/data/fonts/fonts_thumbnail"*
        printf '%s\n' "$source_id" > "$stamp_file"
      fi
    fi

  '';

  extraBwrapArgs = [
    # Apply late to win over the automatic /home bind mount.
    "--ro-bind-try"
    "/home/$USER/.cache/euro-office-desktopeditors/merged-local-fonts"
    "/home/$USER/.local/share/fonts"
  ];

  targetPkgs =
    pkgs: [
      curl
      derivation
      noto-fonts-cjk-sans
      libGL
      pipewire
    ];

  runScript = "/bin/euro-office-desktopeditors";

  extraInstallCommands = ''
    mkdir -p $out/share
    ln -s ${derivation}/share/icons $out/share
    cp -r ${derivation}/share/applications $out/share
    chmod -R u+w $out/share/applications
    substituteInPlace $out/share/applications/euro-office-euro-office.desktop \
      --replace-fail "/usr/bin/euro-office-euro-office" "$out/bin/euro-office-desktopeditors"
    sed -i \
      -e 's#^StartupWMClass=.*#StartupWMClass=DesktopEditors#' \
      -e '/^StartupWMClass=/!a StartupWMClass=DesktopEditors' \
      $out/share/applications/euro-office-euro-office.desktop
    sed -i '/^X-GNOME-WMClass=/d' $out/share/applications/euro-office-euro-office.desktop
    sed -i '/^StartupWMClass=/a X-GNOME-WMClass=DesktopEditors' $out/share/applications/euro-office-euro-office.desktop
  '';

  meta = derivation.meta // {
    # Keep desktop name aligned with upstream app metadata.
    description = "Office suite with document, spreadsheet and presentation editors";
  };
}