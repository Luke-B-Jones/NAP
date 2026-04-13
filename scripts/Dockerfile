FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${CONDA_DIR}/envs/nap_env/bin:/usr/local/bin:${PATH}

ARG TARGETARCH

# Light Linux base
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    bzip2 \
    procps \
    coreutils \
    findutils \
    gawk \
    grep \
    sed \
    && rm -rf /var/lib/apt/lists/*

# Install Miniforge (gives a proper conda install, but stays fairly light)
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

# Copy the NAP repo into the image
WORKDIR /opt/NAP
COPY . /opt/NAP

# Set up NAP, create nap_env, and expose nap on PATH
RUN chmod +x /opt/NAP/build.sh /opt/NAP/nap && \
    find /opt/NAP/bin/scripts -type f -name "*.sh" -exec chmod +x {} \; && \
    /bin/bash /opt/NAP/build.sh && \
    conda env create -n nap_env -f /opt/NAP/environment.yaml && \
    conda clean -afy && \
    ln -sf /opt/NAP/nap /usr/local/bin/nap && \
    mkdir -p /workspace /opt/NAP/bin/logs /opt/NAP/bin/databases && \
    chmod -R a+rX /opt/NAP && \
    chmod -R a+rwX /workspace /opt/NAP/bin/logs /opt/NAP/bin/databases

# Host-mounted working area
WORKDIR /workspace

# Default to an interactive shell
CMD ["bash"]
