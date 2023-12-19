FROM python:3.11-slim AS compile-image
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    git \
    g++ \
    cmake \
    libssl-dev

RUN python -m venv /opt/venv

# Make sure we use the virtualenv:
ENV PATH="/opt/venv/bin:$PATH"

# duckdb
# we need to compile duckdb ourselves because duckdb doesnt provide
# binary extensions for 'httpfs' in platform: linux_arm64_gcc4
# this means duckdb is not working to query remote files in
# both Mac M1 (only under docker) and Linux ARM (only under docker)
# Note: without docker, duckdb extensions autoload mechanism works.
# More info at:
# https://github.com/duckdb/duckdb/issues/8035

RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
    git clone --depth 1 --branch v0.9.2 https://github.com/duckdb/duckdb && \
    cd duckdb/tools/pythonpkg && BUILD_HTTPFS=1 python -m pip install . ; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    pip install duckdb==0.9.2; \
fi

FROM python:3.11-slim AS build-image
ARG TARGETPLATFORM
ARG BUILDPLATFORM

COPY --from=compile-image /opt/venv /opt/venv

# Make sure we use the virtualenv:
ENV PATH="/opt/venv/bin:$PATH"

# Update OS and install packages
RUN apt-get update --yes && \
    apt-get dist-upgrade --yes && \
    apt-get install --yes \
      screen \
      unzip \
      curl \
      vim \
      zip

RUN case ${TARGETPLATFORM} in \
         "linux/amd64")  AWSCLI_FILE=https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip  ;; \
         "linux/arm64")  AWSCLI_FILE=https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip  ;; \
    esac && \
    curl "${AWSCLI_FILE}" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -f awscliv2.zip
