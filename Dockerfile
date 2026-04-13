FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${CONDA_DIR}/envs/nap_env/bin:/usr/local/bin:${PATH}

ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    wget \
    gzip \
    bzip2 \
    procps \
    coreutils \
    findutils \
    gawk \
    grep \
    sed \
    bc \
    ncurses-bin \
    vim \
    && rm -rf /var/lib/apt/lists/*

RUN case "${TARGETARCH}" in \
        "amd64") CONDA_ARCH="x86_64" ;; \
        "arm64") CONDA_ARCH="aarch64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -L -o /tmp/miniforge.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${CONDA_ARCH}.sh" && \
    bash /tmp/miniforge.sh -b -p "${CONDA_DIR}" && \
    rm -f /tmp/miniforge.sh && \
    conda config --system --set auto_activate_base false && \
    conda clean -afy

WORKDIR /opt/NAP
COPY . /opt/NAP

RUN chmod +x /opt/NAP/build.sh && \
    chmod +x /opt/NAP/scripts/*.sh && \
    conda env create -n nap_env -f /opt/NAP/environment.yaml && \
    /bin/bash -lc "source ${CONDA_DIR}/etc/profile.d/conda.sh && \
    conda activate nap_env && \
    cd /opt/NAP && \
    ./build.sh && \
    ./nap update-database SILVA_138.2_SSU_NR99" && \
    ln -sf /opt/NAP/nap /usr/local/bin/nap && \
    mkdir -p /workspace && \
    conda clean -afy

WORKDIR /workspace

CMD ["bash"]
