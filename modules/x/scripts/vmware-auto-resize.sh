{{coreUtils}}/bin/stdbuf -oL \
  {{xev}}/bin/xev -root -event randr |
while IFS= read -r line; do
  case "$line" in
    *event,*)
      output=$({{xrandr}}/bin/xrandr | {{gawk}}/bin/awk '/ connected/{print $1; exit}')
      [ -n "$output" ] && {{xrandr}}/bin/xrandr --output "$output" --auto
      ;;
  esac
done
