{ cacert
, lib
, makeWrapper
, rustPlatform
, viaSrc
}:

rustPlatform.buildRustPackage rec {
  pname = "via-cli";
  version = "0.5.0";

  src = viaSrc;
  cargoHash = "sha256-bNyXrTFTs9574YU1HIf7lJqhvh4o5Uy+/FDV1YgDGc0=";

  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ cacert ];
  SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  postInstall = ''
    wrapProgram $out/bin/via \
      --prefix PATH : /run/wrappers/bin \
      --set-default OP_BIOMETRIC_UNLOCK_ENABLED true
  '';

  meta = {
    description = "Run commands and API requests with 1Password-backed credentials";
    homepage = "https://github.com/tee8z/via";
    license = lib.licenses.mit;
    mainProgram = "via";
    platforms = lib.platforms.linux;
  };
}
