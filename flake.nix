{
  description = "Build Elixir Phoenix apps with nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
  };
  outputs = {
    self,
    nixpkgs,
  }: {
    lib = {
      buildPhoenixApp = (import ./build-phoenix-app.nix) {inherit self;};
    };
    devShells.x86_64-linux.default = with nixpkgs.legacyPackages.x86_64-linux.pkgs;
      mkShell {
        packages = [elixir elixir_ls];
      };
  };
}
