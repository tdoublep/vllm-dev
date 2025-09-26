## Global Args #################################################################
ARG BASE_UBI_IMAGE_TAG=9.6-1758184547


## Base Layer ##################################################################
FROM registry.access.redhat.com/ubi9/ubi-minimal:${BASE_UBI_IMAGE_TAG} AS base

WORKDIR /workspace

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8


## Miniforge Install ###########################################################
FROM base AS python-install
ARG MINIFORGE_VERSION=25.3.1-0

RUN curl -fsSL -o ~/miniforge3.sh -O  "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-$(uname)-$(uname -m).sh" && \
    chmod +x ~/miniforge3.sh && \
    # set umask to give group 0 write permissions
    umask 002 && \
    ~/miniforge3.sh -b -p /opt/conda && \
    rm ~/miniforge3.sh


## Base Layer ##################################################################
FROM base AS release

# Install dev tools
RUN microdnf install -y \
        which \
        procps \
        findutils \
        tar \
        nano \
        rsync \
        git \
    && microdnf clean all

COPY --from=python-install --link /opt/conda /opt/conda
COPY --from=python-install --link /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh

RUN --mount=type=cache,target=/root/.cache/pip \
    source /etc/profile.d/conda.sh; \
    conda activate;

# setup non-root user for OpenShift
ENV HOME=/home/develop
RUN microdnf install -y shadow-utils \
    && useradd --uid 2000 --gid 0 develop \
    && microdnf remove -y shadow-utils \
    && microdnf clean all \
    # give group perms to directories that will be used for development
    && chmod -R g+rw $HOME \
    && chmod g+rwx $HOME /workspace /usr/src /usr/local /var/local /opt

COPY --link entrypoint.sh /usr/local/bin/entrypoint.sh

USER 2000
CMD ["entrypoint.sh"]
