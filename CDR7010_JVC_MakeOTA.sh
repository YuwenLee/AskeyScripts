#!/bin/bash

set -e

FROM_VER=5.4.3.1642
TO_VER=5.4.3.1557
REMOTE_SHARE=~/Remote_share/CDR7010/SHIP
BUILD_JOB=CDR7010_JVC_SHIP_629ST_MP

OTA_PARAM=
UPDATE_RECOVERY=

function update_nonhlos()
{
  echo 
  echo ${FUNCNAME}

  FROM_DIR=$(find ${REMOTE_SHARE} -type d -name "*${FROM_VER}*")
  TO_DIR=$(find ${REMOTE_SHARE} -type d -name "*${TO_VER}*")
  
  COPY_FILES="sbl1.mbn emmc_appsboot.mbn NON-HLOS.bin"
    
  if [ "${TO_DIR} " = "" ]
  then
    echo ERROR: ${TO_VER} does not exist!
    exit 1
  fi

  FULL_IMG=$(find ${TO_DIR} -name "$(basename ${TO_DIR}).zip")
  if [ "${FULL_IMG}" = "" ]
  then
    echo ERROR: $(basename ${TO_DIR}).zip does not exists
    exit 1
  fi

  echo === Copy ${FULL_IMG}
  cp ${FULL_IMG} ./

  unzip $(basename ${FULL_IMG}) -d full_img

  for f in ${COPY_FILES}
  do
    cp full_img/$f ../${BUILD_JOB}/asko/LINUX/android/out/target/product/msm8953_64
    cp full_img/$f ../${BUILD_JOB}/asko/LINUX/android/device/qcom/msm8953_64/radio
  done
}

function update_recovery()
{
  echo 
  echo ${FUNCNAME}

  FROM_DIR=$(find ${REMOTE_SHARE} -type d -name "*${FROM_VER}*")
  TO_DIR=$(find ${REMOTE_SHARE} -type d -name "*${TO_VER}*")
    
  if [ "${TO_DIR} " = "" ]
  then
    echo ERROR: ${TO_VER} does not exist!
    exit 1
  fi

  FULL_IMG=$(find ${TO_DIR} -name "$(basename ${TO_DIR}).zip")
  if [ "${FULL_IMG}" = "" ]
  then
    echo ERROR: $(basename ${TO_DIR}).zip does not exists
    exit 1
  fi

  if [ ! -e $(basename ${FULL_IMG}) ]
  then
    echo === Copy ${FULL_IMG}
    cp ${FULL_IMG} ./
    unzip $(basename ${FULL_IMG}) -d full_img
  fi
  
  cp full_img/recovery.img ../${BUILD_JOB}/asko/LINUX/android/out/target/product/msm8953_64
  UPDATE_RECOVERY=-2
}

function patch_otascript_reorder_sbl1_aboot_boot_modem_system()
{
  echo
  echo  ${FUNCNAME}
  cd ../${BUILD_JOB}/asko/LINUX/android/build/tools/releasetools
  echo === replace ota_from_target_files
  cp -v ota_from_target_files.py.reorder_sbl1_aboot_boot_modem_system  ota_from_target_files.py
  chmod 777 ota_from_target_files.py
  cd - > /dev/null 2>&1
}

function make_ota()
{
  echo 
  echo ${FUNCNAME}

  work_dir=$(pwd)

  FROM_DIR=$(find ${REMOTE_SHARE} -type d -name "*${FROM_VER}*")
  TO_DIR=$(find ${REMOTE_SHARE} -type d -name "*${TO_VER}*")

  from=$(find $(find ${REMOTE_SHARE} -type d -name "*${FROM_VER}*") -name "*target_file*")
  to=$(find $(find ${REMOTE_SHARE} -type d -name "*${TO_VER}*") -name "*target_file*")
  
  suffix=MP
  echo ${from} | grep ST && suffix=ST > /dev/null

  from_ver=$(basename ${from} | awk -F. ' { print $3"."$4"."$5"."$6 } ')
  to_ver=$(basename ${to}     | awk -F. ' { print $3"."$4"."$5"."$6 } ')
  from4=$(echo ${from_ver} | awk -F. ' { print $4 } ')
  to4=$(echo ${to_ver} | awk -F. ' { print $4 } ')

  ota_package=${from4}_to_${to4}

  echo =============================
  echo from ${from_ver} to ${to_ver}

  mkdir -p ${work_dir}/update_src
  if [ ${from4} -gt ${to4} ]
  then 
    echo ${from_ver} | awk -F. ' { print $4 } '
    OTA_PARAM="--block --downgrade -n ${UPDATE_RECOVERY} -v -i "
    suffix=${suffix}_R
    echo ${from_ver} | awk -F. ' { print $1"."$2"."$3"."$4+1} ' > ${work_dir}/update_src/version.txt
  else
    echo ${to_ver}   | awk -F. ' { print $4 } '
    OTA_PARAM="--block -v -i"
    echo ${to_ver} | awk -F. ' { print $1"."$2"."$3"."$4} ' > ${work_dir}/update_src/version.txt
  fi

  echo === copy ${from}
  cp ${from} from.zip
  echo === copy ${to}
  cp ${to}   to.zip
  echo === generate update.zip
  cd ../${BUILD_JOB}/asko/LINUX/android
  echo ./build/tools/releasetools/ota_from_target_files ${OTA_PARAM} ${work_dir}/from.zip ${work_dir}/to.zip ${work_dir}/update_src/update.zip
  ./build/tools/releasetools/ota_from_target_files ${OTA_PARAM} ${work_dir}/from.zip ${work_dir}/to.zip ${work_dir}/update_src/update.zip
  md5sum ${work_dir}/update_src/update.zip | awk '{print $1}' > ${work_dir}/update_src/hash.txt
  
  cd ${work_dir}
  mkdir update_dst
  cd update_src
  zip -P 8cf36115a0528ea15b069e1ab4d3008f -r ../update_dst/update_${from4}to${to4}_${suffix}.zip *

  cd ${work_dir}
  cd update_dst
  ls -la

  if [ ${from4} -gt ${to4} ]
  then
    cd $(dirname ${from})
    echo ===${pwd}===
    ls -la
    if [ ! -e update_${from4}to${to4}_${suffix}.zip ]
    then
      cp ${work_dir}/update_dst/update_${from4}to${to4}_${suffix}.zip ./
    else
      echo WARNIN: update_${from4}to${to4}_${suffix}.zip exists!
    fi
  else
    echo === No thing ===
  fi
}


#
# Actions start here
#
update_nonhlos
update_recovery
patch_otascript_reorder_sbl1_aboot_boot_modem_system
make_ota
