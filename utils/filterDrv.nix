{ lib }: attr: (builtins.filter lib.attrsets.isDerivation (builtins.attrValues attr))
