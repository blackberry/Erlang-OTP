#!/bin/bash

build_erlang_for_playbook()
{
    ###########################################################################
    # Setup environment                                                       #
    ###########################################################################
    set -e

    # ensure required BBNDK env variables are set
    : ${QNX_HOST:?"Error: QNX_HOST environment variable is not set."}
    : ${QNX_TARGET:?"Error: QNX_TARGET environment variable is not set."}

    local BUILD_ROOT=`pwd`
    pushd ..
    local ERLANG_ROOT=`pwd`
    popd


    ###########################################################################
    # Build Erlang Bootstrap                                                  #
    ###########################################################################
    pushd $ERLANG_ROOT

    export ERL_TOP=`pwd`

    if [ ! -f configure ] ; then
        ./otp_build autoconf
    fi

    ./configure --enable-bootstrap-only

    # a missing directory causes a build error, create it to prevent the error
    pushd lib/hipe
    if [ ! -d "ebin" ]; then
      mkdir ebin
    fi
    popd

    # build fails with -j8 option
    make

    # Add path to erlc
    local ERLC_BOOTSTRAP_DIR=`pwd`/bootstrap/bin
    if [ ! -f $ERLC_BOOTSTRAP_DIR/erlc ] ; then
        echo "Couldn't find $ERLC_BOOTSTRAP_DIR/erlc; did the Erlang build for Linux fail?"
    fi

    export PATH=$ERLC_BOOTSTRAP_DIR:$PATH

    pushd lib
    ./configure
    make
    popd

    popd

    ###########################################################################
    # Setup PlayBook Environment Variables                                    #
    ###########################################################################

    #set up env for cross-compiling for PlayBook
    export PATH=$QNX_HOST/usr/bin:$PATH
    export CC="$QNX_HOST/usr/bin/qcc -V4.4.2,gcc_ntoarmv7le_cpp "
    export CFLAGS="-V4.4.2,gcc_ntoarmv7le_cpp -g "
    export CPP="$QNX_HOST/usr/bin/qcc -V4.4.2,gcc_ntoarmv7le_cpp -E"
    export LD="$QNX_HOST/usr/bin/ntoarmv7-ld "
    export RANLIB="$QNX_HOST/usr/bin/ntoarmv7-ranlib "



    ###########################################################################
    # Build Erlang For PlayBook                                               #
    ###########################################################################
    pushd $ERLANG_ROOT

    CPPFLAGS="-D__PLAYBOOK__ -D__QNXNTO__ -DNO_SYSLOG -DLOG_ERR=1 -DSIZEOF_VOID_P=4 -I$QNX_TARGET/usr/include " \
    LDFLAGS="-L$QNX_TARGET/armle-v7/lib -L$QNX_TARGET/armle-v7/usr/lib -lm -lsocket " \
    erl_xcomp_sysroot=$QNX_TARGET/armle-v7 \
    erl_xcomp_isysroot=$QNX_TARGET/usr/include \
    erl_xcomp_bigendian=no \
    erl_xcomp_linux_clock_gettime_correction=yes \
    erl_xcomp_linux_nptl=yes \
    erl_xcomp_linux_usable_sigusrx=yes \
    erl_xcomp_linux_usable_sigaltstack=yes \
    erl_xcomp_poll=yes \
    erl_xcomp_kqueue=yes \
    erl_xcomp_putenv_copy=yes \
    erl_xcomp_reliable_fpe=yes \
    erl_xcomp_getaddrinfo=yes \
    erl_xcomp_gethrvtime_procfs_ioctl=no \
    erl_xcomp_clock_gettime_cpu_time=yes \
    erl_xcomp_after_morecore_hook=no \
    erl_xcomp_dlsym_brk_wrappers=yes \
    ./configure --build=i686-pc-linux-gnu --host=arm-unknown-nto-qnx6.5.0eabi --prefix=$BUILD_ROOT/Erlang --disable-hipe --with-ssl=$QNX_TARGET/usr/include/openssl

    # comment out -lrt in <ERL_TOP>/erts/emulator/arm-unknown-nto-qnx6.5.0eabi/Makefile (this causes a build error)
    pushd erts/emulator/arm-unknown-nto-qnx6.5.0eabi
    cat Makefile | sed -e 's/LIBS\ +=\ -lrt/\#LIBS\ +=\ -lrt/' > temp.mk
    rm Makefile
    mv temp.mk Makefile
    popd

    make
    make release RELEASE_ROOT=$BUILD_ROOT/Erlang
    pushd $BUILD_ROOT/Erlang
    ./Install -cross -minimal $BUILD_ROOT/Erlang
    popd

    popd
}

build_erlang_for_playbook
