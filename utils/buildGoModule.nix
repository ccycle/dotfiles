{
  gomod2nix,
  system,
  other-repo,
  pname,
  version,
  ...
}:
gomod2nix.legacyPackages.${system}.buildGoApplication {
  inherit pname version;
  src = ./.; # 自分のリポジトリ

  # 依存関係の解決
  modules = ./gomod2nix.toml;

  # 重要: replace ディレクティブを Nix の store パスに書き換える
  # あるいは、ビルド前に preBuild でパスを調整する
  preBuild = ''
    # go.mod 内の相対パスを、Flake input で取得したソースのパスに置換
    substituteInPlace go.mod \
      --replace "../other-repo" "${other-repo}"
  '';
}
