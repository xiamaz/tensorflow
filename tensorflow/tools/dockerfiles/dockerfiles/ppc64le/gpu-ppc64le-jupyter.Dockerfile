# Copyright 2018 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================
#
# THIS IS A GENERATED DOCKERFILE.
#
# This file was assembled from multiple pieces, whose use is documented
# throughout. Please refer to the TensorFlow dockerfiles documentation
# for more information.

ARG UBUNTU_VERSION=16.04

ARG ARCH=
ARG CUDA=10.0
FROM nvidia/cuda${ARCH:+-$ARCH}:${CUDA}-base-ubuntu${UBUNTU_VERSION} as base
# ARCH and CUDA are specified again because the FROM directive resets ARGs
# (but their default value is retained if set previously)
ARG ARCH
ARG CUDA
ARG CUDNN=7.4.1.5-1

# Needed for string substitution 
SHELL ["/bin/bash", "-c"]
# Pick up some TF dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cuda-command-line-tools-${CUDA/./-} \
        cuda-cublas-${CUDA/./-} \
        cuda-cufft-${CUDA/./-} \
        cuda-curand-${CUDA/./-} \
        cuda-cusolver-${CUDA/./-} \
        cuda-cusparse-${CUDA/./-} \
        curl \
        libcudnn7=${CUDNN}+cuda${CUDA} \
        libfreetype6-dev \
        libhdf5-serial-dev \
        libzmq3-dev \
        pkg-config \
        software-properties-common \
        unzip

RUN [ ${ARCH} = ppc64le ] || (apt-get update && \
        apt-get install nvinfer-runtime-trt-repo-ubuntu1604-5.0.2-ga-cuda${CUDA} \
        && apt-get update \
        && apt-get install -y --no-install-recommends libnvinfer5=5.0.2-1+cuda${CUDA} \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*)

# For CUDA profiling, TensorFlow requires CUPTI.
ENV LD_LIBRARY_PATH /usr/local/cuda/extras/CUPTI/lib64:$LD_LIBRARY_PATH

FROM ubuntu:${UBUNTU_VERSION} as pythonbuild
ARG PYTHON_VERSION=2.7.12

RUN apt-get update && apt-get install -y wget gcc make zlib1g-dev libssl-dev libsqlite3-dev libncurses5-dev libncursesw5-dev libgdbm-dev libdb5.3-dev libbz2-dev libexpat1-dev liblzma-dev libffi-dev

RUN wget -O /tmp/python.tgz https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && tar xf /tmp/python.tgz -C /tmp/
RUN cd /tmp/Python-${PYTHON_VERSION} && ./configure --enable-optimizations --enable-unicode=ucs4 --with-ensurepip=install && make && make install

# Some TF tools expect a "python" binary
FROM base
ARG PYTHON_SUFFIX=2
ARG PYTHON=python${PYTHON_SUFFIX}
ARG PIP=pip${PYTHON_SUFFIX}

# See http://bugs.python.org/issue19846
ENV LANG C.UTF-8

RUN apt-get update && apt-get install -y libffi6 libc6 libbz2-1.0 liblzma5 libmpdec2 libncursesw5 libreadline6 libsqlite3-0 libtinfo5 mime-support libdb5.3 libssl1.0.0

COPY --from=pythonbuild /usr/local /usr/local

RUN ${PIP} --no-cache-dir install --upgrade \
    pip \
    setuptools
RUN if [ ! -e /usr/local/bin/python ]; then ln -s $(which ${PYTHON}) /usr/local/bin/python; fi

# Options:
#   tensorflow
#   tensorflow-gpu
#   tf-nightly
#   tf-nightly-gpu
ARG TF_PACKAGE=tensorflow
RUN apt-get update && apt-get install -y wget libhdf5-dev
RUN ${PIP} install --global-option=build_ext \
            --global-option=-I/usr/include/hdf5/serial/ \
            --global-option=-L/usr/lib/powerpc64le-linux-gnu/hdf5/serial \
            h5py

# CACHE_STOP is used to rerun future commands, otherwise downloading the .whl will be cached and will not pull the most recent version
ARG CACHE_STOP=1
RUN if [ ${TF_PACKAGE} = tensorflow-gpu ]; then \
        BASE=https://powerci.osuosl.org/job/TensorFlow_PPC64LE_GPU_Release_Build/lastSuccessfulBuild/; \
    elif [ ${TF_PACKAGE} = tf-nightly-gpu ]; then \
        BASE=https://powerci.osuosl.org/job/TensorFlow_PPC64LE_GPU_Nightly_Artifact/lastSuccessfulBuild/; \
    elif [ ${TF_PACKAGE} = tensorflow ]; then \
        BASE=https://powerci.osuosl.org/job/TensorFlow_PPC64LE_CPU_Release_Build/lastSuccessfulBuild/; \
    elif [ ${TF_PACKAGE} = tf-nightly ]; then \
        BASE=https://powerci.osuosl.org/job/TensorFlow_PPC64LE_CPU_Nightly_Artifact/lastSuccessfulBuild/; \
    fi; \
    MAJOR=`${PYTHON} -c 'import sys; print(sys.version_info[0])'`; \
    MINOR=`${PYTHON} -c 'import sys; print(sys.version_info[1])'`; \
    PACKAGE=$(wget -qO- ${BASE}"api/xml?xpath=//fileName&wrapper=artifacts" | grep -o "[^<>]*cp${MAJOR}${MINOR}[^<>]*.whl"); \
    wget ${BASE}"artifact/tensorflow_pkg/"${PACKAGE}; \
    ${PIP} install ${PACKAGE}

COPY bashrc /etc/bash.bashrc
RUN chmod a+rwx /etc/bash.bashrc

RUN ${PIP} install jupyter matplotlib
RUN ${PIP} install jupyter_http_over_ws
RUN jupyter serverextension enable --py jupyter_http_over_ws

RUN mkdir -p /tf/tensorflow-tutorials && chmod -R a+rwx /tf/
RUN mkdir /.local && chmod a+rwx /.local
RUN apt-get install -y --no-install-recommends wget
WORKDIR /tf/tensorflow-tutorials
RUN wget https://raw.githubusercontent.com/tensorflow/docs/master/site/en/tutorials/keras/basic_classification.ipynb
RUN wget https://raw.githubusercontent.com/tensorflow/docs/master/site/en/tutorials/keras/basic_text_classification.ipynb
COPY readme-for-jupyter.md README.md
RUN apt-get autoremove -y && apt-get remove -y wget
WORKDIR /tf
EXPOSE 8888

RUN ${PYTHON} -m ipykernel.kernelspec

CMD ["bash", "-c", "source /etc/bash.bashrc && jupyter notebook --notebook-dir=/tf --ip 0.0.0.0 --no-browser --allow-root"]
