#!/bin/bash

# Required tools for script operation:
# sudo apt install libimage-exiftool-perl

CURRENT_DIR="$(pwd)"
TARGET_DIR=
DESTINATION_DIR=
CHECK_YEAR=
PERCENTAGE=
PERCENTAGE_UNDONE=

text_color_clear="00"

text_attribute_normal="0"
text_attribute_bold="1"

text_color_green="32"
text_color_blue="34"
text_color_purple="35"
text_color_red="31"
text_color_white="37"
text_color_yellow="33"

style() {
    echo "\e[${2};${1}m"
}

text_normal="$(style ${text_color_clear} ${text_attribute_normal})"
text_green="$(style ${text_color_green} ${text_attribute_normal})"
text_blue="$(style ${text_color_blue} ${text_attribute_normal})"
text_purple="$(style ${text_color_purple} ${text_attribute_normal})"
text_red_b="$(style ${text_color_red} ${text_attribute_bold})"
text_white_b="$(style ${text_color_white} ${text_attribute_bold})"
text_yellow="$(style ${text_color_yellow} ${text_attribute_normal})"
text_yellow_b="$(style ${text_color_yellow} ${text_attribute_bold})"

print_help() {
    echo -e "
${text_yellow}Usage:${text_normal}
${0} -t <target directory> [-d <destination directory>] [-y <year>] [-h]
${text_yellow}Options:${text_normal}
    -t - Set target directory for scpipt operations. All files there will be renamed;
    -d - Set destination directory. All files will be moved there according to rules;
    -y - Check year for files in target directory (applies for all subdirs);
    -h - Print this help message.
${text_yellow}Example:${text_normal}
${0} -t ~/Pictures -d ~/Pictures/MyDir -y 2018"
}

print_welcome_warning() {
    echo -e "\n${text_yellow_b}*** WARNING! DO NOT IGNORE! ***
${text_yellow}This script is going to modify some directories and files in selected directory.
Make sure you have a backup of all data that is going to be modified by this
script. This is a early alpha version, so everything could happen, including
all critical data lost.${text_normal}
"
    read -n 1 -s -r -p "Press any key to continue or Ctrl+C to exit
"
}

fix_media_dir_names() {
    search_directory="${1}"

    echo -e "${text_purple}Fix directory names${text_normal}"
    for i in $(seq 1 $(find ${search_directory} -type d | sed 's|[^/]||g' | sort | tail -n1 | awk '{ print length }')); do
        find ${search_directory} -maxdepth ${i} -type d -print0 | sort -z | \
        while IFS= read -r -d $'\0' dir; do
            new_dir=$(echo "${dir}" | sed "s|\[||g" | sed "s|\]||g" | sed "s|)||g" | sed "s|(||g" | sed "s|+|_|g" | sed "s| |_|g" | sed "s|'|_|g" | sed "s|#|_|g" | sed "s|,|_|g" | sed "s|!|_|g")
            if [ "${dir}" != "${new_dir}" ]; then
                echo -e "${text_white_b}RENAME:${text_normal} ${dir} -> ${text_yellow}${new_dir}${text_normal}"
                mv "${dir}" "${new_dir}" > /dev/null 2>&1
            fi
        done
    done
}

fix_media_file_names() {
    search_directory="${1}"

    echo -e "${text_purple}Fix files names${text_normal}"
    find ${search_directory} \( \
        -iname '*.jpg' \
        -o -iname '*.jpeg' \
        -o -iname '*.png' \
        -o -iname '*.cr2' \
        -o -iname '*.mp4' \
        -o -iname '*.mov' \
        -o -iname '*.3gp' \
        -o -iname '*.mts' \
        -o -iname '*.avi' \
        -o -iname '*.flv' \
        -o -iname '*.m2ts' \
        -o -iname '*.mpeg' \
        -o -iname '*.vob' \
    \) -print0 | sort -z | \
    while IFS= read -r -d $'\0' file; do
        new_file=$(echo "${file}" | sed "s|\[||g" | sed "s|\]||g" | sed "s|)||g" | sed "s|(||g" | sed "s|+|_|g" | sed "s| |_|g" | sed "s|'|_|g" | sed "s|#|_|g" | sed "s|,|_|g" | sed "s|!|_|g")
        if [ "${file}" != "${new_file}" ]; then
            echo -e "${text_white_b}RENAME:${text_normal} ${file} -> ${text_yellow}${new_file}${text_normal}"
            mv "${file}" "${new_file}" > /dev/null 2>&1
        fi
    done
}

normalize_media_file() {
    full_path_to_file="${1}"
    file_dir="$(dirname "${full_path_to_file}")"
    file_name="${full_path_to_file##*/}"
    file_extension="${file_name##*.}"
    file_extension="${file_extension,,}"
    done_file="${file_dir}/done.txt"
    undone_file="${file_dir}/undone.txt"

    # Try to get required info from media metadata
    case "${file_extension}" in
    "jpg" | "png" | "jpeg" | "cr2" | "mp4" | "mov" | "3gp")
        metadata="$(exiftool -CreateDate ${full_path_to_file} | sed -n 1p)"
        # Create Date                     : 2006:11:01 09:54:54
        ;;
    "mts")
        metadata="$(exiftool -ExtractEmbedded -DateTimeOriginal ${full_path_to_file} | sed -n 1p)"
        # Date/Time Original              : 2012:08:14 12:12:25+03:00
        ;;
    "avi" | "flv" | "m2ts" | "mpeg" | "vob" | "mod")
        # request manual info
        echo -e "${text_red_b}SKIP:${text_normal}   ${full_path_to_file}"
        echo "${file_name}" >> ${undone_file}

        return 1
        ;;
    *)
        # unsupported extension
        ;;
    esac

    if [ ! "${metadata}" ]; then
        echo -e "${text_red_b}SKIP:${text_normal}   ${full_path_to_file}"
        echo "${file_name}" >> ${undone_file}

        return 1
    fi

    # Photo / Video configs
    case "${file_extension}" in
    "jpg" | "png" | "cr2")
        prefix="IMG"
        ;;
    "jpeg")
        prefix="IMG"
        file_extension="jpg"
        ;;
    "avi" | "flv" | "m2ts" | "mpeg" | "vob" | "mp4" | "mov" | "3gp" | "mts" | "mod")
        prefix="VID"
        ;;
    *)
        # unsupported extension
        ;;
    esac

    raw_date="$(echo ${metadata} | sed 's/^.*: //' | sed 's/+.*//')"
    date="$(echo ${raw_date} | cut -f1 -d' ')"
    time="$(echo ${raw_date} | cut -f2 -d' ')"

    year=$(echo ${date:0:4})
    month=$(echo ${date:5:2})
    day=$(echo ${date:8:2})
    hour=$(echo ${time:0:2})
    minute=$(echo ${time:3:2})
    second=$(echo ${time:6:2})

    if [ "${year}" == "0000" ] ||
       [ "${month}" == "00" ] ||
       [ "${day}" == "00" ]; then
        echo -e "${text_red_b}SKIP:${text_normal}   ${full_path_to_file}"
        echo "${file_name}" >> ${undone_file}

        return 1
    fi

    if [ ${CHECK_YEAR} ] &&
       [ "${year}" != "${CHECK_YEAR}" ]; then
        echo -e "${text_red_b}SKIP:${text_normal}   ${full_path_to_file}"
        echo "${file_name}" >> ${undone_file}

        return 1
    fi

    new_file_name="${prefix}_${year}${month}${day}_${hour}${minute}${second}.${file_extension}"
    id=0

    if [ "${new_file_name}" != "${file_name}" ]; then
        new_file_name="${prefix}_${year}${month}${day}_${hour}${minute}${second}_$(printf "%03d" ${id}).${file_extension}"

        while [ -a ${file_dir}/${new_file_name} ]; do
            if [ "${new_file_name}" != "${file_name}" ]; then
                # Check uniq name
                ((id++))

                new_file_name="${prefix}_${year}${month}${day}_${hour}${minute}${second}_$(printf "%03d" ${id}).${file_extension}"
            else
                break
            fi
        done

        mv ${full_path_to_file} ${file_dir}/${new_file_name} > /dev/null 2>&1
    fi

    # if [ "${file_extension}" == "jpg" ]; then
    #     convert -interlace Plane -gaussian-blur 0.05 -quality 85% \
    #     ${full_path_to_file} \
    #     ${file_dir}/${new_file_name} > /dev/null 2>&1
    # fi

    new_date="${year}:${month}:${day} ${hour}:${minute}:${second}"
    exiftool \
    -overwrite_original \
    -CreateDate="${new_date}" \
    -ModifyDate="${new_date}" \
    -TrackCreateDate="${new_date}" \
    -TrackModifyDate="${new_date}" \
    -MediaCreateDate="${new_date}" \
    -MediaModifyDate="${new_date}" \
    -Label= -Subject= -Keywords= \
    ${file_dir}/${new_file_name} > /dev/null 2>&1 &
    chmod 664 ${file_dir}/${new_file_name}

    echo -e "${text_white_b}RENAME:${text_normal} [${text_green}$(printf "%3d%%" ${PERCENTAGE})${text_normal}] ${full_path_to_file} -> ${text_yellow}${new_file_name}${text_normal}"
    echo -e "RENAME: [$(printf "%3d%%" ${PERCENTAGE})] ${full_path_to_file} -> ${new_file_name}" >> ${done_file}
}

manually_normalize_media_file() {
    full_path_to_file="${1}"
    user_date="${2}"
    file_dir="$(dirname "${full_path_to_file}")"
    file_name="${full_path_to_file##*/}"
    file_extension="${file_name##*.}"
    file_extension="${file_extension,,}"
    done_file="${file_dir}/done.txt"

    # Photo / Video configs
    case "${file_extension}" in
    "jpg" | "png" | "cr2")
        prefix="IMG"
        ;;
    "jpeg")
        prefix="IMG"
        file_extension="jpg"
        ;;
    "avi" | "flv" | "m2ts" | "mpeg" | "vob" | "mp4" | "mov" | "3gp" | "mts" | "mod")
        prefix="VID"
        ;;
    esac

    date=$(echo ${user_date} | cut -f1 -d' ')
    time=$(echo ${user_date} | cut -f2 -d' ')

    year=$(echo ${date:0:4})
    month=$(echo ${date:5:2})
    day=$(echo ${date:8:2})
    hour=$(echo ${time:0:2})
    minute=$(echo ${time:3:2})
    second=$(echo ${time:6:2})

    new_file_name="${prefix}_${year}${month}${day}_${hour}${minute}${second}.${file_extension}"
    id=0

    if [ "${new_file_name}" != "${file_name}" ]; then
        new_file_name="${prefix}_${year}${month}${day}_${hour}${minute}${second}_$(printf "%03d" ${id}).${file_extension}"

        while [ -a ${file_dir}/${new_file_name} ]; do
            if [ "${new_file_name}" != "${file_name}" ]; then
                # Check uniq name
                ((id++))

                new_file_name="${prefix}_${year}${month}${day}_${hour}${minute}${second}_$(printf "%03d" ${id}).${file_extension}"
            else
                break
            fi
        done

        mv ${full_path_to_file} ${file_dir}/${new_file_name} > /dev/null 2>&1
    fi

    # if [ "${file_extension}" == "jpg" ]; then
    #     convert -interlace Plane -gaussian-blur 0.05 -quality 85% \
    #     ${full_path_to_file} \
    #     ${file_dir}/${new_file_name} > /dev/null 2>&1
    # fi

    new_date="${year}:${month}:${day} ${hour}:${minute}:${second}"
    exiftool \
    -overwrite_original \
    -CreateDate="${new_date}" \
    -ModifyDate="${new_date}" \
    -TrackCreateDate="${new_date}" \
    -TrackModifyDate="${new_date}" \
    -MediaCreateDate="${new_date}" \
    -MediaModifyDate="${new_date}" \
    -DateTimeOriginal="${new_date}" \
    -Label= -Subject= -Keywords= \
    ${file_dir}/${new_file_name} > /dev/null 2>&1 &
    chmod 664 ${file_dir}/${new_file_name}

    echo -e "${text_white_b}RENAME:${text_normal} [${text_green}$(printf "%3d%%" ${PERCENTAGE_UNDONE})${text_normal}] ${file_name} -> ${text_yellow}${new_file_name}${text_normal}"
    echo -e "RENAME: [$(printf "%3d%%" ${PERCENTAGE_UNDONE})] ${file_name} -> ${new_file_name}" >> ${done_file}
}

fix_undone_files() {
    undone_file=${1}
    directory=$(dirname "${undone_file}")
    response=

    total_files_undone=$(cat ${undone_file} | wc -l)
    files_processed_undone=0

    echo -en "${text_white_b}MANUAL:${text_normal} [${text_blue}$(printf "%3d%%" ${PERCENTAGE})${text_normal}] Enter date (YYYY.MM.DD) for ${directory}: "
    read response < /dev/tty

    if [ ! "${response}" ]; then
        return 0
    fi

    while read file; do
        ((files_processed_undone++))
        PERCENTAGE_UNDONE=$((files_processed_undone * 100 / total_files_undone))
        manually_normalize_media_file ${directory}/${file} "${response} 00:00:00"
    done < ${undone_file}

    rm -rf ${undone_file}
}

normalize_media_files() {
    search_directory="${1}"

    total_files=$(find ${search_directory} -type f \( \
        -iname '*.jpg' \
        -o -iname '*.jpeg' \
        -o -iname '*.png' \
        -o -iname '*.cr2' \
        -o -iname '*.mp4' \
        -o -iname '*.mov' \
        -o -iname '*.mod' \
        -o -iname '*.3gp' \
        -o -iname '*.mts' \
        -o -iname '*.avi' \
        -o -iname '*.flv' \
        -o -iname '*.m2ts' \
        -o -iname '*.mpeg' \
        -o -iname '*.vob' \
    \) | wc -l)
    files_processed=0

    echo -e "${text_purple}Normalize media files${text_normal}"
    find ${search_directory} -type f \( \
        -iname '*.jpg' \
        -o -iname '*.jpeg' \
        -o -iname '*.png' \
        -o -iname '*.cr2' \
        -o -iname '*.mp4' \
        -o -iname '*.mov' \
        -o -iname '*.mod' \
        -o -iname '*.3gp' \
        -o -iname '*.mts' \
        -o -iname '*.avi' \
        -o -iname '*.flv' \
        -o -iname '*.m2ts' \
        -o -iname '*.mpeg' \
        -o -iname '*.vob' \
    \) -print0 | sort -z | \
    while IFS= read -r -d $'\0' file; do
        ((files_processed++))
        PERCENTAGE=$((files_processed * 100 / total_files))
        normalize_media_file ${file}
    done

    total_files=$(find ${search_directory} -type f \( \
        -iname 'undone.txt' \
    \) | wc -l)
    files_processed=0

    echo -e "${text_purple}Normalize skipped media files${text_normal}"
    find ${search_directory} -type f \( \
        -iname 'undone.txt' \
    \) -print0 | sort -z | \
    while IFS= read -r -d $'\0' file; do
        ((files_processed++))
        PERCENTAGE=$((files_processed * 100 / total_files))
        fix_undone_files ${file}
    done
}

copy_media_file() {
    full_path_to_file=${1}
    destination_directory=${2}
    file_dir=$(dirname "${full_path_to_file}")
    file_name=${full_path_to_file##*/}
    file_extension="${file_name##*.}"
    file_extension="${file_extension,,}"
    moved_file="${file_dir}/moved.txt"

    # IMG_20160618_074738_001.jpg
    year=$(echo ${file_name:4:4})
    month=$(echo ${file_name:8:2})

    num_underlines=$(grep -o "_" <<< "${file_name}" | wc -l)

    if [ -a ${destination_directory}/${year}/${month}/${file_name} ]; then
        case ${num_underlines} in
        2)
            id=0
            file_name="${file_name:0: -4}_$(printf "%03d" ${id}).${file_extension}"
            ;;
        3)
            id=${file_name:20:3}
            ((id++))
            file_name="${file_name:0: -8}_$(printf "%03d" ${id}).${file_extension}"
            ;;
        esac
    fi

    while [ -a ${destination_directory}/${year}/${month}/${file_name} ]; do
        ((id++))

        file_name="${file_name:0: -8}_$(printf "%03d" ${id}).${file_extension}"
    done

    mkdir -p ${destination_directory}/${year}/${month}
    cp -f ${full_path_to_file} ${destination_directory}/${year}/${month}/${file_name}

    echo -e "${text_white_b}COPY:${text_normal}   [${text_green}$(printf "%3d%%" ${PERCENTAGE})${text_normal}] ${text_yellow}${full_path_to_file}${text_normal} -> ${destination_directory}/${year}/${month}/${file_name}"
    echo -e "COPY:   [$(printf "%3d%%" ${PERCENTAGE})] ${full_path_to_file} -> ${destination_directory}/${year}/${month}/${file_name}" >> ${moved_file}
}

copy_media_files() {
    search_directory=${1}
    destination_directory=${2}

    total_files=$(find ${search_directory} -type f \( \
        -iname '*.jpg' \
        -o -iname '*.jpeg' \
        -o -iname '*.png' \
        -o -iname '*.cr2' \
        -o -iname '*.mp4' \
        -o -iname '*.mov' \
        -o -iname '*.mod' \
        -o -iname '*.3gp' \
        -o -iname '*.mts' \
        -o -iname '*.avi' \
        -o -iname '*.flv' \
        -o -iname '*.m2ts' \
        -o -iname '*.mpeg' \
        -o -iname '*.vob' \
    \) | wc -l)
    files_processed=0

    find ${search_directory} -type f \( \
        -iname '*.jpg' \
        -o -iname '*.jpeg' \
        -o -iname '*.png' \
        -o -iname '*.cr2' \
        -o -iname '*.mp4' \
        -o -iname '*.mov' \
        -o -iname '*.mod' \
        -o -iname '*.3gp' \
        -o -iname '*.mts' \
        -o -iname '*.avi' \
        -o -iname '*.flv' \
        -o -iname '*.m2ts' \
        -o -iname '*.mpeg' \
        -o -iname '*.vob' \
    \) -print0 | sort -z | \
    while IFS= read -r -d $'\0' file; do
        ((files_processed++))
        PERCENTAGE=$((files_processed * 100 / total_files))
        copy_media_file ${file} ${destination_directory}
    done
}

while getopts "t:d:y:h" opt; do
    case $opt in
        t)
            TARGET_DIR="${OPTARG}"
            ;;
        d)
            DESTINATION_DIR="${OPTARG}"
            ;;
        y)
            CHECK_YEAR="${OPTARG}"
            ;;
        h)
            print_help

            exit 0
            ;;
        \?)
            print_help

            exit 0
            ;;
    esac
done

if [ ! ${TARGET_DIR} ]; then
    print_help

    exit 0
fi

print_welcome_warning

fix_media_dir_names ${TARGET_DIR}
fix_media_file_names ${TARGET_DIR}

normalize_media_files ${TARGET_DIR}

if [ ${DESTINATION_DIR} ]; then
    copy_media_files ${TARGET_DIR} ${DESTINATION_DIR}
fi
