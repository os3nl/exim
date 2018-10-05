FROM alpine

# deps are inspired by https://git.alpinelinux.org/cgit/aports/tree/community/exim/APKBUILD#n18
RUN apk add --no-cache \
  bash \
  curl \
  db-dev \
  gawk \
  gnupg \
  libidn-dev \
  libressl-dev \
  libspf2-dev \
  linux-headers \
  mariadb-connector-c-dev \
  pcre-dev \
  perl \
  postgresql-dev \
  sqlite-dev


# 1.a First make sure that your system does not contain a pre-installed version of the
# MTA of your choice, if so, remove it before you continue.
RUN (which exim && echo exim found && exit 1) || true

# 1.b Make sure the source code is retrieved from a secure location.
# Use the official website for the MTA of your choice.
ARG EXIM_VERSION=4.91
ARG EXIM_URL=ftp://mirror.easyname.at/exim-ftp/exim/exim4/exim-$EXIM_VERSION.tar.gz
RUN wget -O /tmp/exim.tgz $EXIM_URL
# which is from the first source found at https://www.exim.org/mirmon/ftp_mirrors.html

# 1.c Because it is important that an MTA be correct and secure it is often signed
# using a digital PGP signature. If your MTA is signed then make sure3 you
# have downloaded the correct sources by checking the validity of the key and
# the signature.
RUN wget -O /tmp/exim.asc $EXIM_URL.asc
# which is signed by 'the file nigel-pubkey.asc'
# src: https://www.exim.org/exim-html-current/doc/html/spec_html/ch-introduction.html
ARG KEYFILEURL=ftp://mirror.easyname.at/exim-ftp/exim/nigel-pubkey.asc
RUN wget -O /tmp/key $KEYFILEURL
RUN gpg --import /tmp/key
# But this failed:
# gpg: Signature made Sun Apr 15 13:23:10 2018 UTC
# gpg:                using RSA key BCE58C8CE41F32DF
# gpg: Can't check signature: No public key
# So we read further at the source above:
# At time of last update, releases were being made by Jeremy Harris
# and signed with key 0xBCE58C8CE41F32DF.
# Other recent keys used for signing are those of Heiko Schlittermann,
# 0x26101B62F69376CE, and of Phil Pennock, 0x4D1E900E14C1CC04.
ARG KEYSURL=ftp://mirror.easyname.at/exim-ftp/exim/Exim-Maintainers-Keyring.asc
ARG KEYSURL=http://exim.mirror.colo-serv.net/exim/Exim-Maintainers-Keyring.asc
RUN wget -O /tmp/keys $KEYSURL
RUN gpg --import /tmp/keys
RUN gpg --verify /tmp/exim.asc /tmp/exim.tgz

# 1.d There are a number of options that you will have to enter before compilation,
# so that the functionality can be compiled into the program. Make sure the basic
# install holds all the necessary functionality. Show the options you configured.
RUN cd /tmp && tar xfz /tmp/exim.tgz
RUN mv /tmp/exim-4* /tmp/exim
WORKDIR /tmp/exim
RUN apk add --no-cache alpine-sdk
ARG ALPINEMAKE=https://git.alpinelinux.org/cgit/aports/plain/community/exim/exim.Makefile
RUN wget -O /tmp/exim/Local/Makefile $ALPINEMAKE
RUN sed -i -e 's/-lnsl//g' -e 's/^HAVE_ICONV.*$//' \
  /tmp/exim/OS/Makefile-Linux
RUN make Makefile
RUN make -j1
RUN make INSTALL_ARG="exim_dbmbuild exim_dumpdb exim_tidydb exim_fixdb exim_lock" install
RUN adduser -D exim
RUN make INSTALL_ARG="exim" install
# Since we have two, we symlink (/usr/sbin/exim-4.91-6  /usr/sbin/exim-4.91-8)
RUN ln -s `ls /usr/sbin/exim-*|tail -1` /usr/sbin/exim
ENTRYPOINT ["/usr/sbin/exim"]

CMD ["-bd", "-v"]
