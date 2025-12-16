{
  lib,
  stdenv,
  rustPlatform,
  rustc,
  fetchFromGitHub,
  wasm-pack,
  wasm-bindgen-cli_0_2_105,
  pkg-config,
  openssl,
  cmake,
}:
let
  targetTriple = {
    x86_64-linux = "x86_64-unknown-linux-gnu";
    aarch64-linux = "aarch64-unknown-linux-gnu";
    x86_64-darwin = "x86_64-apple-darwin";
    aarch64-darwin = "aarch64-apple-darwin";
  };
  target = targetTriple.${stdenv.hostPlatform.system};
  libExt = if stdenv.isDarwin then "dylib" else "so";
in
rustPlatform.buildRustPackage rec {
  pname = "dodeca";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "bearcove";
    repo = "dodeca";
    rev = "v${version}";
    hash = "sha256-r25YTH/nRWgIBlFiw8cTpcUEpV6QmOsxdPa2UOd/w0M=";
  };

  cargoHash = "sha256-XSWCLgefQRqnhLuOn1qv5stmjQgoj2915e8gTORJQb0=";

  cargoPatches = [
    ./make-build-work.patch
  ];

  buildInputs = [ openssl ];
  nativeBuildInputs = [
    wasm-pack
    wasm-bindgen-cli_0_2_105
    rustc.llvmPackages.lld
    pkg-config
    cmake
  ];

  buildPhase = ''
    runHook preBuild

    # Build WASM
    cargo build -p livereload-client -p dodeca-devtools --target wasm32-unknown-unknown --release
    wasm-bindgen --target web --out-dir crates/livereload-client/pkg target/wasm32-unknown-unknown/release/livereload_client.wasm
    wasm-bindgen --target web --out-dir crates/dodeca-devtools/pkg target/wasm32-unknown-unknown/release/dodeca_devtools.wasm

    # Build main binaries
    bash scripts/build-target.sh ${target}

    runHook postBuild
  '';

  doCheck = false;

  installPhase = ''
    runHook preInstall

    # Auto-discover plugins (crates with cdylib in Cargo.toml)
    PLUGINS=()
    for dir in crates/dodeca-*/; do
        if [[ -f "$dir/Cargo.toml" ]] && grep -q "cdylib" "$dir/Cargo.toml"; then
            plugin=$(basename "$dir")
            # Convert crate name to lib name (dodeca-foo -> dodeca_foo)
            lib_name="''${plugin//-/_}"
            PLUGINS+=("$lib_name")
        fi
    done

    mkdir -p $out/bin/plugins
    cp "target/${target}/release/ddc" $out/bin/
    # Copy plugins
    for plugin in "''${PLUGINS[@]}"; do
        PLUGIN_FILE="lib$plugin.${libExt}"
        SRC="target/${target}/release/$PLUGIN_FILE"
        if [[ -f "$SRC" ]]; then
            cp "$SRC" $out/bin/plugins/
        else
            echo "Warning: Plugin not found: $SRC"
        fi
    done

    runHook postInstall
  '';

  meta = {
    description = "A salsa-infused static site generator ";
    homepage = "https://dodeca.bearcove.eu/";
    changelog = "github.com/bearcove/dodeca/blob/${src.rev}/CHANGELOG.md";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = [ (import ../../maintainer.nix { inherit (lib) maintainers; }) ];
    mainProgram = "ddc";
  };
}
