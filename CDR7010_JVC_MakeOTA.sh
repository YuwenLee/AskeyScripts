#!/bin/bash

set -e

FROM_VER=5.4.3.1632
TO_VER=5.4.3.1557
REMOTE_SHARE=~/Remote_share/CDR7010/SHIP
BUILD_JOB=CDR7010_JVC_SHIP_629ST_MP

function update_BuildJob()
{
  FROM_DIR=$(find ${REMOTE_SHARE} -type d -name "*${FROM_VER}*")
  TO_DIR=$(find ${REMOTE_SHARE} -type d -name "*${TO_VER}*")
  
  COPY_FILES="sbl1.mbn emmc_appsboot.mbn NON-HLOS.bin"
  
  echo 
  echo ${FUNCNAME}
  
  if [ "${TO_DIR} " = "" ]
  then
    echo ERROR: ${TO_VER} does not exist!
    exit 1
  fi

  OTASHIP=$(find ${TO_DIR} -name "$(basename ${TO_DIR}).zip")
  if [ "${OTASHIP}" = "" ]
  then
    echo ERROR: msm8953_64-ota-ship.jenkins.${TO_VER}.zip does not exists
    exit 1
  fi

  echo === Copy ${OTASHIP}
  cp ${OTASHIP} ./

  unzip $(basename ${OTASHIP}) -d otaship

  for f in ${COPY_FILES}
  do
    cp otaship/$f ../${BUILD_JOB}/asko/LINUX/android/out/target/product/msm8953_64
    cp otaship/$f ../${BUILD_JOB}/asko/LINUX/android/device/qcom/msm8953_64/radio
  done
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
    PARAM="--block --downgrade -n -v -i"
    suffix=${suffix}_R
    echo ${from_ver} | awk -F. ' { print $1"."$2"."$3"."$4+1} ' > ${work_dir}/update_src/version.txt
  else
    echo ${to_ver}   | awk -F. ' { print $4 } '
    PARAM="--block -v -i"
    echo ${to_ver} | awk -F. ' { print $1"."$2"."$3"."$4} ' > ${work_dir}/update_src/version.txt
  fi

  echo === copy ${from}
  cp ${from} from.zip
  echo === copy ${to}
  cp ${to}   to.zip
  echo === replace ota_from_target_files
  cd ../${BUILD_JOB}/asko/LINUX/android/build/tools/releasetools
  cp ota_from_target_files.py.reorder_sbl1_aboot_boot_modem_system ota_from_target_files.py
  echo === generate update.zip
  cd ../../../
  ./build/tools/releasetools/ota_from_target_files ${PARAM} ${work_dir}/from.zip ${work_dir}/to.zip ${work_dir}/update_src/update.zip
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
update_BuildJob
make_ota
