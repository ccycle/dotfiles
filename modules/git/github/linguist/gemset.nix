{
  cgi = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "0c5494n3n6l51n1w1vc118zckbqdzk7r6b656hswg72w0bif2ja3";
      type = "gem";
    };
    version = "0.4.1";
  };
  charlock_holmes = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "0hybw8jw9ryvz5zrki3gc9r88jqy373m6v46ynxsdzv1ysiyr40p";
      type = "gem";
    };
    version = "0.7.7";
  };
  github-linguist = {
    dependencies = [ "cgi" "charlock_holmes" "mini_mime" "rugged" ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "1x86bxf2lbxpxmbrb6vn6gxfxz6v91vgnz94ryxfl7ff276pd1ki";
      type = "gem";
    };
    version = "7.29.0";
  };
  mini_mime = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "1vycif7pjzkr29mfk4dlqv3disc5dn0va04lkwajlpr1wkibg0c6";
      type = "gem";
    };
    version = "1.1.5";
  };
  rugged = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "1sccng15h8h3mcjxfgvxy85lfpswbj0nhmzwwsqdffbzqgsb2jch";
      type = "gem";
    };
    version = "1.7.2";
  };
}
