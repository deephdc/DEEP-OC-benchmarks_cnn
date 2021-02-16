#!/bin/bash
#SBATCH --time=3:00:00
#SBATCH --partition=visu
#SBATCH --nodes=1
#SBTACH --ntasks-per-node=48
#SBATCH --job-name=tf_cnn_benchmark
#SBATCH --gres=gpu:1

#
# Copyright (c) 2018 - 2020 Karlsruhe Institute of Technology - Steinbuch Centre for Computing
# This code is distributed under the MIT License
# Please, see the LICENSE file
#
# @author: vykozlov
#

###  INFO  ###
# Script that runs a DEEP-OC-benchmarks_cnn app via udocker container.
# Example for a SLURM batch system.
# Pre-configured for running on GPUs, if more than 1 GPU requested:
# 1. Update SBATCH --gres=gpu:NUM_GPUS (top)
# 2. Update UDOCKER_RUN_COMMAND, flag --num_gpus=NUM_GPUS
#
# To submit the script: 
#    sbatch ./udocker-job.sh
#

### BASIC CONFIG ###
# docker image to use:
DOCKER_IMAGE="deephdc/deep-oc-benchmarks_cnn:synthetic-test"
# name of the udocker container:
UDOCKER_CONTAINER="benchmarks_synthetic_test"
# options to pass to udocker, e.g. -v HOST_DIR:UCONTAINER_DIR (optional):
UDOCKER_OPTIONS=""
# command to run inside udocker container:
UDOCKER_RUN_COMMAND="deepaas-cli train --num_gpus=1"


### SCRIPT CONFIG ###
UDOCKER_USE_GPU=true
UDOCKER_RECREATE=false
UDOCKER_DELETE_AFTER=false
UDOCKER_DOWNLOAD_LINK="https://github.com/indigo-dc/udocker/releases/download/devel3_1.2.4/udocker-1.2.4.tar.gz"


### THE CODE: ###

function print_date()
{
    echo $(date +'%Y-%m-%d %H:%M:%S')
}

function short_date()
{
    echo $(date +'%y%m%d_%H%M%S')
}


echo "=== DATE: $(print_date)"
echo "== DOCKER_IMAGE: ${DOCKER_IMAGE}"
echo "== UDOCKER_CONTAINER: ${UDOCKER_CONTAINER}"
echo "== (!) UDOCKER ENVIRONMENT OPTIONS are NOT PRINTED for security reasons! (!)"
# echo "== UDOCKER_OPTIONS: ${UDOCKER_OPTIONS}"
echo "== UDOCKER_RUN_COMMAND: ${UDOCKER_RUN_COMMAND}"
echo "== SLURM_JOBID: ${SLURM_JOB_ID}"
echo "== SLURM_OPTIONS (partition : nodes : ntasks-per-node : gpus: gres: time): \
$SLURM_JOB_PARTITION : $SLURM_JOB_NODELIST : $SLURM_NTASKS_PER_NODE :  $SBATCH_GPUS : $SBATCH_GRES : $SBATCH_TIMELIMIT"
echo ""

##### CHECK for udocker and INSTALL if missing ######
export PATH="$HOME/udocker:$PATH"
echo "== [udocker check: $(print_date) ]"
if command udocker version 2>/dev/null; then
   echo "= udocker is present!"
else
   echo "= [WARNING: $(print_date) ]: udocker is NOT found. Trying to install..."
   [[ -d "$HOME/udocker" ]] && mv "$HOME/udocker" "$HOME/udocker-$(short_date).bckp"
   echo "= Downloading from $UDOCKER_DOWNLOAD_LINK"
   cd $HOME && wget $UDOCKER_DOWNLOAD_LINK
   udocker_tar="${UDOCKER_DOWNLOAD_LINK##*/}"
   tar zxvf "$udocker_tar"

   if command udocker version 2>/dev/null; then
       echo "= [INFO: $(print_date)] Now udocker is found!"
   else
       echo "[ERROR: $(print_date)] hmm... udocker is still NOT found! Exiting..."
       exit 1
   fi
fi
echo "== [/udocker check]"
echo ""

##### RUN THE JOB #####
IFContainerExists=$(udocker ps |grep "'${UDOCKER_CONTAINER}'")
IFImageExists=$(echo ${IFContainerExists} |grep "${DOCKER_IMAGE}")
if [ ${#IFImageExists} -le 1 ] || [ ${#IFContainerExists} -le 1 ] || echo ${UDOCKER_RECREATE} |grep -iqF "true"; then
    echo "== [INFO: $(print_date) ]"
    if [ ${#IFContainerExists} -gt 1 ]; then
        echo "= Removing container ${UDOCKER_CONTAINER}..."
        udocker rm ${UDOCKER_CONTAINER}
    fi
    udocker pull ${DOCKER_IMAGE}
    echo "= $(print_date): Creating container ${UDOCKER_CONTAINER}..."
    udocker create --name=${UDOCKER_CONTAINER} ${DOCKER_IMAGE}
    echo "= $(print_date): Created"
    echo "== [/INFO]"
else
    echo "== [INFO: $(print_date) ]"
    echo "= ${UDOCKER_CONTAINER} already exists!"
    echo "= udocker ps: ${IFContainerExists}"
    echo "= Trying to re-use it..."
    echo "== [/INFO]"
fi
echo ""

# if GPU is to be used, apply an 'nvidia hack'
# and setup the container for GPU
if echo ${UDOCKER_USE_GPU} |grep -iqF "true"; then
    echo "== [NVIDIA: $(print_date) ]"
    echo "=  Setting up Nvidia compatibility."
    nvidia-modprobe -u -c=0  # CURRENTLY only to circumvent a bug
    udocker setup --nvidia --force ${UDOCKER_CONTAINER}
    udocker run ${UDOCKER_CONTAINER} nvidia-smi
    echo "== [/NVIDIA]"
fi
echo ""


echo "== [RUN: $(print_date) ] Running the application..."
udocker run ${UDOCKER_OPTIONS} ${UDOCKER_CONTAINER} /bin/bash <<EOF
${UDOCKER_RUN_COMMAND}
EOF

echo "== [/RUN]"
echo ""


if echo ${UDOCKER_DELETE_AFTER} |grep -iqF "true"; then
    echo "== [POST_RUN, UDOCKER: $(print_date) ] Deleting container ${UDOCKER_CONTAINER} ..."
    udocker rm ${UDOCKER_CONTAINER}
fi
echo "== [/POST_RUN]"
