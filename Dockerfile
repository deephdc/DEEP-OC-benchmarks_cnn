# Dockerfile may have following Arguments: tag, pyVer, branch, jlab
# tag - tag for the Base image, (e.g. 1.10.0-py3 for tensorflow)
# pyVer - python versions as 'python' or 'python3' (default: python3)
# branch - user repository branch to clone (default: master, other option: test)
# jlab - if to insall JupyterLab (true) or not (false, default)
#
# To build the image:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> --build-arg arg=value .
# or using default args:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> .
#
# Be Aware! For the Jenkins CI/CD pipeline, 
# input args are defined inside the Jenkinsfile, not here!
#


# ARG tag=1.10.0-py36
# ARG image=deephdc/tensorflow

ARG tag=1.14.0-py3
ARG image=tensorflow/tensorflow

# Base image, e.g. tensorflow/tensorflow:1.14.0-py3
FROM ${image}:${tag}

LABEL maintainer='A.Grupp, V.Kozlov (KIT)'
LABEL version='0.2.0'
# tf_cnn_benchmarks packed with DEEPaaS API

# renew 'tag' to access during the build
ARG tag

# python version
ARG pyVer=python3

# What user branch to clone [!]
ARG branch=master

# If to install JupyterLab
ARG jlab=true

# Oneclient version, has to match OneData Provider and Linux version
ARG oneclient_ver=19.02.0.rc2-1~bionic

# Install ubuntu updates and python related stuff
# link python3 to python, pip3 to pip, if needed
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
         git \
         curl \
         wget \
         $pyVer-setuptools \
         $pyVer-dev \
         $pyVer-pip \
         $pyVer-wheel && \ 
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    if [ "$pyVer" = "python3" ] ; then \
       if [ ! -e /usr/bin/pip ]; then \
          ln -s /usr/bin/pip3 /usr/bin/pip; \
       fi; \
       if [ ! -e /usr/bin/python ]; then \
          ln -s /usr/bin/python3 /usr/bin/python; \
       fi; \
    fi && \
    python --version && \
    pip --version


# Set LANG environment
ENV LANG C.UTF-8

# Set the working directory
WORKDIR /srv

# Install rclone
RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.deb && \
    dpkg -i rclone-current-linux-amd64.deb && \
    apt install -f && \
    mkdir /srv/.rclone/ && touch /srv/.rclone/rclone.conf && \
    rm rclone-current-linux-amd64.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# INSTALL oneclient for ONEDATA
RUN curl -sS  http://get.onedata.org/oneclient-1902.sh | bash -s -- oneclient="$oneclient_ver" && \
    apt-get clean && \
    mkdir -p /mnt/onedata && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*

# Install DEEPaaS from PyPi
# Install FLAAT (FLAsk support for handling Access Tokens)
RUN pip install --no-cache-dir \
        'deepaas>=1.1.0' \
        flaat>=0.5.3 && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Disable FLAAT authentication by default
ENV DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER yes

# Install JupyterLab
ENV JUPYTER_CONFIG_DIR /srv/.deep-start/
# Necessary for the Jupyter Lab terminal
ENV SHELL /bin/bash
RUN if [ "$jlab" = true ]; then \
       pip install --no-cache-dir jupyterlab ; \
    else echo "[INFO] Skip JupyterLab installation!"; fi

# EXPERIMENTAL: install deep-start script
# N.B.: This repository also contains run_jupyter.sh
# For compatibility, create symlink /srv/.jupyter/run_jupyter.sh
RUN git clone https://github.com/deephdc/deep-start /srv/.deep-start && \
    ln -s /srv/.deep-start/deep-start.sh /usr/local/bin/deep-start && \
    ln -s /srv/.deep-start/run_jupyter.sh /usr/local/bin/run_jupyter && \
    mkdir -p /srv/.jupyter && \
    ln -s /srv/.deep-start/run_jupyter.sh /srv/.jupyter/run_jupyter.sh

# Install TF Benchmarks
ENV PYTHONPATH=/srv/tf_cnn_benchmarks

###
# Clone tf_cnn_benchmarks from the official repository into /srv/benchmarks.tmp
# Move tf_cnn_benchmarks to higher level, delete benchmarks.tmp
RUN export TF_VERSION=$(echo ${tag} | cut -d\. -f1,2) && \
    git clone --depth 1 -b cnn_tf_v${TF_VERSION}_compatible https://github.com/tensorflow/benchmarks.git /srv/benchmarks.tmp && \
    mv -T /srv/benchmarks.tmp/scripts/tf_cnn_benchmarks /srv/tf_cnn_benchmarks && \
    rm -rf /srv/benchmarks.tmp

# Copy one directory from tensorflow/models
# ATTENTION! tensorflow/models is huge, ca. 1.1GB, 
# trying to copy in "light way" but still ca.500MB
# !!! FOR 1.14 and 1.15 THERE IS NO CORRESPONDING BRANCH, USE r1.13.0 !!!
RUN export TF_VERSION=$(echo ${tag} | cut -d\. -f1,2) && \
    if [ "$TF_VERSION" = 1.14 ] || [ "$TF_VERSION" = 1.15 ]; then \
        export TF_VERSION=1.13; \
    fi && \
    mkdir /srv/models.tmp && cd /srv/models.tmp && git init && \
    git remote add origin https://github.com/tensorflow/models.git && \
    git fetch --depth 1 origin && \
    git checkout origin/r${TF_VERSION}.0 official/utils/logs && \
    mv official /srv/tf_cnn_benchmarks && cd /srv && \
    rm -rf /srv/models.tmp

# Install user app
# Patch tf_cnn_benchmarks, if necessary:
# 1.10 - correct eval_results to show accuracy, add loss in "extras"
RUN git clone -b $branch https://github.com/deephdc/benchmarks_cnn_api && \
    cd  benchmarks_cnn_api && \
    pip install --no-cache-dir -e . && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    export TF_VERSION=$(echo ${tag} | cut -d\. -f1,2) && \
    export TF_CNN_PATCH=/srv/benchmarks_cnn_api/patches/tf_cnn_benchmarks_${TF_VERSION}.patch && \
    if test -f ${TF_CNN_PATCH}; then \
       cd /srv/tf_cnn_benchmarks && \
       echo "[INFO] Applying ${TF_CNN_PATCH} in /srv/tf_cnn_benchmarks" && \
       patch < ${TF_CNN_PATCH}; \
    fi && \
    cd /srv


# Open DEEPaaS port
EXPOSE 5000

# Open Monitoring and Jupyter port
EXPOSE 6006 8888

# Account for OpenWisk functionality (deepaas >=0.4.0) + proper docker stop
CMD ["deepaas-run", "--openwhisk-detect", "--listen-ip", "0.0.0.0", "--listen-port", "5000"]
