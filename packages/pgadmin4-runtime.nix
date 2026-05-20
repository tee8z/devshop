{ lib
, stdenvNoCC
, electron_40
, makeWrapper
, nodejs
, pgadmin4-desktopmode
, python3
, writeShellScriptBin
, yarn-berry_4
,
}:

let
  pgAdminServer = writeShellScriptBin "pgadmin4-runtime-server" ''
    exec ${lib.getExe pgadmin4-desktopmode}
  '';
in
stdenvNoCC.mkDerivation {
  pname = "pgadmin4-runtime";
  inherit (pgadmin4-desktopmode) version src;

  offlineCache = yarn-berry_4.fetchYarnBerryDeps {
    src = pgadmin4-desktopmode.src + "/runtime";
    hash = "sha256-vOOpeVscLUupSmyDoA1ibB9IUVVjDZZZlQUXWCAYtGw=";
  };

  nativeBuildInputs = [
    makeWrapper
    nodejs
    yarn-berry_4
    yarn-berry_4.yarnBerryConfigHook
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    YARN_ENABLE_SCRIPTS = "0";
  };

  configurePhase = ''
    runHook preConfigure

    cd runtime
    export HOME="$TMPDIR"
    yarnBerryConfigHook

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    yarn install --immutable

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    app_dir="$out/share/pgadmin4-runtime"
    mkdir -p "$app_dir" "$out/bin" "$out/share/applications"
    cp -R assets node_modules package.json src "$app_dir"/

    install -Dm0644 \
      ${pgadmin4-desktopmode}/${python3.sitePackages}/pgadmin4/pgadmin/static/img/logo-256.png \
      "$out/share/icons/hicolor/256x256/apps/pgadmin4.png"

    cat > "$app_dir/dev_config.json" <<EOF
    {
      "pythonPath": "${pgAdminServer}/bin/pgadmin4-runtime-server",
      "pgadminFile": "${pgadmin4-desktopmode}/${python3.sitePackages}/pgadmin4/pgAdmin4.py"
    }
    EOF

    makeWrapper ${lib.getExe electron_40} "$out/bin/pgadmin4-desktop" \
      --chdir "$app_dir" \
      --add-flags "$app_dir"

    cat > "$out/share/applications/org.pgadmin.pgadmin4.desktop" <<EOF
    [Desktop Entry]
    Type=Application
    Version=1.5
    Name=pgAdmin 4
    GenericName=PostgreSQL Administration
    Comment=Administration and development platform for PostgreSQL
    Exec=$out/bin/pgadmin4-desktop
    Icon=pgadmin4
    Terminal=false
    Categories=Development;Database;
    Keywords=PostgreSQL;database;SQL;
    StartupNotify=false
    EOF

    runHook postInstall
  '';

  meta = pgadmin4-desktopmode.meta // {
    description = "pgAdmin 4 desktop runtime application";
    mainProgram = "pgadmin4-desktop";
  };
}
