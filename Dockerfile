# Start with a base image of Ubuntu 20.04
FROM ubuntu:20.04 as base

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Update, install necessary tools, and clean up in one layer
RUN apt-get update && apt-get install -y \
    software-properties-common \
    build-essential \
    gcc-9 \
    g++-9 \
    make \
    git \
    cmake \
    zlib1g-dev \
    sudo && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 100 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 100 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create the /docker_files directory
RUN mkdir -p /docker_files

# Capture the user's name, UID, and GID from build arguments
ARG USERNAME=myuser
ARG USER_UID=1000
ARG USER_GID=1000

# Create a group and user with the specified UID and GID
RUN groupadd -g $USER_GID $USERNAME && \
    useradd -l -m -u $USER_UID -g $USER_GID -s /bin/bash $USERNAME && \
    usermod -aG sudo $USERNAME && \
    chown -R $USERNAME:$USERNAME /docker_files

# Switch to the created user
USER $USERNAME
WORKDIR /home/$USERNAME

# Copy the current directory contents to the user's home directory
COPY --chown=$USERNAME:$USERNAME . .

# Use specific version of Miniconda
FROM continuumio/miniconda3:4.8.2 as conda

# Copy user home directory from base
COPY --from=base /home/$USERNAME /home/$USERNAME

# Set up the environment
COPY environment.yml /home/$USERNAME/
WORKDIR /home/$USERNAME
RUN conda env create -f environment.yml && conda clean -afy && \
    echo "source activate nap_env" >> ~/.bashrc && \
    echo 'export PATH=$(pwd)/nap:$PATH' >> ~/.bashrc

# Clone and build RATTLE
RUN git clone --recurse-submodules https://github.com/comprna/RATTLE /docker_files/RATTLE && \
    cd /docker_files/RATTLE && ./build.sh && \
    echo 'export PATH=$PATH:/docker_files/RATTLE/bin' >> ~/.bashrc
WORKDIR /docker_files/RATTLE

# Clone and build DORADO
RUN wget https://example.com/path/to/dorado-0.7.3-linux-x64 -O /tmp/dorado-installer && \
    chmod +x /tmp/dorado-installer && \
    /tmp/dorado-installer --prefix=/docker_files/dorado && \
    rm /tmp/dorado-installer
# Verify Dorado installation and add to PATH
RUN if [ ! -x "/docker_files/dorado/bin/dorado" ]; then \
        echo "Dorado installation failed"; exit 1; \
    fi && \
    echo 'export PATH=$PATH:/docker_files/dorado/bin' >> ~/.bashrc



# Health check
HEALTHCHECK --interval=5m --timeout=3s \
  CMD pgrep -f "nap -h" || exit 1
# Default command
CMD ["/bin/bash"]
