{ cacert
, lib
, makeWrapper
, rustPlatform
, viaSrc
}:

rustPlatform.buildRustPackage rec {
  pname = "via-cli";
  version = "0.6.1";

  src = viaSrc;
  cargoHash = "sha256-zmQOLhLlvQ26TE4YO8KpH5MXuzPI3GS66ncCGkuXmao=";

  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ cacert ];
  SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  postInstall = ''
    wrapProgram $out/bin/via \
      --prefix PATH : /run/wrappers/bin \
      --set-default OP_BIOMETRIC_UNLOCK_ENABLED true
  '';

  meta = {
    description = "Run commands, SSH sessions, and API requests with 1Password-backed credentials";
    homepage = "https://github.com/tee8z/via";
    license = lib.licenses.mit;
    mainProgram = "via";
    platforms = lib.platforms.linux;
  };
}
