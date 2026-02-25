# Nix を使用した pnpm プロジェクトのパッケージング

このドキュメントでは、`pnpm` を使用する Node.js プロジェクトを Nix derivation としてパッケージングするための主要なアプローチについて説明します。

## 概要

`pnpm` は、コンテンツアドレス可能なストアとシンボリックリンクを多用して `node_modules` を構築するため、Nix のサンドボックス化されたビルド環境との統合には特別な配慮が必要です。`npm` プロジェクトで一般的に使われる `buildNpmPackage` などのヘルパーは、そのままでは `pnpm` に対応していません。

現在、コミュニティでは主に2つのアプローチが取られています。

1.  **`pnpm2nix` のようなツールを使用する方法**: `pnpm-lock.yaml` を解析し、Nix が理解できる形式に変換する。
2.  **`buildNpmPackage` を手動でオーバーライドする方法**: `npm` コマンドの代わりに `pnpm` コマンドを実行するようにビルドフェーズをカスタマイズする。

## 推奨アプローチ: `pnpm2nix` の利用

`pnpm` プロジェクトのパッケージングには、専用のツールを使うのが最も簡単で再現性が高い方法です。[`nzbr/pnpm2nix-nzbr`](https://github.com/nzbr/pnpm2nix-nzbr) は、この目的のために `mkPnpmPackage` という高レベルな関数を提供しており、推奨されるアプローチです。

このツールは、`pnpm-lock.yaml` から依存関係を解決し、Nix のストアにフェッチするための固定出力 derivation を生成します。

### 使用例: `flake.nix`

```nix
{
  description = "A pnpm project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pnpm2nix-nzbr.url = "github:nzbr/pnpm2nix-nzbr";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, pnpm2nix-nzbr, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pnpm2nix = pnpm2nix-nzbr.packages.${system};
      in
      {
        packages.default = pnpm2nix.mkPnpmPackage {
          pname = "my-pnpm-app";
          version = "0.1.0";
          src = ./.;
          # pnpm-lock.yaml をもとに依存関係を計算する
          pnpmLock = ./pnpm-lock.yaml;
          # 実行可能ファイルの名前
          executable = "my-pnpm-app";
        };
      });
}
```

### 長所と短所

-   **長所**:
    -   `pnpm` プロジェクト専用に設計されており、最も簡単な方法。
    -   `flake.nix` 内で完結し、外部のスクリプトが不要。
-   **短所**:
    -   サードパーティのツールへの依存が発生する。
    -   コミュニティのツールであり、`nixpkgs` 本体にはまだ含まれていない。

## 代替アプローチ: `buildNpmPackage` のオーバーライド

専用ツールがうまく機能しない場合や、より細かい制御が必要な場合は、`nixpkgs` 標準の `buildNpmPackage` をカスタマイズする方法があります。

このアプローチの要点は、`npm` の代わりに `pnpm` をビルド時に使用するように、ビルドフェーズを上書きすることです。

### `pnpm` の準備: `corepack`

Node.js v16.13 以降、`pnpm` や `yarn` などのパッケージマネージャを管理するための `corepack` が同梱されています。Nix で `pnpm` を利用する際は、`nodePackages.pnpm` よりも `corepack` を有効にすることが推奨されます。

### 使用例: `default.nix`

```nix
{ pkgs ? import <nixpkgs> { } }:

let
  # corepack が有効な Node.js を使用する
  nodejs = pkgs.nodejs-18_x;
  pnpm = pkgs.pnpm;
in
pkgs.stdenv.mkDerivation {
  pname = "my-pnpm-app";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = [
    nodejs
    pnpm # ビルド環境で pnpm コマンドを利用可能にする
  ];

  # pnpm は npm と同じ package-lock.json を解釈できる
  # pnpm import を実行して pnpm-lock.yaml を生成しておく
  # もしくは、あらかじめ pnpm-lock.yaml をもとに package-lock.json を生成しておく
  # $ pnpm import

  # 依存関係を vendor 化するための package-lock.json
  # package-lock.json は `pkgs.fetchnpmDeps` などで利用できる
  # ここでは簡略化のため、ビルド時にネットワークアクセスを許可する
  # preBuild = ''
  #   export HOME=$(mktemp -d)
  #   pnpm install --frozen-lockfile
  # '';
  # installPhase = ''
  #   runHook preInstall
  #
  #   pnpm run build
  #   mkdir -p $out/bin
  #   cp dist/my-pnpm-app $out/bin/my-pnpm-app
  #
  #   runHook postInstall
  # '';

  # より Nix らしいアプローチ (ネットワークアクセスなし)
  # 1. pnpm-lock.yaml から package-lock.json を生成
  # 2. `pkgs.fetchnpmDeps` を使って依存関係を vendor 化
  # 3. `node_modules` をビルド時に展開する
  # この方法は複雑なため、pnpm2nix の利用を推奨する

  # ここでは最もシンプルな、ただし非推奨な方法を示す
  configurePhase = ''
    export HOME=$(mktemp -d)
    pnpm config set store-dir ./.pnpm-store
  '';
  
  buildPhase = ''
    pnpm install --frozen-lockfile
    pnpm run build
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp dist/main.js $out/bin/my-pnpm-app
  '';

  # この方法はビルドごとに依存関係をダウンロードするため非効率
  # Nix の良さを活かすには、依存関係の解決とフェッチを分離する必要がある
  # そのため、pnpm2nix のようなツールが推奨される
}
```

### 長所と短所

-   **長所**:
    -   `nixpkgs` の標準的な機能のみを使用するため、外部依存が少ない。
    -   ビルドプロセスを細かく制御できる。
-   **短所**:
    -   `pnpm` のワークフローを再現するための手作業が多く、複雑になりがち。
    -   依存関係の固定（`fixed-output derivation`）を正しく行うのが難しい。

## 結論

`pnpm` プロジェクトを Nix でパッケージングする場合、まずは `nzbr/pnpm2nix-nzbr` のような専用ツールの利用を検討してください。これが最も簡単で、Nix の思想に沿った方法です。

`buildNpmPackage` のカスタマイズは、より細かい制御が必要な場合や、専用ツールが利用できない場合のフォールバックとして有効ですが、依存関係の管理が複雑になる点に注意が必要です。

## 参考文献

-   **`nzbr/pnpm2nix-nzbr`**: <https://github.com/nzbr/pnpm2nix-nzbr>
-   **`nix-community/pnpm2nix`**: <https://github.com/nix-community/pnpm2nix>
-   **NixOS Discourse discussion on pnpm**: [How to use pnpm with recent nodejs?](https://discourse.nixos.org/t/how-to-use-pnpm-with-recent-nodejs/19628)
-   **Corepack Documentation**: [pnpm Official Documentation](https://pnpm.io/cli/corepack)
