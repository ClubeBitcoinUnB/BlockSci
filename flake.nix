{
  description = "BlockSci analysis tool for blockchains";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              libjson-rpc-cpp = final.callPackage ./nix/libjson-rpc-cpp.nix {};
            })
          ];
        };
        pythonRuntimeDeps =
          ps: with ps; [
            dateparser
            multiprocess
            pandas
            psutil
            pycryptodome
            requests
          ];
        mkHeaderOnly =
          {
            pname,
            version,
            owner,
            repo ? pname,
            rev,
            sha256,
            copyFiles ? "include/.",
            destDir ? "include",
          }:
          pkgs.stdenv.mkDerivation {
            inherit pname version;

            src = pkgs.fetchFromGitHub {
              inherit
                owner
                rev
                sha256
                repo
                ;
            };

            dontBuild = true;
            dontConfigure = true;

            installPhase = ''
              mkdir -p $out/${destDir}
              cp -r ${copyFiles} $out/${destDir}
            '';
          };
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "blocksci";
          version = "0.7.0";
          src = self;

          nativeBuildInputs = with pkgs; [
            cmake
          ];

          buildInputs = with pkgs; [
            cereal
            clipp
            gtest
            nlohmann_json
            openssl
            rocksdb
            secp256k1
            sparsehash
            self.packages.${system}.bitcoin-api-cpp
            self.packages.${system}.dset
            self.packages.${system}.endian
            self.packages.${system}.filesystem
            self.packages.${system}.mio
          ];

          propagatedBuildInputs = with pkgs; [
            boost
            range-v3
            self.packages.${system}.variant
          ];
        };

        packages.blockscipy = pkgs.python3Packages.buildPythonPackage {
          pname = "blockscipy";
          version = "0.7.0";
          pyproject = true;

          src = ./blockscipy;

          build-system = with pkgs.python3Packages; [
            scikit-build-core
            pybind11
          ];

          nativeBuildInputs = with pkgs; [
            cmake
            ninja
          ];

          dontUseCmakeConfigure = true;

          buildInputs = with pkgs; [
            howard-hinnant-date
            self.packages.${system}.default
          ];

          dependencies = pythonRuntimeDeps pkgs.python3Packages;

          pythonImportsCheck = [ "blocksci" ];

          doCheck = false;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [
            self.packages.${system}.default
          ];

          nativeBuildInputs =
            with pkgs;
            [
              python3
              python3Packages.pip
              python3Packages.scikit-build-core
              clang-tools
              ninja
              ruff
            ]
            ++ pythonRuntimeDeps pkgs.python3Packages;

          buildInputs = with pkgs; [
            python3Packages.pybind11
            howard-hinnant-date
          ];

          shellHook = ''
            export LOCAL_PIP="$PWD/.nix-pip"
            export PYTHONPATH="$LOCAL_PIP/${pkgs.python3.sitePackages}:$PYTHONPATH"
            export PATH="$LOCAL_PIP/bin:$PATH"

            export CMAKE_PREFIX_PATH="$PWD/.nix-install:$CMAKE_PREFIX_PATH"
          ''
          + (
            if pkgs.stdenv.isDarwin then
              ''
                export DYLD_LIBRARY_PATH="$PWD/.nix-install/lib:$DYLD_LIBRARY_PATH"
              ''
            else
              ''
                export LD_LIBRARY_PATH="$PWD/.nix-install/lib64:$LD_LIBRARY_PATH"
              ''
          );
        };

        packages.bitcoin-api-cpp = pkgs.stdenv.mkDerivation {
          pname = "bitcoin-api-cpp";
          version = "0.3.1-unstable-2018-11-12";

          src = pkgs.fetchFromGitHub {
            owner = "hkalodner";
            repo = "bitcoin-api-cpp";
            rev = "952bef34a7ad63f752982afcc6231013db7a19dd";
            sha256 = "sha256-T7NrGW/MbIAQMHx4jrSkxoJpuODp7fcNkPJQBxz4EVs=";
          };

          nativeBuildInputs = with pkgs; [
            cmake
          ];
          
          postPatch = ''
            substituteInPlace CMakeLists.txt \
              --replace-fail "set(CMAKE_CXX_STANDARD 14)" "set(CMAKE_CXX_STANDARD 17)"
          '';

          buildInputs = with pkgs; [
            curl
          ];

          propagatedBuildInputs = with pkgs; [
            jsoncpp
            libjson-rpc-cpp
          ];
        };

        packages.dset = mkHeaderOnly {
          pname = "dset";
          version = "unstable-2015-06-28";

          owner = "wjakob";
          rev = "7967ef0e6041cd9d73b9c7f614ab8ae92e9e587a";
          sha256 = "sha256-EwboSCVaeuMfPjKftZuRD0GZvx8dD6VGwFIp6oxhV8Y=";

          copyFiles = "dset.h";
          destDir = "include/dset";
        };

        packages.endian = mkHeaderOnly {
          pname = "endian";
          version = "10.0.0";

          owner = "steinwurf";
          rev = "10.0.0";
          sha256 = "sha256-XXucL/yV2w9xXqHK3UjCM9iFaa5QD5jEpFhxOs9WPcg=";

          copyFiles = "src/endian";
        };

        packages.filesystem = mkHeaderOnly {
          pname = "filesystem";
          version = "unstable-2018-09-12";

          owner = "hkalodner";
          rev = "8cb505d6f51479645e670366df45951eeacb9fc4";
          sha256 = "sha256-zwHcyAiax4OpWShCqEOggVe5a+f6SRH13toCNBS+IUY=";
        };

        packages.mio = mkHeaderOnly {
          pname = "mio";
          version = "unstable-2018-05-18";

          owner = "hkalodner";
          rev = "9d2d5f397cad9ca6d2dfa31cd6716fdd98542862";
          sha256 = "sha256-TZmXHBvHwiupKFDuRTelvnP4JHfuwaT0EPT2N4w+KF4=";
        };

        packages.variant = mkHeaderOnly {
          pname = "variant";
          version = "1.3.0";

          owner = "mpark";
          rev = "v1.3.0";
          sha256 = "sha256-pPqUNaQ9e03NUkQMg3bKkcbTtGc1HmvPpm7dwfYbX9k=";
        };
      }
    );
}
