#!/usr/bin/env bash

## Author  : Aditya Shakya
## Mail    : adi1090x@gmail.com
## Github  : @adi1090x
## Twitter : @adi1090x

dir="$HOME/.config/polybar/shapes/scripts/rofi"
uptime=$(uptime -p | sed -e 's/up //g')

rofi_command="rofi -no-config -theme $dir/powermenu.rasi"
lock_script="$HOME/.config/i3/scripts/lock"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
mkdir -p "$runtime_dir" 2>/dev/null || true
log="$runtime_dir/ripper-powermenu.log"

systemctl_bin=""
for candidate in /usr/bin/systemctl /bin/systemctl; do
	if [[ -x "$candidate" ]]; then
		systemctl_bin="$candidate"
		break
	fi
done

show_error() {
	rofi -no-config -theme "$dir/message.rasi" -e "$1"
}

start_polkit_agent() {
	if [[ -x "$HOME/.local/bin/ripper-polkit-agent-start" ]]; then
		"$HOME/.local/bin/ripper-polkit-agent-start" >>"$log" 2>&1 || true
	fi
}

run_systemctl_action() {
	if [[ -z "$systemctl_bin" ]]; then
		return 127
	fi

	"$systemctl_bin" "$@" >>"$log" 2>&1
}

run_power_action() {
	action="$1"
	: >"$log"
	start_polkit_agent

	if run_systemctl_action "$action"; then
		exit 0
	fi

	if run_systemctl_action --ignore-inhibitors "$action"; then
		exit 0
	fi

	show_error "$action failed. See $log"
	exit 1
}

start_lock() {
	: >"$log"

	if [[ -x "$lock_script" ]]; then
		"$lock_script" >>"$log" 2>&1 &
		lock_pid=$!
		sleep 0.2

		if kill -0 "$lock_pid" 2>/dev/null; then
			return 0
		fi

		wait "$lock_pid"
		status=$?
		show_error "Lock failed ($status). See $log"
		return "$status"
	elif command -v betterlockscreen >/dev/null 2>&1; then
		betterlockscreen -l >>"$log" 2>&1 &
		return 0
	else
		show_error "Lock command not found"
		return 1
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
	printf 'yes\nno\n' | rofi -dmenu \
		-no-config \
		-i \
		-no-fixed-num-lines \
		-p "Are You Sure? : " \
		-selected-row 1 \
		-theme "$dir/confirm.rasi"
}

confirmed() {
	case "$1" in
	[Yy] | [Yy][Ee][Ss])
		return 0
		;;
	esac

	return 1
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
		if confirmed "$ans"; then
			run_power_action poweroff
		elif [[ $ans == "no" || $ans == "NO" || $ans == "n" || $ans == "N" ]]; then
			exit 0
        else
			msg
        fi
        ;;
    $reboot)
		ans=$(confirm_exit)
		if confirmed "$ans"; then
			run_power_action reboot
		elif [[ $ans == "no" || $ans == "NO" || $ans == "n" || $ans == "N" ]]; then
			exit 0
        else
			msg
        fi
        ;;
    $lock)
		start_lock
        ;;
    $suspend)
		ans=$(confirm_exit)
		if confirmed "$ans"; then
			: >"$log"
			start_polkit_agent
			start_lock || exit 1
			sleep 0.3
			run_power_action suspend
		elif [[ $ans == "no" || $ans == "NO" || $ans == "n" || $ans == "N" ]]; then
			exit 0
        else
			msg
        fi
        ;;
    $logout)
		ans=$(confirm_exit)
		if confirmed "$ans"; then
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
