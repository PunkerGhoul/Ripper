#!/usr/bin/env bash

## Author  : Aditya Shakya
## Mail    : adi1090x@gmail.com
## Github  : @adi1090x
## Twitter : @adi1090x

dir="$HOME/.config/polybar/cuts/scripts/rofi"
uptime=$(uptime -p | sed -e 's/up //g')

rofi_command="rofi -no-config -theme $dir/powermenu.rasi"
lock_script="$HOME/.config/i3/scripts/lock"

systemctl_bin=""
for candidate in /usr/bin/systemctl /bin/systemctl; do
	if [[ -x "$candidate" ]]; then
		systemctl_bin="$candidate"
		break
	fi
done

run_system_action() {
	if [[ -z "$systemctl_bin" ]]; then
		rofi -no-config -theme "$dir/message.rasi" -e "systemctl not found"
		exit 1
	fi

	"$systemctl_bin" "$@"
}

run_lock() {
	if [[ -x "$lock_script" ]]; then
		"$lock_script"
	elif command -v betterlockscreen >/dev/null 2>&1; then
		betterlockscreen -l
	else
		rofi -no-config -theme "$dir/message.rasi" -e "Lock command not found"
		exit 1
	fi
}

# Options
shutdown=" Shutdown"
reboot=" Restart"
lock=" Lock"
suspend=" Sleep"
logout=" Logout"

# Confirmation
confirm_exit() {
	rofi -dmenu \
		-no-config \
		-i \
		-no-fixed-num-lines \
		-p "Are You Sure? : " \
		-theme "$dir/confirm.rasi"
}

# Message
msg() {
	rofi -no-config -theme "$dir/message.rasi" -e "Available Options  -  yes / y / no / n"
}

# Variable passed to rofi
options="$lock\n$suspend\n$logout\n$reboot\n$shutdown"

chosen="$(echo -e "$options" | $rofi_command -p "Uptime: $uptime" -dmenu -selected-row 0)"
case $chosen in
$shutdown)
	ans=$(confirm_exit)
	if [[ $ans == "yes" || $ans == "YES" || $ans == "y" || $ans == "Y" ]]; then
		run_system_action poweroff
	elif [[ $ans == "no" || $ans == "NO" || $ans == "n" || $ans == "N" ]]; then
		exit 0
	else
		msg
	fi
	;;
$reboot)
	ans=$(confirm_exit)
	if [[ $ans == "yes" || $ans == "YES" || $ans == "y" || $ans == "Y" ]]; then
		run_system_action reboot
	elif [[ $ans == "no" || $ans == "NO" || $ans == "n" || $ans == "N" ]]; then
		exit 0
	else
		msg
	fi
	;;
$lock)
	run_lock
	;;
$suspend)
	ans=$(confirm_exit)
	if [[ $ans == "yes" || $ans == "YES" || $ans == "y" || $ans == "Y" ]]; then
		run_lock &
		sleep 0.2
		run_system_action suspend
	elif [[ $ans == "no" || $ans == "NO" || $ans == "n" || $ans == "N" ]]; then
		exit 0
	else
		msg
	fi
	;;
$logout)
	ans=$(confirm_exit)
	if [[ $ans == "yes" || $ans == "YES" || $ans == "y" || $ans == "Y" ]]; then
		if [[ "$DESKTOP_SESSION" == "Openbox" ]]; then
			openbox --exit
		elif [[ "$DESKTOP_SESSION" == "bspwm" ]]; then
			bspc quit
		elif [[ "$DESKTOP_SESSION" == "i3" ]]; then
			i3-msg exit
		fi
	elif [[ $ans == "no" || $ans == "NO" || $ans == "n" || $ans == "N" ]]; then
		exit 0
	else
		msg
	fi
	;;
esac
