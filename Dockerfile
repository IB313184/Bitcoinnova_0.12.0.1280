# daemon runs in the background
# run something like tail /var/log/bitcoinnovad/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/bitcoinnovad:/var/lib/bitcoinnovad -v $(pwd)/wallet:/home/bitcoinnova --rm -ti bitcoinnova:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG BITCOINNOVA_BRANCH=master
ENV BITCOINNOVA_BRANCH=${BITCOINNOVA_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install

RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-7.0 \
      g++-7.0 \
      git cmake \
      libboost1.58-all-dev && \
    git clone https://github.com/IB313184/Bitcoinnova_0.12.0.1280.git /src/bitcoinnova && \
    cd /src/bitcoinnova && \
    git checkout $BITCOINNOVA_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/Bitcoinnovad /usr/local/bin/Bitcoinnovad && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/zedwallet /usr/local/bin/zedwallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/Bitcoinnovad && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/zedwallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/bitcoinnova && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# build cmake (ubuntu 14.04 comes with cmake 2.8, we want a 3.X)
RUN apt-get install -y curl
RUN curl -O https://cmake.org/files/v3.8/cmake-3.8.0.tar.gz \
     && tar -xvf cmake-3.8.0.tar.gz
RUN cd cmake-3.8.0 && ./bootstrap && make && make install

# setup the bitcoinnovad service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/bitcoinnovad bitcoinnovad && \
    useradd -s /bin/bash -m -d /home/bitcoinnova bitcoinnova && \
    mkdir -p /etc/services.d/bitcoinnovad/log && \
    mkdir -p /var/log/bitcoinnovad && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/bitcoinnovad/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/bitcoinnovad/run && \
    echo "cd /var/lib/bitcoinnovad" >> /etc/services.d/bitcoinnovad/run && \
    echo "export HOME /var/lib/bitcoinnovad" >> /etc/services.d/bitcoinnovad/run && \
    echo "s6-setuidgid bitcoinnovad /usr/local/bin/Bitcoinnovad" >> /etc/services.d/bitcoinnovad/run && \
    chmod +x /etc/services.d/bitcoinnovad/run && \
    chown nobody:nogroup /var/log/bitcoinnovad && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/bitcoinnovad/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/bitcoinnovad/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/bitcoinnovad" >> /etc/services.d/bitcoinnovad/log/run && \
    chmod +x /etc/services.d/bitcoinnovad/log/run && \
    echo "/var/lib/bitcoinnovad true bitcoinnovad 0644 0755" > /etc/fix-attrs.d/bitcoinnovad-home && \
    echo "/home/bitcoinnova true bitcoinnova 0644 0755" > /etc/fix-attrs.d/bitcoinnova-home && \
    echo "/var/log/bitcoinnovad true nobody 0644 0755" > /etc/fix-attrs.d/bitcoinnovad-logs

VOLUME ["/var/lib/bitcoinnovad", "/home/bitcoinnova","/var/log/bitcoinnovad"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/bitcoinnova export HOME /home/bitcoinnova s6-setuidgid bitcoinnova /bin/bash"]
