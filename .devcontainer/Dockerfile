FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ARG DEBIAN_FRONTEND=noninteractive

# System dependencies for Rails + native gems
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libvips-dev \
    libyaml-dev \
    libffi-dev \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    curl \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*
