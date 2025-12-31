




# Dockerfile for ELINA development with VS Code Remote - Containers
# Base image: Ubuntu 22.04 (Linux 64-bit)
FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies (gcc, g++, m4, and build tools)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        g++ \
        m4 \
        cmake \
        git \
        wget \
        curl \
        python3 \
        python3-pip \
        python3-venv \
        pkg-config \
        opam \
        ca-certificates \
        sudo \
        vim \
        && rm -rf /var/lib/apt/lists/* \
        && apt-get remove -y libgmp-dev || true

# Install GMP from source
RUN cd /tmp && \
    wget https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz && \
    tar -xf gmp-6.3.0.tar.xz && \
    cd gmp-6.3.0 && \
    ./configure --enable-cxx && \
    make && \
    make check && \
    make install && \
    cd /tmp && \
    rm -rf gmp-6.3.0* && \
    ldconfig

# Install MPFR from source (use static versioned URL)
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
RUN cd /tmp && \
    wget https://www.mpfr.org/mpfr-4.2.1/mpfr-4.2.1.tar.xz && \
    tar -xf mpfr-4.2.1.tar.xz && \
    cd mpfr-4.2.1 && \
    ./configure && \
    make && \
    make check || (cat tests/test-suite.log && false) && \
    make install && \
    cd /tmp && \
    rm -rf mpfr-4.2.1* && \
    ldconfig

# Set up a non-root user for VS Code
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

WORKDIR /home/$USERNAME
RUN opam init --disable-sandboxing -a -y && \
    opam update && \
    opam install -y ocamlfind

# Set workspace folder
WORKDIR /workspaces/ELINA

# Copy ELINA source into the image and build (conditionally enable -use-vector if AVX is supported)
WORKDIR /opt/elina
COPY . /opt/elina
RUN if grep -q avx /proc/cpuinfo; then \
        ./configure -use-vector; \
    else \
        ./configure; \
    fi && \
    make && \
    make install

# Set default user
USER $USERNAME

# [Optional] Python ELINA bindings can be installed after building ELINA:
# cd python_interface && python3 setup.py install --user

# Note: Ensure Python 3.4 or later is available for Python interface (already included)