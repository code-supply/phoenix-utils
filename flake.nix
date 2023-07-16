{
  description = "Build Elixir Phoenix apps with nix";

  outputs = {self}: {
    lib = {
      buildPhoenixApp = import ./build-phoenix-app.nix;
    };
  };
}
