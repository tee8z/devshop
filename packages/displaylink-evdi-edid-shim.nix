{ lib
, realLibevdi
, stdenv
}:

stdenv.mkDerivation {
  pname = "displaylink-evdi-edid-shim";
  version = "1.0.0";

  src = ./displaylink-evdi-edid-shim.c;
  dontUnpack = true;

  buildPhase = ''
    runHook preBuild

    cp "$src" displaylink-evdi-edid-shim.c
    $CC -shared -fPIC -O2 -Wall -Wextra \
      -DREAL_LIBEVDI='"${realLibevdi}/lib/libevdi.so"' \
      -Wl,-soname,libevdi.so.1 \
      -o libevdi.so.1 displaylink-evdi-edid-shim.c -ldl

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -D -m 0755 libevdi.so.1 "$out/lib/libevdi.so.1"
    ln -s libevdi.so.1 "$out/lib/libevdi.so"
    ln -s libevdi.so.1 "$out/lib/libevdi.so.0"

    runHook postInstall
  '';

  meta = {
    description = "libevdi forwarding shim for injecting DisplayLink EDID data";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
