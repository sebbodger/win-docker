# syntax=docker/dockerfile:1-labs

FROM mcr.microsoft.com/devcontainers/base:focal

RUN apt-get update \
    && apt-get -y install software-properties-common \
    && add-apt-repository ppa:smoser/swtpm \
    && add-apt-repository ppa:flexiondotorg/quickemu \
    && apt-get update \
    && apt-get --no-install-recommends -y install \
    qemu \
    qemu-utils \
    bash \
    coreutils \
    ovmf \
    grep \
    jq \
    lsb-base \
    procps \
    python3 \
    genisoimage \
    usbutils \
    util-linux \
    sed \
    spice-client-gtk \
    wget \
    xdg-user-dirs \
    zsync \
    unzip \
    swtpm \
    curl \
    cpu-checker \
    quickemu \
    ssh \
    p7zip-full \
    python3-pip \
    samba \
    expect \
    openssh-client \
    sshpass

COPY --chmod=0600 /ssh/* /root/.ssh/
COPY --chmod=0755 /scripts/exp.sh /usr/bin/exp

WORKDIR /root/win-docker/
RUN mkdir samba \
    && mkdir windows-11

# do a minimal copy of the files needed for installation preparation in order to ensure 
# cache of the layer
COPY /scripts/prepare-install.py /scripts/requirements.txt ./
RUN pip install -r requirements.txt
RUN python3 prepare-install.py

# now copy everything else
COPY /scripts/*.py .
COPY --chmod=0755 /scripts/*.sh .

# network=host here means the network of the builder container
# ... which is the custom one used for reverse ssh of vnc
RUN --network=host --security=insecure ./launch-install.sh