let pkgs = import <nixpkgs> {};

in pkgs.mkShell rec {
  name = "qdice";
  
  buildInputs = with pkgs; [
    nodejs-14_x 
    (yarn.override {
      nodejs = nodejs-14_x;
    })
    electron_19
    wine64
    proton-caller
    protontricks
    zip
    steamPackages.steamcmd
    elmPackages.elm-format
  ];

  shellHook = ''
    export $(cat .env | xargs)
    export $(cat .local_env | xargs)
    echo "Loaded .env and .local_env as env vars."
  '';
}  
