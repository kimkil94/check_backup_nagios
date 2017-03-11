#!/bin/bash
#===============================================================================
#
#          FILE:  check_backup.sh
# 
#         USAGE:  ./check_backup.sh 
# 
#   DESCRIPTION:  
# 
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:   (Kimkil), 
#       COMPANY:  
#       VERSION:  1.0
#       CREATED:  03/11/2017 07:07:10 PM CET
#      REVISION:  ---
#===============================================================================

LIST_FILE="/opt/backup_files"
DATE=$(date +%Y-%m-%d)

if [ ! -f ${LIST_FILE} ];then
    touch ${LIST_FILE} 
    echo "File ${LIST_FILE} created."
    exit 0 
fi

archive_test() {
    #only tar.gz files
    local file=${1}
    if `gunzip -c ${file} | tar t  >/dev/null 2>&1`; then
        echo -ne "\t -> Archive file $(basename ${file}) tested. - OK\n"
        return 0
    else
        echo -ne "\t -> Archive file $(basename ${file}) is NOT OK. TEST end with errors. - ERROR\n"
        ((err_count++))
        return 1
    fi
}


string_replace() {
    echo "${1/\*/$2}"
}

get_file_size(){
    local file=${1}
    local unit=${2}
    local size_of_file=""
    if [ ! -z ${file}  ];then
        if [ "${unit}" = "MB" ];then
            size_of_file=$(du -m ${file} | awk '{print $1}')
            echo ${size_of_file}
        elif [ "${unit}" = "GB" ];then
            size_of_file=$(du -m ${file} | awk '{print $1}')
            echo ${size_of_file}
        else
            exit 1
        fi
    else
        exit 1
    fi

}


err_count="0"
# read file that contain backup files and parameters
while read -r line; do
    # read line by line, comments line will be ignored/ starting with # (^#)
    [[ "$line" =~ ^#.*$ ]] && continue
    # put all columns to variables
    name=$(echo $line | awk '{print $1}' )
    path_to_file=$(echo "$line" | awk '{print $2}')
    if [[ "$path_to_file" = *DAY* ]]; then
        path_to_file=$(echo $path_to_file | sed "s/DAY/${DATE}/g" )
    fi    
    type_of_file=$(echo $line | awk '{print $3}')
    minimal_size=$(echo $line | awk '{print $4}')

    # if minimal size of backup file is in GBs
    if [ -f ${path_to_file} ];then
        if [[ "${minimal_size}" =~ GB$ ]]; then
            # get actual using get_file_size function  
            actual_size=$(get_file_size ${path_to_file} "GB" )
            # minimal_size without unit 
            minimal_size=$(echo $line | awk '{print $4}' | sed 's/GB//g')

            echo "#####--------------------------------------------------------------------------------------------------------------------------#####"
            # if actual size is greater than or equal to minimal_size that is set in LIST_FILE
            if [ "${actual_size}" -gt "${minimal_size}"   ] || [ "${actual_size}" -eq "${minimal_size}" ]; then
                echo "Backup :  ${name} is created ; File : $(basename ${path_to_file}) ; Type : ${type_of_file} ; Size :   ${actual_size}GB -> [OK]"

                if [ "${type_of_file}" = "tar.gz" ];then
                    archive_test "${path_to_file}"
                fi
            elif [ "${actual_size}" -lt "${minimal_size}" ]; then
                echo "Backup : ${name} not created ; File : $(basename ${path_to_file}) ; Type : ${type_of_file} ; Size :  ${actual_size}GB -> [ERROR]"
                ((err_count++))
                return 1
            fi
            echo "#####--------------------------------------------------------------------------------------------------------------------------#####"
        # if minimal size of backup file is in MBs
        elif [[ "${minimal_size}" =~ MB$ ]]; then
            actual_size=$(get_file_size ${path_to_file} "MB" )
            minimal_size=$(echo $line | awk '{print $4}' | sed 's/MB//g')
            echo "#####--------------------------------------------------------------------------------------------------------------------------#####"
            if [ "${actual_size}" -gt "${minimal_size}"   ] || [ "${actual_size}" -eq "${minimal_size}" ]; then
                echo "Backup :  ${name} is created ; File : $(basename ${path_to_file}) ; Type : ${type_of_file} ; Size :   ${actual_size}MB -> [OK]"
                if [ "${type_of_file}" = "tar.gz" ];then
                    archive_test "${path_to_file}"
                fi

            elif [ "${actual_size}" -lt "${minimal_size}" ]; then
                echo "Backup : ${name} not created ; File : $(basename ${path_to_file}) ; Type : ${type_of_file} ; Size :  ${actual_size}MB -> [ERROR]"
                ((err_count++))
            fi
            echo "#####--------------------------------------------------------------------------------------------------------------------------#####"
        fi
    else
        echo "Backup : $name is NOT OK ; File: $(basename ${path_to_file}) does not exist! - ERROR"
        ((err_count++))
    fi
done < "${LIST_FILE}"

if [ "${err_count}" -gt "0" ];then
    echo "########################################################################"
    echo "############################# SUMARRY ##################################"
    echo " -> ERROR -At least one Backup file is not correctly created!"
    echo "########################################################################"
else
    echo "########################################################################"
    echo "####################### SUMARRY ########################################"
    echo " -> OK - All backups are healthy! You are save! "
    echo "########################################################################"
fi

