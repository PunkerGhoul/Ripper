{ pkgs, env, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      pull.rebase = true;
    };
    includes = [
      {
        contents = {
          user = {
            name = env.github.name;
            email = env.github.email;
            signingKey = env.github.signingKey;
          };
          init = {
            defaultBranch = "main";
          };
          commit = {
            gpgSign = true;
          };
        };
      }
    ];
    ignores = [
      "*.swp"
    ];
  };
}
