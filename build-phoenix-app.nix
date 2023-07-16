(
  {
    pkgs,
    pname,
    src,
    version,
    mixDepsSha256,
    tailwind ? pkgs.tailwindcss,
    esbuild ? pkgs.esbuild,
    tailwindPath ? "_build/tailwind-x86_64-linux",
    esbuildPath ? "_build/esbuild-x86_64-linux",
    erlangVersion ? "erlangR25",
    elixirVersion ? "elixir_1_14",
    beamPkgs ?
      with pkgs.beam_minimal;
        packagesWith (interpreters.${erlangVersion}.override {
          configureFlags = [
            "--without-debugger"
            "--without-et"
            "--without-megaco"
            "--without-observer"
            "--without-termcap"
            "--without-wx"
          ];
          installTargets = ["install"];
        }),
    elixir ? beamPkgs.${elixirVersion},
    erlang ? beamPkgs.erlang,
    fetchMixDeps ? beamPkgs.fetchMixDeps.override {inherit elixir;},
    mixRelease ? beamPkgs.mixRelease.override {inherit elixir erlang fetchMixDeps;},
    mixFodDeps ?
      fetchMixDeps {
        inherit version src;
        pname = "${pname}-elixir-deps";
        sha256 = mixDepsSha256;
      },
  }:
    mixRelease {
      inherit src pname version mixFodDeps;

      postBuild = ''
        install ${tailwind}/bin/tailwindcss ${tailwindPath}
        install ${esbuild}/bin/esbuild ${esbuildPath}
        cp -a ../deps ./
        mix assets.deploy
      '';
    }
)
