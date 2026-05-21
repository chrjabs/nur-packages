{
  lib,
  stdenv,
  numactl,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "runsolver";
  version = "3.4.1";

  src = builtins.fetchTarball {
    url = "https://www.cril.univ-artois.fr/~roussel/runsolver/runsolver-${finalAttrs.version}.tar.bz2";
    sha256 = "sha256-875zo6TNWajTWrtIWkfc0Wcy3u1xl745JdPPNQCEGkM=";
  };

  buildInputs = [
    numactl.dev
  ];

  postPatch = ''
    substituteInPlace src/runsolver.cc \
      --replace-fail "numa_node_size(" "numa_node_size64("

    substituteInPlace src/Makefile \
      --replace-fail '$(INSTROOT)/usr/bin' '$(INSTROOT)/bin/'
  '';

  preBuild = ''
    cd src
  '';

  preInstall = ''
    mkdir -p $out/bin
  '';

  makeFlags = [ "INSTROOT=$(out)" ];

  meta = {
    description = "Controlling a Solver Execution";
    homepage = "https://www.cril.univ-artois.fr/~roussel/runsolver/";
    license = with lib.licenses; [
      gpl3
    ];
    maintainers = [ (import ../../maintainer.nix { inherit (lib) maintainers; }) ];
    mainProgram = "runsolver";
  };
})
