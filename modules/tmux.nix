{ ... }: {
  programs.tmux = {
    enable = true;
    terminal = "screen-256color"; # https://zenn.dev/ymotongpoo/articles/d3b38bee191e3b
    mouse = true;
  };
}
