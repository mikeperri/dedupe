#!/usr/bin/env bash
echo "Go to Finder"

osascript -e 'tell app "Finder" to display dialog "Select the folder with pictures"' || exit 1
dir=$(osascript -e 'the POSIX path of (choose folder)') || exit 1
cd $dir

rm -rf tmp
mkdir tmp
mkdir Duplicates

check_tmp_exists() {
    if [ ! -d tmp ]; then
        osascript -e 'tell app "Finder" to display dialog "Stopping because tmp folder was deleted"'
        exit 1
    fi
}

printf "Converting to 16x16 bitmaps"
for i in *.png; do
    check_tmp_exists
    printf "."
    $(sips -s format bmp "${i}" --out "tmp/${i%.*}.bmp" --resampleHeightWidth 16 16 &> /dev/null)
done
printf "\n"

TO_DUPLICATES=()
TO_DUPLICATES_LEN=0

printf "Comparing bitmaps"
for i in tmp/*.bmp; do
    check_tmp_exists
    i_name=$(basename ${i%.*})
    marked_for_deletion=0
    for e in ${TO_DUPLICATES[@]}; do if [[ "$e" = "$i_name" ]]; then marked_for_deletion=1; fi; done
    if [ $marked_for_deletion -eq 0 ]; then
        for j in tmp/*.bmp; do
            check_tmp_exists
            printf "."
            j_name=$(basename ${j%.*})
            # echo "Comparing ${i} ${j}"
            if [[ ${i} != ${j} ]]; then
                diff "${i}" "${j}" &> /dev/null
                if [ $? -eq 0 ]; then
                    TO_DUPLICATES[TO_DUPLICATES_LEN]=$j_name
                    let "TO_DUPLICATES_LEN += 1"
                    mv "${j_name}.png" "Duplicates/${j_name}.png"
                fi
            fi
        done
    fi
done
printf "\n"
echo "Done. Go to Finder"

MSG="Moved ${TO_DUPLICATES_LEN} photos to Duplicates folder

"
for i in ${TO_DUPLICATES[@]}; do
    MSG+="${i}.png
"
done
osascript -e 'tell app "Finder" to display dialog "'"${MSG}"'"'
open Duplicates

rm -rf tmp
