{ symlinkJoin }:
drv: namePrev: nameFinal:
symlinkJoin {
  name = drv.name;
  paths = [ drv ];
  postBuild = ''
    ln -s $out/bin/${namePrev} $out/bin/${nameFinal}
  '';
}
