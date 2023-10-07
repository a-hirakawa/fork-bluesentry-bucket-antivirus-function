FROM amazonlinux:2

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/

# Install packages
RUN yum update -y
RUN yum install -y cpio yum-utils zip unzip less gcc make patch zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl11-devel tk-devel libffi-devel xz-devel git tar libtool-ltdl
RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
RUN curl -s -S -L https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer | bash
RUN PATH=$PATH:/root/.pyenv/bin && \
    eval "$(pyenv init -)" && \
    pyenv install 3.11.5

# Download libraries we need to run in lambda
WORKDIR /tmp
RUN yumdownloader -x \*i686 --archlist=x86_64 clamav clamav-lib clamav-update json-c pcre2 libprelude gnutls libtasn1 lib64nettle nettle binutils
RUN rpm2cpio clamav-0*.rpm | cpio -idmv
RUN rpm2cpio clamav-lib*.rpm | cpio -idmv
RUN rpm2cpio clamav-update*.rpm | cpio -idmv
RUN rpm2cpio json-c*.rpm | cpio -idmv
RUN rpm2cpio pcre*.rpm | cpio -idmv
RUN rpm2cpio gnutls* | cpio -idmv
RUN rpm2cpio nettle* | cpio -idmv
RUN rpm2cpio lib* | cpio -idmv
RUN rpm2cpio *.rpm | cpio -idmv
RUN rpm2cpio libtasn1* | cpio -idmv
RUN rpm2cpio binutils-*.rpm | cpio -idmv

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/

COPY requirements.txt /opt/app/requirements.txt
RUN PATH=$PATH:/root/.pyenv/bin && \
    eval "$(pyenv init -)" && \
    pyenv global 3.11 && \
    pip3 install -r /opt/app/requirements.txt

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Copy over the binaries and libraries
RUN cp /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/bin/ld.bfd /tmp/usr/lib64/* /opt/app/bin/
RUN cp --dereference /usr/lib64/{libpcre.so.1.2.0,libltdl.so.7,libxml2.so.2,liblzma.so.5,libcurl.so.4,libnghttp2.so.14,libidn2.so.0,libssh2.so.1,libldap-2.4.so.2,liblber-2.4.so.2,libunistring.so.0,libsasl2.so.3,libssl3.so,libsmime3.so,libnss3.so,libcrypt.so.1} /opt/app/bin/

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

WORKDIR /root/.pyenv/versions/3.11.5/lib/python3.11/site-packages
RUN zip -r9 --exclude="pip/*" --exclude="pip-*.dist-info/*" --exclude="setuptools/*" --exclude="setuptools-*.dist-info/*" --exclude="pkg_resources/*" --exclude="pkg_resources-*.dist-info/*" --exclude="*/__pycache__/*" --exclude="__pycache__/*" /opt/app/build/lambda.zip *

WORKDIR /opt/app
