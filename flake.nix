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
        pytestRegtest = pkgs.python3Packages.buildPythonPackage rec {
          pname = "pytest-regtest";
          version = "2.5.1";
          pyproject = true;

          src = pkgs.fetchPypi {
            pname = "pytest_regtest";
            inherit version;
            hash = "sha256-hPd/GPpwKVN3Zi3pbXIdA7MtBVCcU+E2au7BHb7VbsA=";
          };

          build-system = with pkgs.python3Packages; [
            setuptools
          ];

          dependencies = with pkgs.python3Packages; [
            deepdiff
            pytest
          ];

          # nixpkgs 26.05 currently ships deepdiff 8.x while pytest-regtest
          # 2.5.1 declares deepdiff >= 9. BlockSci's regression tests exercise
          # the plugin successfully with deepdiff 8.x, so relax this until
          # nixpkgs updates deepdiff or we add a dedicated deepdiff 9 package.
          pythonRelaxDeps = [ "deepdiff" ];

          pythonImportsCheck = [ "pytest_regtest" ];

          doCheck = false;
        };
        pythonTestDeps =
          ps: [
            ps.pytest
            ps."pytest-benchmark"
            pytestRegtest
            ps.pytz
            ps.tzlocal
          ];
        knownPools = pkgs.fetchFromGitHub {
          owner = "blockchain";
          repo = "Blockchain-Known-Pools";
          rev = "29ab27c844ebdb63110f8783f73b9decd4abc221";
          sha256 = "sha256-nFWprW6+PXDCIW/IjbAm9PNTMs+Clu42gCtfNnTU8QI=";
        };
        pythonDevEnv = pkgs.python3.withPackages (
          ps:
          [
            self.packages.${system}.blockscipy
          ]
          ++ pythonTestDeps ps
        );
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

          preBuild = ''
            parallel_level="''${NIX_BUILD_CORES:-1}"

            if [ "$parallel_level" -lt 1 ]; then
              parallel_level=1
            fi

            export CMAKE_BUILD_PARALLEL_LEVEL="$parallel_level"
            echo "CMAKE_BUILD_PARALLEL_LEVEL=$CMAKE_BUILD_PARALLEL_LEVEL"
          '';

          buildInputs = with pkgs; [
            howard-hinnant-date
            self.packages.${system}.default
          ];

          dependencies = pythonRuntimeDeps pkgs.python3Packages;

          postInstall = ''
            mkdir -p "$out/${pkgs.python3.sitePackages}/blocksci/Blockchain-Known-Pools"
            cp ${knownPools}/pools.json \
              "$out/${pkgs.python3.sitePackages}/blocksci/Blockchain-Known-Pools/pools.json"
          '';

          pythonImportsCheck = [ "blocksci" ];

          doCheck = false;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            self.packages.${system}.default
            pythonDevEnv
            clang-tools
            cmake
            ninja
            ruff
          ];

          BLOCKSCI_POOLS_JSON = "${knownPools}/pools.json";
          CMAKE_PREFIX_PATH = "${self.packages.${system}.default}";
        };

        # Initial flake CI intentionally covers BTC regtest only. BCH/LTC
        # coverage can be added as follow-up checks once BTC remains stable.
        checks.blockscipy-btc = pkgs.runCommand "blocksci-python-btc-tests" {
          nativeBuildInputs = [
            self.packages.${system}.default
            pythonDevEnv
          ];
          BLOCKSCI_POOLS_JSON = "${knownPools}/pools.json";
        } ''
          cp -R ${self}/test "$TMPDIR/test"
          chmod -R u+w "$TMPDIR/test"
          cd "$TMPDIR/test/blockscipy"
          python -m pytest --btc -q
          touch "$out"
        '';

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
