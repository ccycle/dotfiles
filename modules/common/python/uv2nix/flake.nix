# flake.nix の outputs 部分のlet ... in 内
{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    # flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, myPythonProject, ... }@inputs:
    let
      system = "x86_64-linux"; # またはあなたのシステムのアーキテクチャ
      pkgs = nixpkgs.legacyPackages.${system};

      # myPythonProjectからuv2nixを使ってパッケージを生成
      myPythonProjectPackage = pkgs.callPackage
        (
          { fetchurl, uv2nix, lib }:
          let
            # myPythonProjectの内容をNixストアにコピー
            # myPythonProjectはflake=falseなので、パスとして参照できる
            projectSource = myPythonProject; # inputsで定義したものをそのまま利用
          in
          uv2nix.buildPythonApplication {
            pname = "your-python-app-from-repo"; # 適切な名前に変更
            version = "0.1.0"; # 適切なバージョンに変更
            src = projectSource;
            # requirements.txt など、uv2nixが参照するファイルパスを調整
            # 例えば、projectSource/requirements.txt など
            # `uv2nix` の引数は、プロジェクトの構造に合わせて調整してください。
            # 通常は `requirements` または `pyproject` を指定します。
            # 例: requirements = "${projectSource}/requirements.txt";
            # または pyproject = true;
          }
        )
        {
          inherit uv2nix; # uv2nixを依存として渡す
        };
    in
    {
      homeConfigurations."your-username" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home.nix
          {
            home.packages = [
              myPythonProjectPackage # 生成したパッケージをhome-managerでインストール
            ];
          }
        ];
      };
    };
}
