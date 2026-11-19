{
  config,
  lib,
  pkgs,
  ...
}:

let
  catalog = builtins.fromJSON (builtins.readFile ../llm-server/catalog.json);
  defaultModel = "ornith-1.5:35b-mlx";

  # Home-level cordis patch: outranks each profile's patch, and dsh's config
  # editor never writes it, so a read-only store file is safe.
  # A patch row replaces the whole config of the row with the same id.
  homePatch = [
    {
      id = "llm-pi-ai";
      config.providers.${catalog.provider.id} = {
        displayName = catalog.provider.name;
        api = "openai-completions";
        baseURL = catalog.provider.baseURL;
        # The local server does not authenticate, but pi-ai's openai-completions
        # refuses a route with neither a key nor an Authorization header.
        headers.Authorization = "Bearer none";
        models = lib.mapAttrsToList (id: m: {
          inherit id;
          name = m.name;
          contextWindow = m.contextLength;
        }) catalog.models;
      };
    }
    {
      id = "agent-default-model";
      config = {
        provider = catalog.provider.id;
        model =
          assert lib.assertMsg (
            catalog.models ? ${defaultModel}
          ) "dsh: default model ${defaultModel} is not in llm-server/catalog.json";
          defaultModel;
      };
    }
  ];
in
{
  home.packages = [ (pkgs.callPackage ./drv.nix { }) ];

  # JSON is valid YAML, so the patch list is emitted with builtins.toJSON.
  home.file."${config.home.homeDirectory}/.dsh/cordis.patch.yml".text = builtins.toJSON homePatch;
}
