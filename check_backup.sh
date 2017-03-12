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

##################################
### Globals
# Path to file where are list of all backup files with options for each
# This file has 6 mandatory columns ,delimited by *space* -> Name_of_backup Backup_file_path Type_of_file Minimal_size(GB/MB) Nas_backup(yes/no \Nas_mount(MountPoint/none))
LIST_FILE="/opt/backup_files"
# Current date
DATE=$(date +%Y-%m-%d)
# File where are saved checksums values for backup files
SUMFILE="/opt/backup_files_checksums"

# create list_file and exit , not able to continue without this file!
if [ ! -f ${LIST_FILE} ];then
    touch ${LIST_FILE} 
    echo "File ${LIST_FILE} created."
    exit 0 
fi

# create file for storing checksums 
if [ ! -f ${SUMFILE} ];then
    touch ${SUMFILE} 
    echo "File ${SUMFILE} created."
fi

###################################
### Functions
###################################

### archive_test() - perform test against the tar.gz file. Test by dry run of decompressing 
# Arguments: $1 - absolute path to tar.gz file
# Returns: 
#           0 - success , archive file has been sucessfully decompressed
#           1 - failed, an error occured during decompression
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
###------------------------------------------------------------------------

### sum_and_save() - get the checksum of file and save it to file if does not exist yet, if exist replace it
# Arguments: $1 - absolut path to file
# Returns:
#           0 - if file exist and checksum was stored properly to $SUMFILE
#           1 - if file does not exist
sum_and_save() {
    local sum_file=${1}
    local checksum=""
    if [ -f ${sum_file} ];then
        checksum=$(md5sum ${sum_file} |awk '{print $1}')
        if grep ${sum_file} ${SUMFILE} > /dev/null 2>&1 ;then
            sum_for_replace=$(grep ${sum_file} ${SUMFILE} | awk '{print $1}')
            sed -i "s/"${sum_for_replace}"/"${checksum}"/g" ${SUMFILE}
            return 0
        else
            echo ${checksum} ${sum_file} >> ${SUMFILE}
            return 0
        fi
    else
        echo "File: $sum_file doesnt exist!"
        ((err_count++))
        return 1
    fi
}
###-------------------------------------------------------------------------

### string_replace() - replace string that is passed as argument $1 for string from argument $2

string_replace() {
    echo "${1/\*/$2}"
}
###-------------------------------------------------------------------------

### get_file_size() - get size of file and return in required units (MB/GB)
# Arguments:    $1 - absolut path to file
#               $2 - unit MegaBytes(MB) or GigaBytes(GB)
# Returns: 
#               $size_of_file 
#               exit 1 - if file path or correct unit were not provided
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
###--------------------------------------------------------------------------

### comp_sum_local_nas() - compare two checksums for local file and same file that was copied to NAS . Check for integrity of NAS backup.
# Arguments:    $1 - absolute path to local file
#               $2 - absolute path to file stored on NAS mount point
# Returns:
#               0 - if checksum of local file EQUAL to checksum of NAS file
#               1 - if checksum of local file DOES NOT EQUAL to checksum of NAS FILE
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
###-------------------------------------------------------------------------
##################################
####-------- MAIN ------------####

# null error counting variable
err_count="0"

# read file that contain backup files and parameters
while read -r line; do
    # read line by line, comments line will be ignored/ starting with # (^#)
    [[ "$line" =~ ^#.*$ ]] && continue
    ## put all columns to variables
    # parse options to variables
    name=$(echo $line | awk '{print $1}' )  # name of the backup
    path_to_file=$(echo "$line" | awk '{print $2}') #absolute path to backuped file
    # if path to file contain "DAY" it will be replaced by current DATE 
    if [[ "$path_to_file" = *DAY* ]]; then
        path_to_file=$(echo $path_to_file | sed "s/DAY/${DATE}/g" )
    fi    
    type_of_file=$(echo $line | awk '{print $3}') # type of file tar.gz or sql TODO: add support for sql files and prechecks!
    minimal_size=$(echo $line | awk '{print $4}') # minimal size of backup in GB/MB 
    nas_backup=$(echo $line | awk '{print $5}')   # if backup is also stored on some Network Attached Storage (NAS)
    # if backup file is stored also on NAS , mount point is needed 
    if [ "${nas_backup}" = "yes" ];then
        nas_mount=$(echo $line | awk '{print $6}')
    fi
    # if minimal size of backup file is in GBs
    if [ -f ${path_to_file} ];then
        # if size is in GigaBytes
        if [[ "${minimal_size}" =~ GB$ ]]; then
            # get actual using get_file_size function  
            actual_size=$(get_file_size ${path_to_file} "GB" )
            # minimal_size without unit 
            minimal_size=$(echo $line | awk '{print $4}' | sed 's/GB//g')

            echo "#####--------------------------------------------------------------------------------------------------------------------------#####"
            # if actual size is GREATER than or equal to minimal_size that is set in LIST_FILE
            if [ "${actual_size}" -gt "${minimal_size}"   ] || [ "${actual_size}" -eq "${minimal_size}" ]; then
                echo "Backup :  ${name} is created ; File : $(basename ${path_to_file}) ; Type : ${type_of_file} ; Size :   ${actual_size}GB -> [OK]"
                # if it is NOT NAS file  
                if [ ! "${nas_backup}" = "yes" ];then
                    # if its tar.gz Archive, perform archive_test and save the checksum of file
                    if [ "${type_of_file}" = "tar.gz" ];then
                        archive_test "${path_to_file}"
                        sum_and_save "${path_to_file}"
                    else
                        # if its not tar.gz archive save just checksum
                        sum_and_save "${path_to_file}"
                    fi
                # if it is NAS file
                elif [ "${nas_backup}" = "yes" ];then
                    # if checksum of local file equal to NAS file ( comp_sum_local_nas -> return 0), 
                    if comp_sum_local_nas "${path_to_file}" "${nas_mount}$(basename ${path_to_file})" ;then
                        echo "NAS backup for ${name} in place ${nas_mount}$(basename ${path_to_file})"
                    else
                        echo "Error NAS backup for ${name} not in place!"
                    fi
                else
                    exit 1 # exit if yes or no was not specified -> syntax error in $LIST_FILE
                fi
            # if actual size is LOWER than minimal size -> return 1 - count errors++
            elif [ "${actual_size}" -lt "${minimal_size}" ]; then
                echo "Backup : ${name} not created ; File : $(basename ${path_to_file}) ; Type : ${type_of_file} ; Size :  ${actual_size}GB -> [ERROR]"
                ((err_count++))
                return 1
            fi
            echo "#####--------------------------------------------------------------------------------------------------------------------------#####"
        # if minimal size of backup file is in MBs
        elif [[ "${minimal_size}" =~ MB$ ]]; then
            # get actual using get_file_size function  
            actual_size=$(get_file_size ${path_to_file} "MB" )
            #minimal size without units 
            minimal_size=$(echo $line | awk '{print $4}' | sed 's/MB//g')
            echo "#####--------------------------------------------------------------------------------------------------------------------------#####"
            # if actual size is GREATER than minimal size that is set in LIST_FILE
            if [ "${actual_size}" -gt "${minimal_size}"   ] || [ "${actual_size}" -eq "${minimal_size}" ]; then
                echo "Backup :  ${name} is created ; File : $(basename ${path_to_file}) ; Type : ${type_of_file} ; Size :   ${actual_size}MB -> [OK]"
                # if it is NOT NAS file
                if [ ! "${nas_backup}" = "yes" ];then
                    # if it is tar.gz Archive, perform archive_test and save the checksum of a file
                    if [ "${type_of_file}" = "tar.gz" ];then
                        archive_test "${path_to_file}"
                        sum_and_save "${path_to_file}"
                    else
                        # if it is not tar.gz archive, save just checksum of file
                        sum_and_save "${path_to_file}"
                    fi
                # if it IS NAS file
                elif [ "${nas_backup}" = "yes" ];then
                    # if checksum of local file equal to NAS file ( comp_sum_local_nas -> return 0)
                    if comp_sum_local_nas "${path_to_file}" "${nas_mount}$(basename ${path_to_file})" ;then
                        echo "NAS backup for ${name} in place ${nas_mount}$(basename ${path_to_file})"
                    else
                        echo "Error NAS backup for ${name} not in place!"
                    fi
                else
                    exit 1 # exit if any of the supported optiions (yes|no) was not specified -> syntax error in $LIST_FILE
                fi
            # if actual size is LOWER than minimal size -> return 1 - count errors++
            elif [ "${actual_size}" -lt "${minimal_size}" ]; then
                echo "Backup : ${name} not created ; File : $(basename ${path_to_file}) ; Type : ${type_of_file} ; Size :  ${actual_size}MB -> [ERROR]"
                ((err_count++))
            fi
            echo "#####--------------------------------------------------------------------------------------------------------------------------#####"
        fi
    else
        # If Backup file DOES NOT EXIST 
        echo "Backup : $name is NOT OK ; File: $(basename ${path_to_file}) does not exist! - ERROR"
        ((err_count++))
    fi
done < "${LIST_FILE}"

# create summary , if no erros occured (err_count=0) -> exit 0 .
#                  if at least one errors occured (err_count > 0) -> exit 1 .
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

