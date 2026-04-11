#!/bin/sh
PAK_DIR="$(dirname "$0")"
PAK_NAME="$(basename "$PAK_DIR")"
PAK_NAME="${PAK_NAME%.*}"
set -x

rm -f "$LOGS_PATH/$PAK_NAME.txt"
exec >>"$LOGS_PATH/$PAK_NAME.txt"
exec 2>&1

echo "$0" "$@"
cd "$PAK_DIR" || exit 1
mkdir -p "$USERDATA_PATH/$PAK_NAME"

architecture=arm
if uname -m | grep -q '64'; then
    architecture=arm64
fi

export PATH="$PAK_DIR/bin/$architecture:$PAK_DIR/bin/$PLATFORM:$PAK_DIR/bin:$PATH"

SERVICE_NAME="tailscaled"
HUMAN_READABLE_NAME="Tailscale VPN"
LAUNCHES_SCRIPT="false"

TAILSCALE_AUTHKEY_FILE="$SDCARD_PATH/authkey"
TAILSCALE_LOGIN_SERVER_STATE_FILE="$USERDATA_PATH/$PAK_NAME/login_server.json"

service_off() {
    killall "$SERVICE_NAME"
}


show_message() {
    message="$1"
    seconds="$2"

    if [ -z "$seconds" ]; then
        seconds="forever"
    fi

    killall minui-presenter >/dev/null 2>&1 || true
    echo "$message" 1>&2
    if [ "$seconds" = "forever" ]; then
        minui-presenter --message "$message" --timeout -1 &
    else
        minui-presenter --message "$message" --timeout "$seconds"
    fi
}

disable_start_on_boot() {
    sed -i "/${PAK_NAME}.pak-on-boot/d" "$SDCARD_PATH/.userdata/$PLATFORM/auto.sh"
    sync
    return 0
}

enable_start_on_boot() {
    if [ ! -f "$SDCARD_PATH/.userdata/$PLATFORM/auto.sh" ]; then
        echo '#!/bin/sh' >"$SDCARD_PATH/.userdata/$PLATFORM/auto.sh"
        echo '' >>"$SDCARD_PATH/.userdata/$PLATFORM/auto.sh"
    fi

    echo "test -f \"$PAK_DIR/bin/on-boot\" && \"$PAK_DIR/bin/on-boot\" # ${PAK_NAME}.pak-on-boot" >>"$SDCARD_PATH/.userdata/$PLATFORM/auto.sh"
    chmod +x "$SDCARD_PATH/.userdata/$PLATFORM/auto.sh"
    sync
    return 0
}

will_start_on_boot() {
    if grep -q "${PAK_NAME}.pak-on-boot" "$SDCARD_PATH/.userdata/$PLATFORM/auto.sh" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

is_service_running() {
    if pgrep "$SERVICE_NAME" >/dev/null 2>&1; then
        return 0
    fi

    if [ "$LAUNCHES_SCRIPT" = "true" ]; then
        if pgrep -fn "$SERVICE_NAME" >/dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}

wait_for_service() {
    max_counter="$1"
    counter=0

    while ! is_service_running; do
        counter=$((counter + 1))
        if [ "$counter" -gt "$max_counter" ]; then
            return 1
        fi
        sleep 1
    done
}

wait_for_service_to_stop() {
    max_counter="$1"
    counter=0

    while is_service_running; do
        counter=$((counter + 1))
        if [ "$counter" -gt "$max_counter" ]; then
            return 1
        fi
        sleep 1
    done
}

get_service_pid() {
    if [ "$LAUNCHES_SCRIPT" = "true" ]; then
        pgrep -fn "$SERVICE_NAME" 2>/dev/null | sort | head -n 1 || true
    else
        pgrep "$SERVICE_NAME" 2>/dev/null | sort | head -n 1 || true
    fi
}

load_login_server_state() {
    state_file="$TAILSCALE_LOGIN_SERVER_STATE_FILE"
    if [ ! -f "$state_file" ]; then
        return 1
    fi
    if ! jq -e 'type == "object"' "$state_file" >/dev/null 2>&1; then
        rm -f "$state_file"
        return 1
    fi
    jq -rM '.' "$state_file"
}

parse_login_server_from_settings() {
    settings_json="$1"
    login_server=$(printf "%s" "$settings_json" | jq -rM '
        def trim: gsub("^\\s+|\\s+$"; "");
        (.settings[2] // {}) as $login |
        if ($login.selected // 0) == 1 then
            ($login.input.login_server_url // "" | trim)
        else
            ""
        end
    ' 2>/dev/null)

    if [ -z "$login_server" ]; then
        return 1
    fi

    printf "%s\n" "$login_server"
}

save_login_server_state() {
    settings_json="$1"
    state_file="$TAILSCALE_LOGIN_SERVER_STATE_FILE"
    tmp_file="${state_file}.tmp"

    login_server_json=$(printf "%s" "$settings_json" | jq -c '
        def trim: gsub("^\\s+|\\s+$"; "");
        (.settings[2] // {}) as $login |
        ($login.input.login_server_url // "" | trim) as $url |
        if ($login.selected // 0) == 1 and ($url | length) > 0 then
            {selected: 1, url: $url}
        else
            empty
        end
    ' 2>/dev/null)

    if [ -n "$login_server_json" ]; then
        printf "%s\n" "$login_server_json" >"$tmp_file"
        mv "$tmp_file" "$state_file"
    else
        rm -f "$state_file"
    fi
}

tailscale_get_login_server() {
    settings_json="$1"

    if [ -n "$settings_json" ]; then
        if login_server_candidate="$(parse_login_server_from_settings "$settings_json")"; then
            printf "%s\n" "$login_server_candidate"
            return 0
        fi
    fi

    if saved_state="$(load_login_server_state)"; then
        login_server_url=$(printf "%s" "$saved_state" | jq -rM '(.url // "") | gsub("^\\s+|\\s+$"; "")' 2>/dev/null)
        if [ -n "$login_server_url" ]; then
            printf "%s\n" "$login_server_url"
            return 0
        fi
    fi

    return 1
}

current_settings() {
    minui_list_file="/tmp/${PAK_NAME}-settings.json"
    rm -f "$minui_list_file"

    jq -rM '{settings: .settings}' "$PAK_DIR/config.json" >"$minui_list_file"
    if is_service_running; then
        jq '.settings[0].selected = 1' "$minui_list_file" >"$minui_list_file.tmp"
        mv "$minui_list_file.tmp" "$minui_list_file"
    fi

    if will_start_on_boot; then
        jq '.settings[1].selected = 1' "$minui_list_file" >"$minui_list_file.tmp"
        mv "$minui_list_file.tmp" "$minui_list_file"
    fi

    saved_login_server="$(load_login_server_state)"
    saved_login_server_url=""
    saved_login_server_selected="0"
    if [ -n "$saved_login_server" ]; then
        saved_login_server_selected=$(printf "%s" "$saved_login_server" | jq -rM '.selected // 0')
        saved_login_server_url=$(printf "%s" "$saved_login_server" | jq -rM '.url // ""')
    fi

    if [ -n "$saved_login_server_url" ]; then
        jq --arg url "$saved_login_server_url" '.settings[2].input.login_server_url = $url' "$minui_list_file" >"$minui_list_file.tmp"
        mv "$minui_list_file.tmp" "$minui_list_file"
    fi

    if [ "$saved_login_server_selected" = "1" ] && [ -n "$saved_login_server_url" ]; then
        jq '.settings[2].selected = 1' "$minui_list_file" >"$minui_list_file.tmp"
        mv "$minui_list_file.tmp" "$minui_list_file"
    fi

    cat "$minui_list_file"
}

tailscale_login() {
    authkey="$1"
    login_server="$2"

    tailscale_args="--authkey=$authkey --hostname=minui --accept-routes --accept-dns"
    if [ -n "$login_server" ]; then
        tailscale_args="$tailscale_args --login-server=$login_server"
    fi

    # shellcheck disable=SC2086
    if ! tailscale up $tailscale_args; then
        return 1
    fi
}

tailscale_start() {
    statedir="$USERDATA_PATH/$PAK_NAME/"

    tailscaled --statedir="$statedir" --no-logs-no-support &
}

tailscale_get_authkey() {
    authkeyfile="$TAILSCALE_AUTHKEY_FILE"

    if [ ! -f "$authkeyfile" ] || [ ! -s "$authkeyfile" ]; then
        return 1
    fi
    authkey="$(cat "$authkeyfile")"
    rm -f "$authkeyfile"

    echo "$authkey"
}

tailscale_is_logged_in() {
    if tailscale status | grep -qi -e "logged out" -e "failed"; then
        return 1
    fi
}

tailscale_get_ip_address() {
    if ! ip_address="$(tailscale ip -1)"; then
        return 1
    fi
    echo "$ip_address"
}

main_screen() {
    settings="$1"
    minui_list_file="/tmp/${PAK_NAME}-minui-list.json"
    rm -f "$minui_list_file"

    echo "$settings" >"$minui_list_file"

    if is_service_running; then
        service_pid="$(get_service_pid)"
        jq --arg pid "$service_pid" '.settings[.settings | length] |= . + {"name": "PID", "options": [$pid], "selected": 0, "features": {"unselectable": true}}' "$minui_list_file" >"$minui_list_file.tmp"
        mv "$minui_list_file.tmp" "$minui_list_file"

        ip_address="$(tailscale_get_ip_address)"
        if [ -n "$ip_address" ]; then
            jq --arg ip "$ip_address" '.settings[.settings | length] |= . + {"name": "Address", "options": [$ip], "selected": 0, "features": {"unselectable": true}}' "$minui_list_file" >"$minui_list_file.tmp"
            mv "$minui_list_file.tmp" "$minui_list_file"
        fi
    fi

    minui-list --file "$minui_list_file" --format json --title "$HUMAN_READABLE_NAME" --confirm-text "SAVE" --item-key "settings" --write-value state
}

cleanup() {
    rm -f "/tmp/${PAK_NAME}-old-settings.json"
    rm -f "/tmp/${PAK_NAME}-new-settings.json"
    rm -f "/tmp/${PAK_NAME}-settings.json"
    rm -f "/tmp/${PAK_NAME}-minui-list.json"
    rm -f /tmp/stay_awake
    killall minui-presenter >/dev/null 2>&1 || true
}

main() {
    echo "1" >/tmp/stay_awake
    trap "cleanup" EXIT INT TERM HUP QUIT

    if [ "$PLATFORM" = "tg3040" ] && [ -z "$DEVICE" ]; then
        export DEVICE="brick"
        export PLATFORM="tg5040"
    fi

    if ! command -v minui-list >/dev/null 2>&1; then
        show_message "minui-list not found." 2
        return 1
    fi

    if ! command -v minui-presenter >/dev/null 2>&1; then
        show_message "minui-presenter not found." 2
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        show_message "jq not found." 2
        return 1
    fi

    if ! command -v tailscale >/dev/null 2>&1; then
        show_message "tailscale not found." 2
        return 1
    fi

    if ! command -v tailscaled >/dev/null 2>&1; then
        show_message "tailscaled not found." 2
        return 1
    fi

    chmod +x "$PAK_DIR/bin/$PLATFORM/minui-list"
    chmod +x "$PAK_DIR/bin/$PLATFORM/minui-presenter"
    chmod +x "$PAK_DIR/bin/$architecture/jq"
    chmod +x "$PAK_DIR/bin/$architecture/tailscale"
    chmod +x "$PAK_DIR/bin/$architecture/tailscaled"
    chmod +x "$PAK_DIR/bin/on-boot"

    allowed_platforms="miyoomini my282 rg35xxplus tg5040"
    if ! echo "$allowed_platforms" | grep -q "$PLATFORM"; then
        show_message "$PLATFORM is not a supported platform." 2
    fi

    if [ "$PLATFORM" = "miyoomini" ]; then
        if [ ! -f /customer/app/axp_test ]; then
            show_message "Wifi not supported on non-Plus version of the Miyoo Mini." 2
            return 1
        fi
    fi

    if [ "$PLATFORM" = "rg35xxplus" ]; then
        RGXX_MODEL="$(strings /mnt/vendor/bin/dmenu.bin | grep ^RG)"
        if [ "$RGXX_MODEL" = "RG28xx" ]; then
            show_message "Wifi not supported on RG28XX." 2
            return 1
        fi
    fi

    while true; do
        settings="$(current_settings)"
        new_settings="$(main_screen "$settings")"
        exit_code=$?
        # exit codes: 2 = back button, 3 = menu button
        if [ "$exit_code" -ne 0 ]; then
            break
        fi

        echo "$settings" >"/tmp/${PAK_NAME}-old-settings.json"
        echo "$new_settings" >"/tmp/${PAK_NAME}-new-settings.json"

        old_enabled="$(jq -rM '.settings[0].selected' "/tmp/${PAK_NAME}-old-settings.json")"
        enabled="$(jq -rM '.settings[0].selected' "/tmp/${PAK_NAME}-new-settings.json")"

        old_start_on_boot="$(jq -rM '.settings[1].selected' "/tmp/${PAK_NAME}-old-settings.json")"
        start_on_boot="$(jq -rM '.settings[1].selected' "/tmp/${PAK_NAME}-new-settings.json")"

        old_login_selection="$(jq -rM '.settings[2].selected // 0' "/tmp/${PAK_NAME}-old-settings.json")"
        old_login_input="$(jq -rM '.settings[2].input.login_server_url // ""' "/tmp/${PAK_NAME}-old-settings.json")"
        new_login_selection="$(jq -rM '.settings[2].selected // 0' "/tmp/${PAK_NAME}-new-settings.json")"
        new_login_input="$(jq -rM '.settings[2].input.login_server_url // ""' "/tmp/${PAK_NAME}-new-settings.json")"

        if [ "$old_login_selection" != "$new_login_selection" ] || [ "$old_login_input" != "$new_login_input" ]; then
            save_login_server_state "$new_settings"
        fi

        if [ "$old_enabled" != "$enabled" ]; then
            if [ "$enabled" = "1" ]; then
                show_message "Starting $HUMAN_READABLE_NAME." 2

                if ! tailscale_start; then
                    show_message "Failed to enable $HUMAN_READABLE_NAME." 2
                    continue
                fi

                if ! wait_for_service 10; then
                    show_message "Failed to start $HUMAN_READABLE_NAME." 2
                fi

                if ! tailscale_is_logged_in; then
                    authkey="$(tailscale_get_authkey)"
                    if [ -z "$authkey" ]; then
                        show_message "No authkey file found." 2
                        service_off
                        continue
                    fi

                    login_server="$(tailscale_get_login_server "$new_settings")"
                    save_login_server_state "$new_settings"

                    if ! tailscale_login "$authkey" "$login_server"; then
                        show_message "Failed to login to $HUMAN_READABLE_NAME." 2
                        service_off
                        continue
                    fi
                fi

                killall minui-presenter >/dev/null 2>&1 || true
            else
                show_message "Disabling $HUMAN_READABLE_NAME." 2
                if ! service_off; then
                    show_message "Failed to disable $HUMAN_READABLE_NAME." 2
                fi

                show_message "Waiting for $HUMAN_READABLE_NAME to stop." forever
                if ! wait_for_service_to_stop 10; then
                    show_message "Failed to stop $HUMAN_READABLE_NAME." 2
                fi
                killall minui-presenter >/dev/null 2>&1 || true
            fi
        fi

        if [ "$old_start_on_boot" != "$start_on_boot" ]; then
            if [ "$start_on_boot" = "1" ]; then
                show_message "Enabling start on boot." 2
                if ! enable_start_on_boot; then
                    show_message "Failed to enable start on boot." 2
                fi
            else
                show_message "Disabling start on boot" 2
                if ! disable_start_on_boot; then
                    show_message "Failed to disable start on boot." 2
                fi
            fi
        fi
    done
}

main "$@"
