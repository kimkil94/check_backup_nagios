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
#         NOTES:  TODO - Add functionality that check only checksum of the file that is also copied to NAS. Do not check with gunzip \
#		  again same file!! As sysadmin I want to know if file is correctly copied to NAS!
#        AUTHOR:   (Kimkil), 
#       COMPANY:  
#       VERSION:  1.0
#       CREATED:  03/11/2017 07:07:10 PM CET
#      REVISION:  ---
#===============================================================================

LIST_FILE="/opt/backup_files"
DATE=$(date +%Y-%m-%d)
SUMFILE="/opt/backup_files_checksums"

if [ ! -f ${LIST_FILE} ];then
    touch ${LIST_FILE} 
    echo "File ${LIST_FILE} created."
    exit 0 
fi

if [ ! -f ${SUMFILE} ];then
    touch ${SUMFILE} 
    echo "File ${SUMFILE} created."
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

sum_and_save() {
    local sum_file=${1}
    local checksum=""
    if [ -f ${sum_file} ];then
        checksum=$(md5sum ${sum_file} |awk '{print $1}')
        if grep ${sum_file} ${SUMFILE} > /dev/null 2>&1 ;then
            sum_for_replace=$(grep ${sum_file} ${SUMFILE} | awk '{print $1}')
            sed -i "s/"${sum_for_replace}"/"${checksum}"/g" ${SUMFILE}
        else
            echo ${checksum} ${sum_file} >> ${SUMFILE}
        fi
    else
        echo "File: $sum_file doesnt exist!"
        ((err_count++))
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


comp_sum_local_nas(){
    local local_file=${1}
    local nas_file=${2}
    sum_local_file=$(md5sum ${local_file} | awk '{print $1}')
    sum_nas_file=$(md5sum ${nas_file} | awk '{print $1}')
    if [ "${sum_local_file}" = "${sum_nas_file}" ];then
        echo "[DEBUG] SUMLOCAL= ${sum_local_file}"
        echo "[DEBUG SUMNAS = ${sum_local_file}]" 
       return 0
   else
       echo "[DEBUG] SUMLOCAL= ${sum_local_file}"
        echo "[DEBUG SUMNAS = ${sum_local_file}]"  
      return 1
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
    nas_backup=$(echo $line | awk '{print $5}')
    if [ "${nas_backup}" = "yes" ];then
        nas_mount=$(echo $line | awk '{print $6}')
    fi
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
                ##############################################
                if [ ! "${nas_backup}" = "yes" ];then
                    if [ "${type_of_file}" = "tar.gz" ];then
                        archive_test "${path_to_file}"
                        sum_and_save "${path_to_file}"
                    else
                        sum_and_save "${path_to_file}"
                    fi
                elif [ "${nas_backup}" = "yes" ];then
                    if comp_sum_local_nas "${path_to_file}" "${nas_mount}$(basename ${path_to_file})" ;then
                        echo "NAS backup for ${name} in place ${nas_mount}$(basename ${path_to_file})"
                    else
                        echo "Error NAS backup for ${name} not in place!"
                    fi
                else
                    exit 1
                fi
                ################################################ <-----------------
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
                if [ ! "${nas_backup}" = "yes" ];then
                    if [ "${type_of_file}" = "tar.gz" ];then
                        archive_test "${path_to_file}"
                        sum_and_save "${path_to_file}"
                    else
                        sum_and_save "${path_to_file}"
                    fi
                elif [ "${nas_backup}" = "yes" ];then
                    if comp_sum_local_nas "${path_to_file}" "${nas_mount}$(basename ${path_to_file})" ;then
                        echo "NAS backup for ${name} in place ${nas_mount}$(basename ${path_to_file})"
                    else
                        echo "Error NAS backup for ${name} not in place!"
                    fi
                else
                    exit 1
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
    exit 1
else
    echo "########################################################################"
    echo "####################### SUMARRY ########################################"
    echo " -> OK - All backups are healthy! You are save! "
    echo "########################################################################"
    exit 0
fi

