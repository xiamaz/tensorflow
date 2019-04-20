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
