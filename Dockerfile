# Use Ubuntu 20.04 as the base image
FROM ubuntu:20.04
# Set environment variables to non-interactive for apt-get
ENV DEBIAN_FRONTEND=non-interactive
# Install necessary system dependencies and GCC/G++ 9.x
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc-9 \
    g++-9 \
    cmake \
    curl \
    wget \
    git \
    ca-certificates \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    zlib1g-dev \
    sudo \
    bc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# Set GCC and G++ to version 9 as the default
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 100
# Set C++14 as the standard for compilation
ENV CXXFLAGS="-std=c++14"

# Copy NAP files into Docker image and set up permissions
RUN mkdir -p /opt/NAP
COPY ./ /opt/NAP/
RUN chmod +x /opt/NAP/build.sh
RUN chmod -R +x /opt/NAP/scripts
RUN chmod -R +x /opt/NAP/subconfigs
# Ensure full read/write/execute permissions for the NAP directory recursively
RUN chmod -R 777 /opt/NAP
# Run NAP setup script as the new user
ENV NAP_DIR=/opt/NAP
WORKDIR $NAP_DIR
RUN ./build.sh $NAP_DIR > /home/$USER_NAME/build.log 2>&1 || { cat /home/$USER_NAME/build.log; exit 1; }

# Clone RATTLE repository and initialize submodules
RUN git clone --recurse-submodules https://github.com/comprna/RATTLE.git /opt/RATTLE
# Build RATTLE
WORKDIR /opt/RATTLE/spoa
RUN mkdir build && cd build && \
    cmake .. && make
WORKDIR /opt/RATTLE
RUN ./build.sh > build.log 2>&1 || { cat build.log; exit 1; }
# Ensure full read/write/execute permissions for the RATTLE directory
RUN chmod -R 777 /opt/RATTLE

# Install Miniconda
ENV MINICONDA_VERSION=py38_23.1.0-1
RUN curl -LO https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -b -p /opt/miniconda && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh
# Set up Conda environment
COPY environment.yaml /opt/miniconda/
ENV PATH="/opt/miniconda/bin:$PATH"
RUN /opt/miniconda/bin/conda init bash && \
    /opt/miniconda/bin/conda env create -f /opt/miniconda/environment.yaml
# Ensure Conda is initialized in bash
RUN echo "source /opt/miniconda/etc/profile.d/conda.sh" >> /etc/bash.bashrc
RUN echo "source /opt/miniconda/etc/profile.d/conda.sh" >> /home/$USER_NAME/.bashrc
# Ensure full read/write/execute permissions for the Miniconda directory
RUN chmod -R 777 /opt/miniconda

# Create a new user based on the build user's name
ARG USER_NAME
RUN useradd -ms /bin/bash $USER_NAME && \
    echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
# Set up the home directory as a volume, ensuring persistence and access
VOLUME /home/$USER_NAME/
# Ensure correct permissions on the home directory
RUN chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/
RUN chmod -R 777 /home/$USER_NAME/
RUN chown -R $USER_NAME:$USER_NAME /opt/
# Switch to the new user and set up their environment
USER $USER_NAME
WORKDIR /home/$USER_NAME

# Add NAP and RATTLE to PATH
RUN echo 'export PATH=$PATH:/opt/NAP:/opt/RATTLE' >> /home/$USER_NAME/.bashrc

# Set the working directory to the user's home directory
WORKDIR /home/$USER_NAME/

# Set to shell
ENTRYPOINT ["/bin/bash"]
