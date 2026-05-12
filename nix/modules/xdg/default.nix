{ pkgs, ... }:

{
	xdg = {
		enable = true;
		localBinInPath = true;

		autostart.enable = true;
		mime.enable = true;

		userDirs = {
			enable = true;
			createDirectories = true;
            setSessionVariables = false;
		};

		portal = {
			enable = false;
			config = {
				common = {
					default = [ "gtk" ];
				};
			};
			extraPortals = [
				pkgs.xdg-desktop-portal-gtk
			];
		};
	};
}
