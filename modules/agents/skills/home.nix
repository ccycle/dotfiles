{ config, lib, ... }:
let
  # Skill names come from this directory's store copy so evaluation stays pure,
  # while the link targets point back at the live checkout so a skill stays
  # editable in place. Regular files here (README.md, home.nix) are filtered out.
  skillNames = lib.attrNames (
    lib.filterAttrs (_name: type: type == "directory") (builtins.readDir ./.)
  );

  # One home.file entry per skill rather than a single entry for the whole
  # directory: a directory-wide symlink would own ~/.claude/skills outright and
  # leave no way for a sibling repo (dotfiles-work) to add its own skills.
  linkSkills =
    dir:
    lib.listToAttrs (
      map (name: {
        name = "${config.home.homeDirectory}/${dir}/${name}";
        value.source = config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/agents/skills/${name}";
      }) skillNames
    );
in
{
  # Pi reads ~/.agents/skills; Claude Code reads ~/.claude/skills; Antigravity
  # CLI (agy) discovers global customizations under ~/.gemini/config.
  home.file =
    linkSkills ".claude/skills" // linkSkills ".agents/skills" // linkSkills ".gemini/config/skills";

  # Guard against a stale whole-directory symlink at any skills target
  # directory (see design.md for how this happens and why it
  # otherwise survives every subsequent activation unnoticed).
  home.activation.removeStaleSkillsContainerSymlink = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for dir in "$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.gemini/config/skills"; do
      if [[ -L "$dir" ]]; then
        rm -f "$dir"
      fi
    done
  '';
}
