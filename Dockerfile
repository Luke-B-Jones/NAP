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
    /bin/bash -lc "source ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate nap_env && /opt/NAP/build.sh" && \
    ln -sf /opt/NAP/scripts/nap.sh /usr/local/bin/nap && \
    mkdir -p /workspace /opt/NAP/logs && \
    chmod -R a+rX /opt/NAP && \
    chmod -R a+rwX /workspace /opt/NAP/logs && \
    echo '. /opt/conda/etc/profile.d/conda.sh' >> /root/.bashrc && \
    echo 'conda activate nap_env' >> /root/.bashrc && \
    conda clean -afy

WORKDIR /workspace

CMD ["bash"]
