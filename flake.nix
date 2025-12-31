{
  description = "Buck2 + uv2nix project";

  inputs = {
    toolchains.url = "path:./toolchains";
  };

  outputs =
    { toolchains, ... }:
    {
      devShells = toolchains.outputs.devShells;
      packages = toolchains.outputs.packages;
    };
}
