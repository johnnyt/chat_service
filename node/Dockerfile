FROM debian:wheezy

ENV NODE_VERSION 0.10.33

RUN sed -i.bak /etc/apt/sources.list -e's/http\.debian\.net/mirrors.kernel.org/g' && \
  apt-get update && \
  DEBIAN_FRONT_END=noninteractive apt-get install --no-install-recommends -y -q \
    g++ \
    make \
    python \
    wget && \
  mkdir /nodejs && \
  wget --quiet -O - "http://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz" | \
  tar xzf - -C /nodejs --strip-components=1 && \
  apt-get remove -y wget && \
  apt-get autoremove -y && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV PATH $PATH:/nodejs/bin

WORKDIR /app
ADD package.json /app/
RUN npm install
ADD . /app

# ONBUILD ADD package.json /app/
# ONBUILD RUN npm install
# ONBUILD ADD . /app

EXPOSE 8080
CMD ["npm", "start"]
#CMD []
#ENTRYPOINT ["/nodejs/bin/npm", "start"]
