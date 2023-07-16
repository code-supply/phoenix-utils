{self}: {
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
}: {
  inherit elixir erlang tailwind esbuild;
  app = mixRelease {
    inherit src pname version mixFodDeps;

    postUnpack = ''
      tailwind_version="$(${elixir}/bin/elixir ${self}/extract_version.ex ${src}/config/config.exs tailwind)"
      esbuild_version="$(${elixir}/bin/elixir ${self}/extract_version.ex ${src}/config/config.exs esbuild)"

      errors=0

      if [[ -z "$tailwind_version" ]]
      then
        echo "No Tailwind version found in config/config.exs - continuing without Tailwind."
      elif [[ "$tailwind_version" != "${tailwind.version}" ]]
      then
        errors+=1
        echo "error: Tailwind version mismatch: using ${tailwind.version} from nix but $tailwind_version in your app!"
      fi

      if [[ -z "$esbuild_version" ]]
      then
        echo "No esbuild version found in config/config.exs - continuing without esbuild."
      elif [[ "$esbuild_version" != "${esbuild.version}" ]]
      then
        errors+=1
        echo "error: esbuild version mismatch: using ${esbuild.version} from nix but $esbuild_version in your app!"
      fi

      if [[ "$errors" > 0 ]]
      then
        echo "Please fix the above errors and try again."
        exit 1
      fi
    '';

    postBuild = ''
      install ${tailwind}/bin/tailwindcss ${tailwindPath}
      install ${esbuild}/bin/esbuild ${esbuildPath}
      cp -a ../deps ./
      mix assets.deploy
    '';
  };
}
