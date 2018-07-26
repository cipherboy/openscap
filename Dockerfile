FROM fedora:28

ENV OSCAP_USERNAME oscap
ENV OSCAP_DIR scap-security-guide
ENV BUILD_JOBS 4

RUN dnf -y upgrade --refresh && \
    dnf -y install cmake dbus-devel GConf2-devel libacl-devel libblkid-devel libcap-devel libcurl-devel \
                   libgcrypt-devel libselinux-devel libxml2-devel libxslt-devel libattr-devel make openldap-devel \
                   pcre-devel perl-XML-Parser perl-XML-XPath perl-devel python-devel rpm-devel swig \
                   bzip2-devel gcc-c++ && \
    mkdir -p /home/$OSCAP_USERNAME && \
    dnf clean all && \
    rm -rf /usr/share/doc /usr/share/doc-base \
        /usr/share/man /usr/share/locale /usr/share/zoneinfo

WORKDIR /home/$OSCAP_USERNAME

COPY . $OSCAP_DIR/

# clean the build dir in case the user is also building OpenSCAP locally
RUN rm -rf $OSCAP_DIR/build/*

WORKDIR /home/$OSCAP_USERNAME/$OSCAP_DIR/build

CMD gcc --version && cmake .. && make -j $BUILD_JOBS && ctest --output-on-failure -R 'test_api_seap'
