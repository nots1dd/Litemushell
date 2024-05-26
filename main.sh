#!/bin/bash

# LITEMUS (Light music player)

# written by nots1dd
# NOTE :: This script uses ffplay to play audio NOT PLAYERCTL
# HENCE, it will NOT work well with your current configs that use playerctl and such

# DEPENDENCIES
# 1. ffmpeg and its family tree (ffprobe, ffplay)
# 2. gum [AUR PACKAGE]
# 3. bc (basic calculator) [AUR PACKAGE]
# 4. viu (terminal image emulator) [AUR PACKAGE]
# 5. grep, awk, trap (very important basic unix tools)
# 6. jq (to parse json)

# Define color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PINK='\033[1;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

src="/home/$USER/misc/litemus" # change this to whatever directory litemus is in
dir_cache="/home/$USER/misc/litemus/.directorycache" # change this to whatever directory litemus is in
cache_dir="/home/$USER/misc/litemus/.cache/"
theme_dir="/home/s1dd/misc/litemus/.config/themes/theme.json"

# sources
source $src/utils/modules.sh

clear
check_directory

status_line=""
timer_line=""

display_logo() {
    echo -e "    " "${BLUE}${BOLD}LITEMUS - Light Music Player\n"
}

# Song Management
declare -a song_list
declare -a queue
current_index=-1


play() {
    clear
    display_logo
    gum style --padding "$gum_padding" --border double --border-foreground "$gum_border_foreground" "Play a song!"

    selected_artist=$(ls *.mp3 | awk -F ' - ' '{ artist = substr($1, 1, 512); print artist}' | sort -u | gum choose --header "$gum_select_artist_message" --cursor.foreground "$gum_selected_cursor_foreground" --selected.foreground "$gum_selected_text_foreground" --header.foreground "$gum_header_foreground" --limit 1 --height $gum_height)
    if [ "$selected_artist" = "user aborted" ]; then
        gum confirm --default --selected.foreground "$gum_confirm_selected_text_foreground" --unselected.foreground "$gum_confirm_unselected_text_foreground" --prompt.foreground "$gum_confirm_prompt_foreground" "Exit Litemus?" && exit || play
    else
        clear
        display_logo
        gum style --padding "$gum_padding" --border double --border-foreground "$gum_border_foreground" "You selected artist:  $(gum style --foreground "$gum_artist_foreground" "$selected_artist")"

        # Filter songs by selected artist
        mapfile -t song_list < <(ls *.mp3 | grep "^$selected_artist" | sort)

        # Ensure cache directory exists
        mkdir -p "$cache_dir"
        local cache_file="$cache_dir/${selected_artist// /_}.cache"

        if [ -f "$cache_file" ]; then
            load_sorted_songs_from_cache "$selected_artist"
        else
            sort_songs_by_album "$selected_artist"
            save_sorted_songs_to_cache "$selected_artist"
            gum spin --title="Caching artist..." -- sleep 0.3
        fi

        # Present the list of song names to the user for selection
        selected_song_display=$(printf "%s\n" "${song_display_list[@]}" | gum choose --header "$gum_select_song_message" --cursor.foreground "$gum_selected_cursor_foreground" --selected.foreground "$gum_selected_text_foreground" --header.foreground "$gum_header_foreground" --limit 1 --height $gum_height)
        
        if [ "$selected_song_display" = "user aborted" ] || [ -z "$selected_song_display" ]; then
            gum confirm --selected.foreground "$gum_confirm_selected_text_foreground" --unselected.foreground "$gum_confirm_unselected_text_foreground" --prompt.foreground "$gum_confirm_prompt_foreground" --default "Exit Litemus?" && exit || play
        else
            # Find the full name of the selected song
            selected_song=""
            for song in "${sorted_song_list[@]}"; do
                song_name=$(echo "$song" | awk -F ' - ' '{ print $2 }' | sed 's/\.mp3//' | tr -d '\n')
                if [ "$song_name" = "$selected_song_display" ]; then
                    selected_song="$song"
                    break
                fi
            done

            queue=("$selected_song" "${queue[@]}") # Add to the beginning of the queue
            current_index=0

            # Add the selected song to the played_songs array
            played_songs+=("$selected_song")

            ffplay_song_at_index "$current_index"
        fi
    fi
}





main() {
    clear
    load_songs
    load_theme "$theme_dir"
    play
}
main

# Variable to track playback status (0 = playing, 1 = paused)
paused=0

# Trap the SIGINT signal (Ctrl+C) to exit the playback
trap exit SIGINT
