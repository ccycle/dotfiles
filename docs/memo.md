セットアップ手順

- ./scripts/login-rbw-shell.nix を立ち上げる
- mkdir -p ~/.config/sops/age/keys.txt  && rbw get "$agekey_value" ~/.config/sops/age/keys.txt 
- agekey_value は keys.txt の中身を入れる
- sudo ln -s /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt /etc/nix/ca_cert.pem
- 初期状態だと ca 周りで失敗するため

nix以外
- google日本語入力
- google chrome
