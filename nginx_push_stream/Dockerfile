FROM debian:wheezy

RUN sed -i.bak /etc/apt/sources.list -e's/http\.debian\.net/mirrors.kernel.org/g' && \
    apt-get update

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7BD9BF62 && \
  echo "deb http://nginx.org/packages/mainline/debian/ wheezy nginx" >> /etc/apt/sources.list && \
  echo "deb-src http://nginx.org/packages/mainline/debian/ wheezy nginx" >> /etc/apt/sources.list

ADD nginx-push-stream-module /src/nginx-push-stream-module
#ADD ngx_mruby /src/ngx_mruby
ADD nginx /src/nginx

ENV NGINX_VERSION 1.7.11
ENV NGINX_PACKAGE ${NGINX_VERSION}-1~wheezy

RUN \
  dpkg --get-selections | grep -v deinstall | awk '{print $1}' | sort > /tmp/initial-packages && \
  apt-get update && \
  DEBIAN_FRONT_END=noninteractive apt-get -y build-dep nginx=$NGINX_PACKAGE && \
  cd /src/nginx && \
  ./configure --add-module=../nginx-push-stream-module && \
  make && \
  cd /src/nginx && \
  make install && \
  dpkg --get-selections | grep -v deinstall | awk '{print $1}' | sort > /tmp/final-packages && \
  DEBIAN_FRONT_END=noninteractive apt-get -y purge `comm -13 /tmp/initial-packages /tmp/final-packages` && \
  apt-get install -y `apt-cache depends nginx=$NGINX_PACKAGE | awk '/Depends:/{print$2}'` && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /usr/local/nginx/logs/access.log
RUN ln -sf /dev/stderr /usr/local/nginx/logs/error.log

#VOLUME ["/var/cache/nginx"]

EXPOSE 80 443

CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
