ARG FIPS=""
ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG PRIVATE_REGISTRY
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="2.0.3"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base"
ARG BASE_VER="24.04"
ARG BASE_VER_PFX=""
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}${FIPS}:${BASE_VER_PFX}${BASE_VER}"

ARG VAULT_REG="${PRIVATE_REGISTRY}"
ARG VAULT_REPO="arkcase/rebuild-vault"
ARG VAULT_VER_PFX="${BASE_VER_PFX}"
ARG VAULT_IMG="${VAULT_REG}/${VAULT_REPO}${FIPS}:${VAULT_VER_PFX}${VER}"

FROM "${VAULT_IMG}" AS vault-src

ARG BASE_IMG

FROM "${BASE_IMG}"

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER
ARG APP_USER="vault"
ARG APP_UID="1000"
ARG APP_GROUP="${APP_USER}"
ARG APP_GID="${APP_UID}"
ARG K8S_VER="1.34"

#
# Some important labels
#
LABEL ORG="Armedia LLC"
LABEL MAINTAINER="Armedia Devops Team <devops@armedia.com>"
LABEL APP="Vault"
LABEL VERSION="${VER}"
LABEL IMAGE_SOURCE="https://github.com/ArkCase/vault"

# Add Kubectl
RUN export K8S_KEY="/etc/apt/trusted.gpg.d/kubernetes.gpg" && \
    export K8S_LIST="/etc/apt/sources.list.d/kubernetes.list" && \
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VER}/deb/Release.key" | \
        gpg --dearmor -o "${K8S_KEY}" && \
    chmod 644 "${K8S_KEY}" && \
    echo "deb [signed-by=${K8S_KEY}] https://pkgs.k8s.io/core:/stable:/v${K8S_VER}/deb/ /" | \
    tee "${K8S_LIST}" && \
    chmod 644 "${K8S_LIST}" && \
    apt-get update &&  \
    apt-get -y install \
        dumb-init \
        iproute2 \
        kubectl \
        libcap2-bin \
      && \
    apt-get clean && \
    kubectl completion bash > /usr/share/bash-completion/completions/kubectl

COPY --chown=root:root --chmod=0775 --from=vault-src /vault /usr/local/bin/

ENV HOME="/app/${APP_USER}"
RUN groupadd --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --uid "${APP_UID}" --gid "${APP_GROUP}" --groups "${ACM_GROUP}" --create-home --home-dir "${HOME}" "${APP_USER}" && \
    chmod -R u=rwX,g=rX,o= "${HOME}"

COPY --chown=root:root --chmod=0755 entrypoint unseal-entrypoint /
COPY --chown=root:root --chmod=0755 scripts/* /usr/local/bin/

#
# Final parameters
#
WORKDIR     /
USER        "${APP_UID}"
ENTRYPOINT  [ "/usr/local/bin/vault-create-k8s-app" ]
