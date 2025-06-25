FROM nginx
RUN apt-get update \
 && apt-get install -yy python3 \
 && apt-get clean
COPY bin /bin
COPY etc /etc
COPY opt /opt
