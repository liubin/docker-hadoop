FROM openjdk:8-jdk-alpine
MAINTAINER Francis Chuang <francis.chuang@boostport.com>

ENV HADOOP_VERSION=2.7.4 HADOOP_HOME=/opt/hadoop

RUN apk --no-cache --update add bash \
    bzip2 \
    fts \
    fuse \
    libressl-dev \
    libtirpc \
    snappy \
    zlib \
    ca-certificates \
    gnupg \
    openssl \
    su-exec \
    tar \
    nginx \
    curl \
 && apk --no-cache --update --repository https://dl-3.alpinelinux.org/alpine/edge/community/ add xmlstarlet
# && update-ca-certificates

# Build deps 1
RUN apk --no-cache --update add --virtual .builddeps.1 \
        autoconf \
        automake \
        build-base \
        libtool \
        zlib-dev

# Install Protobuf
RUN cd /tmp \
 && wget https://github.com/google/protobuf/releases/download/v2.5.0/protobuf-2.5.0.tar.gz \
 && tar zxf protobuf-2.5.0.tar.gz \
 && cd protobuf-2.5.0 \
 && ./configure --prefix=/usr \
 && make && make install && protoc --version \
\
# Set up directories
 && mkdir -p $HADOOP_HOME \
 && mkdir -p /var/lib/hadoop

# Download Hadoop
RUN wget -O /tmp/KEYS https://dist.apache.org/repos/dist/release/hadoop/common/KEYS \
 && gpg --import /tmp/KEYS \
 && wget -q -O /tmp/hadoop-$HADOOP_VERSION-src.tar.gz http://ftp.yz.yamagata-u.ac.jp/pub/network/apache/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION-src.tar.gz  \
 && wget -O /tmp/hadoop.asc https://dist.apache.org/repos/dist/release/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION-src.tar.gz.asc \
 && gpg --verify /tmp/hadoop.asc /tmp/hadoop-$HADOOP_VERSION-src.tar.gz
# Intall build tools
RUN apk --no-cache --update add --virtual .builddeps.2 \
    autoconf \
    automake \
    build-base \
    bzip2-dev \
    cmake \
    curl \
    fts-dev \
    fuse-dev \
    git \
    libtirpc-dev \
    libtool \
    maven \
    snappy-dev \
    zlib-dev

# Unzip and build
RUN cd /tmp \
 && tar -xzf hadoop-$HADOOP_VERSION-src.tar.gz \
 && cd hadoop-$HADOOP_VERSION-src \
 && sed -ri 's/^#if defined\(__sun\)/#if 1/g' hadoop-common-project/hadoop-common/src/main/native/src/exception.c \
 && sed -ri 's/^(.*JniBasedUnixGroupsNetgroupMapping.c)/#\1/g' hadoop-common-project/hadoop-common/src/CMakeLists.txt \
 && sed -ri 's/^( *container)/\1\n    fts/g' hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-nodemanager/src/CMakeLists.txt \
 && sed -ri 's#^(include_directories.*)#\1\n    /usr/include/tirpc#' hadoop-tools/hadoop-pipes/src/CMakeLists.txt \
 && sed -ri 's/^( *pthread)/\1\n    tirpc/g' hadoop-tools/hadoop-pipes/src/CMakeLists.txt \
 && MAVEN_OPTS=-Xmx512M mvn -e clean package -Dmaven.javadoc.skip=true -DskipTests=true -Pdist,native -Dtar -Dsnappy.lib=/usr/lib -Dbundle.snappy \
# Unzip hadoop to /opt
 && tar -xzf hadoop-dist/target/hadoop-$HADOOP_VERSION.tar.gz -C $HADOOP_HOME  --strip-components 1 \
\
# Set up permissions
 && addgroup -S hadoop \
 && adduser -h $HADOOP_HOME -G hadoop -S -D -H -s /bin/false -g hadoop hadoop \
 && chown -R hadoop:hadoop $HADOOP_HOME \
 && chown -R hadoop:hadoop /var/lib/hadoop \
\
# Clean up
 && cd / \
 && rm -rf /tmp/* /var/tmp/* /var/cache/apk/* \
 && rm -rf /tmp/hadoop-* \
 && rm -rf ${HADOOP_HOME}/share/doc \
 && for dir in common hdfs mapreduce tools yarn; do \
        rm -rf ${HADOOP_HOME}/share/hadoop/${dir}/sources; \
    done \
 && rm -rf ${HADOOP_HOME}/share/hadoop/common/jdiff \
 && rm -rf ${HADOOP_HOME}/share/hadoop/mapreduce/lib-examples \
 && rm -rf ${HADOOP_HOME}/share/hadoop/yarn/test \
 && find ${HADOOP_HOME}/share/hadoop -name *test*.jar | xargs rm -rf \
 && rm -rf /root/.m2 \
 && apk del gnupg openssl tar \
 && apk del \
  .builddeps.1 \
  .builddeps.2

VOLUME ["/var/lib/hadoop"]

ADD ["run-hadoop.sh", "/"]
ADD ["/roles", "/roles"]

COPY nginx.default.conf /etc/nginx/conf.d/default.conf

#      Namenode              Datanode                     Journalnode
EXPOSE 8020 9000 50070 50470 50010 50075 50475 1006 50020 8485 8480 8481

CMD ["/run-hadoop.sh"]
WORKDIR $HADOOP_HOME
ENV HADOOP_ROOT_LOGGER="INFO,DRFA"