{ runCommand, bitwarden-cli }:
runCommand
  "bitwarden-get"
{ nativeBuildInputs = [ bitwarden-cli ]; }
  "bw get > $out"
