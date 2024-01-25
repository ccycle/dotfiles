versions: func: builtins.listToAttrs
  (
    builtins.map
      (
        version:
        {
          name = version;
          value = func version;
        }
      )
      versions
  )
