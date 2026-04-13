FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV PATH=/opt/NAP:${CONDA_DIR}/envs/nap_env/bin:${CONDA_DIR}/bin:${PATH}

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
    chmod +x /opt/NAP/subconfigs/*.sh && \
    conda env create -n nap_env -f /opt/NAP/environment.yaml && \
    /bin/bash -lc "source ${CONDA_DIR}/etc/profile.d/conda.sh && \
    conda activate nap_env && \
    cd /opt/NAP && \
    ./build.sh && \
    ./nap update-database SILVA_138.2_SSU_NR99" && \
    mkdir -p /workspace && \
    conda clean -afy

RUN groupadd -g 1000 napuser && \
    useradd -m -u 1000 -g 1000 -s /bin/bash napuser && \
    mkdir -p /home/napuser /workspace && \
    chown -R napuser:napuser /home/napuser /workspace /opt/NAP/bin/logs /opt/NAP/bin/databases /opt/NAP/config.sh && \
    chmod -R ug+rwX /workspace /opt/NAP/bin/logs /opt/NAP/bin/databases && \
    chmod ug+rw /opt/NAP/config.sh

RUN echo '. /opt/conda/etc/profile.d/conda.sh' >> /etc/bash.bashrc && \
    echo 'conda activate nap_env >/dev/null 2>&1 || true' >> /etc/bash.bashrc

RUN printf '%s\n' \
'#!/bin/bash' \
'set -e' \
'source /opt/conda/etc/profile.d/conda.sh' \
'conda activate nap_env >/dev/null 2>&1 || true' \
'exec "$@"' \
> /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /workspace
USER napuser
ENV HOME=/home/napuser

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bash"]
