{self}: {
  pkgs,
  pname,
  src,
  version,
  system,
  tailwind ? pkgs.tailwindcss,
  esbuild ? pkgs.esbuild,
  erlangVersion ? "erlangR25",
  elixirVersion ? "elixir_1_14",
  beamPackages ?
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
  elixir ? beamPackages.${elixirVersion},
  erlang ? beamPackages.erlang,
  fetchMixDeps ? beamPackages.fetchMixDeps.override {inherit elixir;},
  mixRelease ? beamPackages.mixRelease.override {inherit elixir erlang fetchMixDeps;},
  mixDepsSha256 ? null,
  mix2NixOutput ? null,
}:
assert mixDepsSha256 != null -> mix2NixOutput == null; let
  systemAbbrs = {
    "aarch64-darwin" = "macos-arm64";
    "x86_64-linux" = "linux-x64";
  };
  tailwindPath = "_build/tailwind-${systemAbbrs.${system}}";
  esbuildPath = "_build/esbuild-${systemAbbrs.${system}}";
  mixNixDeps =
    if mix2NixOutput == null
    then {}
    else
      with pkgs;
        (import mix2NixOutput) {
          inherit lib beamPackages;
          # remove after https://github.com/NixOS/nixpkgs/pull/240354
          overrides = let
            overrideFun = old: {
              postInstall = ''
                cp -v package.json "$out/lib/erlang/lib/${old.name}"
              '';
            };
          in
            _: prev: {
              phoenix = prev.phoenix.overrideAttrs overrideFun;
              phoenix_html = prev.phoenix_html.overrideAttrs overrideFun;
              phoenix_live_view = prev.phoenix_live_view.overrideAttrs overrideFun;
            };
        };
in {
  inherit elixir erlang tailwind esbuild;
  app = mixRelease {
    inherit src pname version mixNixDeps;

    mixFodDeps =
      if mixDepsSha256 == null
      then null
      else
        fetchMixDeps {
          inherit version src;
          pname = "${pname}-elixir-deps";
          sha256 = mixDepsSha256;
        };

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

    preBuild = ''
      install ${tailwind}/bin/tailwindcss ${tailwindPath}
      install ${esbuild}/bin/esbuild ${esbuildPath}

      if [[ -z "$mixDepsSha256" ]]
      then
        mkdir ./deps
        cp -a _build/prod/lib/. ./deps/
      else
        cp -a ../deps ./
      fi
    '';

    postBuild = ''
      mix assets.deploy --no-deps-check
    '';
  };
}
