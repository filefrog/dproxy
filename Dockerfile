FROM nginx AS builder
COPY bin /bin
COPY etc /etc
COPY opt /opt
