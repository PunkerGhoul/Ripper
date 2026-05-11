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
		};

		portal = {
			enable = true;
			extraPortals = [
				pkgs.xdg-desktop-portal-gtk
			];
		};
	};
}
