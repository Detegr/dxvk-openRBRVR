{
  description = "DXVK D3D9 build with Zig";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    zig = { url = github:mitchellh/zig-overlay; };
    zls = { url = github:zigtools/zls/0.15.1; };
  };

  outputs = { self, nixpkgs, zig, zls }: {
    devShells.x86_64-linux.default = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in pkgs.mkShell {
      nativeBuildInputs = [
        pkgs.glslang.bin
        pkgs.python3
        zig.packages.x86_64-linux."0.16.0"
        zls.packages.x86_64-linux.zls
      ];
    };
  };
}
