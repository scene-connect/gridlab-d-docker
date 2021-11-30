FROM ubuntu

WORKDIR /build

ENV DEBIAN_FRONTEND="noninteractive"
ENV TZ=UTC+0

# Run-time dependencies.
RUN apt-get -y update \
    && apt-get -y install --no-install-recommends \
        libboost-dev \
        libmysqlclient-dev \
        libxerces-c-dev \
        libzmq5-dev \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get -y update \
    && apt-get -y install --no-install-recommends \
        autoconf \
        automake \
        ca-certificates \
        cmake \
        g++ \
        gcc \
        git \
        libtool \
        make \
    && git clone --depth 1 --branch v3.0.1 https://github.com/GMLC-TDC/HELICS.git \
    && cd HELICS \
    && mkdir build \
    && cd build \
    && cmake ../ \
    && make install \
    && cd ../.. \
    && rm -r HELICS \
    && git clone --depth 1 --branch v4.3-RC2 https://github.com/gridlab-d/gridlab-d.git \
    && cd gridlab-d \
    && autoreconf -if \
    && ./configure \
        --with-mysql=/usr/lib/x86_64-linux-gnu/ \
        --with-helics=/usr/local \
        --enable-silent-rules \
        "CFLAGS=-g -O0 -w" "CXXFLAGS=-g -O0 -w -std=c++14 -I/usr/include/mysql" "LDFLAGS=-g -O0 -w" \
    && make \
    && make install \
    && cd .. \
    && rm -r gridlab-d \
    && apt-get -y purge --auto-remove \
        autoconf \
        automake \
        ca-certificates \
        cmake \
        g++ \
        gcc \
        git \
        libtool \
        make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY test.glm .

CMD ["gridlabd", "test.glm"]
