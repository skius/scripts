#!/bin/bash
# https://github.com/MisterSkilly/scripts
# This script finds new files from your plex libraries and issues a CLI scan for them.
# Useful in setups where Plex's automatic scan-on-new-files doesnt work such as network mounts.
# Run this with flock on cron, as often as you like.
# Inspiration: https://github.com/ajkis/scripts/blob/master/plex/plex-scan-new.sh


echo "########### $(date "+%d.%m.%Y %T") -  Starting Just Another Plex Scanner   #########"

startscan=$(date +'%s')

CACHE="$HOME/.cache/japs"
MOVIESECTION=4
MOVIELIBRARY="/path/to/your/plex/movie/library"
TVSECTION=3
TVLIBRARY="/path/to/your/plex/tv/library"

export LD_LIBRARY_PATH=/usr/lib/plexmediaserver
export PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR=/var/lib/plexmediaserver/Library/Application\ Support


#Setting up files and directories for first run
mkdir -p "$CACHE"

if [[ ! -f "$CACHE/movies_files_sorted_old" ]]; then
    touch "$CACHE/movies_files_sorted_old"
fi

if [[ ! -f "$CACHE/tv_files_sorted_old" ]]; then
    touch "$CACHE/tv_files_sorted_old"
fi

### ATTENTION: You could run this script on a different (e.g. Plexdrive 5) mount in order to minimize stress on main mount.
###            Later in this script you would replace the path of the temp mount with the main mount path, so that Plex finds the files.
###            If you don't care about the stress on your main mount, you can ignore this.

echo "Listing movie files..."
find "$MOVIELIBRARY" -type f -not -name "*.srt" > "$CACHE/movies_files"
echo "Listed movie files"
echo "Listing tv files..."
find "$TVLIBRARY" -type f -not -name "*.srt" > "$CACHE/tv_files"
echo "Listed tv files"

echo "Sorting files..."
sort "$CACHE/movies_files" > "$CACHE/movies_files_sorted"
sort "$CACHE/tv_files" > "$CACHE/tv_files_sorted"
echo "Sorted files"

echo ""

if [ -s "$CACHE/movies_files_sorted" ]
then
    echo "There are movies (mount is not broken)"

    echo "Finding new movies..."

    touch "$CACHE/movies_to_scan"

    while read -r mfile
    do
        echo "$(date "+%d.%m.%Y %T") New file detected: $mfile"
        MFOLDER=$(dirname "${mfile}")
        echo "$MFOLDER" >> "$CACHE/movies_to_scan"
    done < <(comm -13 "$CACHE/movies_files_sorted_old" "$CACHE/movies_files_sorted")

    sort "$CACHE/movies_to_scan" | uniq | tee "$CACHE/movies_to_scan"

    if [ -s "$CACHE/movies_to_scan" ]
    then
        echo "Found new movies"
        echo "Starting plex movies scan..."
        
        #aborting if exit != 0
        set -e
        
        readarray -t MOVIES < "$CACHE/movies_to_scan"
        for MOVIE in "${MOVIES[@]}"
        do
            # REPLACING TEMP MOUNT WITH MAIN MOUNT
#            MOVIE="${MOVIE/tmp/main}"
# Change the following line to implement some sort of notification.
#            echo "Scanning movie \"$( basename "$MOVIE" )\" on $(hostname)..." | /some-script.sh
            echo "$(date "+%d.%m.%Y %T") Plex scan movie folder:: $MOVIE"
            $LD_LIBRARY_PATH/Plex\ Media\ Scanner --scan --refresh --section "$MOVIESECTION" --directory "$MOVIE"
        done
        
        set +e
        echo "Plex movies scan finished"
        echo "Preparing cache files for next scan..."
        
        mo=$( wc -c "$CACHE/movies_files_sorted_old" | awk '{print $1}' )
        mn=$( wc -c "$CACHE/movies_files_sorted" | awk '{print $1}')
        #echo $mo
        #echo $mn
        if (( $(( $mn + 30000 )) > $mo )); then
            echo "Updating movies file"
            mv "$CACHE/movies_files_sorted" "$CACHE/movies_files_sorted_old"
        else
            echo "New movies file is significantly smaller, assuming something broke and not updating movies file."
            rm "$CACHE/movies_files_sorted"
        fi
        
        
    else
        echo "No new movies found"
        
    fi

else
        echo "There are no movies (mount is likely broken, aborting movies scan)"
fi

echo ""

rm "$CACHE/movies_files"
rm "$CACHE/movies_to_scan"
rm "$CACHE/movies_files_sorted"

if [ -s "$CACHE/tv_files_sorted" ]
then
    echo "There are TV files (mount is not broken)"

    echo "Finding new TV files..."

    touch "$CACHE/tv_to_scan"

    while read -r tvfile
    do
        echo "$(date "+%d.%m.%Y %T") New file detected: $tvfile"
        MFOLDER=$(dirname "${tvfile}")
        echo "$MFOLDER" >> "$CACHE/tv_to_scan"
    done < <(comm -13 "$CACHE/tv_files_sorted_old" "$CACHE/tv_files_sorted")

    sort "$CACHE/tv_to_scan" | uniq | tee "$CACHE/tv_to_scan"

    if [ -s "$CACHE/tv_to_scan" ]
    then
        echo "Found new TV files"
        echo "Starting plex TV scan..."

        #aborting if exit != 0
        set -e

        readarray -t FOLDERS < "$CACHE/tv_to_scan"
        for FOLDER in "${FOLDERS[@]}"
        do
            # REPLACING TEMP MOUNT WITH MAIN MOUNT
#            FOLDER="${FOLDER/tmp/main}"
# Change the following line to implement some sort of notification.
#            echo "Scanning TV show \"$( basename "$( dirname "$FOLDER" )" )\" on $(hostname)..." | /some-script.sh
            echo "$(date "+%d.%m.%Y %T") Plex scan TV folder:: $FOLDER"
            $LD_LIBRARY_PATH/Plex\ Media\ Scanner --scan --refresh --section "$TVSECTION" --directory "$FOLDER"
        done

        set +e
        echo "Plex TV scan finished"
        echo "Preparing cache files for next scan..."

        to=$( wc -c "$CACHE/tv_files_sorted_old" | awk '{print $1}' )
        tn=$( wc -c "$CACHE/tv_files_sorted" | awk '{print $1}')
        if (( $(( $tn + 30000 )) > $to )); then
            echo "Updating TV file"
            mv "$CACHE/tv_files_sorted" "$CACHE/tv_files_sorted_old"
        else
            echo "New TV file is significantly smaller, assuming something broke and not updating TV file."
            rm "$CACHE/tv_files_sorted"
        fi


    else
        echo "No new TV files found"

    fi


else
        echo "There are no TV files (mount is likely broken, aborting TV scan)"
fi

rm "$CACHE/tv_to_scan"
rm "$CACHE/tv_files"
rm "$CACHE/tv_files_sorted"


echo "##### $(date "+%d.%m.%Y %T") - Just Another Plex Scanner finished in $(($(date +'%s') - $startscan)) seconds ####"
echo "#################################################################################"
