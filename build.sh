#!/bin/bash
############################################################
# This script builds Qt5, QScintilla and qwt with
# sip Python bindings.
# Tested and developed on xenial 64bit
# All other dev packages required to build QGIS need
# to be installed with apt
# Qt is built in debug mode.

set -e

# Enable DEBUG build
DEBUG=0


# Store script directory
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Number of cores for C++ compiler
CORES=`nproc`

QT_VERSION="5.11.2"
# Suffix for install dir
QT_VER=11_2

WEBKIT_VERSION="5.212"

QSCINTILLA_VERSION="2.10.8"

QWT_VERSION="6.1.3"

SIP_VERSION="4.19.13"

# Qt Sources Path
QT_SRC_PATH=~/Qt/${QT_VERSION}/Src


if [ "$DEBUG" = "1" ]; then
DEBUG_FLAG="-debug"
else
DEBUG_FLAG=""
QT_VER=${QT_VER}_release
fi


# Install dir
PREFIX=~/local${QT_VER}


#########################################
# Build Qt

# Note: 5.10.0 does not build with clang but with gcc only

if [ ! -e ${PREFIX}/bin/qmake ]; then

cd ${QT_SRC_PATH}


#if [ ${QT_VER} = "10_1" ]; then

CFLAGS="-O0" ./configure \
    -prefix ${PREFIX} \
    $DEBUG_FLAG \
    -opensource \
    -confirm-license \
    -ccache \
    -platform linux-clang
    #-no-use-gold-linker

    #-platform linux-clang \
#else
#./configure \
#    -prefix ${PREFIX} \
#    $DEBUG_FLAG \
#    -opensource \
#    -confirm-license \
#    -ccache \
#    -platform linux-clang
#
#fi

make -j${CORES}
make -j${CORES} install

cd ${THIS_DIR}

fi

#########################################
# Webkit


if [ ! -e ${PREFIX}/lib/libQt5WebKit.so ]; then

if [ ! -e qtwebkit-${WEBKIT_VERSION} ]; then
    wget https://github.com/qt/qtwebkit/archive/${WEBKIT_VERSION}.zip
    unzip ${WEBKIT_VERSION}.zip
fi

cd qtwebkit-${WEBKIT_VERSION}


$PREFIX/bin/qmake WebKit.pro

echo "set(CMAKE_PREFIX_PATH ${PREFIX})" >> CMakeFiles.txt

make -j${CORES}
make -j${CORES} install

cd ${THIS_DIR}

fi

########################################
# QScintilla

if [ ! -e ${PREFIX}/lib/libqscintilla2_qt5.so ]; then

if [ ! -d QScintilla_gpl-${QSCINTILLA_VERSION} ]; then
    wget https://sourceforge.net/projects/pyqt/files/QScintilla2/QScintilla-${QSCINTILLA_VERSION}/QScintilla_gpl-${QSCINTILLA_VERSION}.tar.gz
    tar -xzf QScintilla_gpl-${QSCINTILLA_VERSION}.tar.gz
fi

cd QScintilla_gpl-${QSCINTILLA_VERSION}
cd Qt4Qt5
$PREFIX/bin/qmake qscintilla.pro
make -j${CORES} install

cd ${THIS_DIR}

fi


#######################################
# qwt

if [ ! -d qwt-${QWT_VERSION} ]; then
    wget https://netcologne.dl.sourceforge.net/project/qwt/qwt/${QWT_VERSION}/qwt-${QWT_VERSION}.tar.bz2
    tar -xjf qwt-${QWT_VERSION}.tar.bz2
fi

cd qwt-${QWT_VERSION}
perl -i -pe "s@/usr/local@${PREFIX}@" qwtconfig.pri

$PREFIX/bin/qmake qwt.pro

make -j${CORES} install

cd ${THIS_DIR}


#######################################
# SIP

if [ ! -d sip-${SIP_VERSION} ]; then
    wget https://sourceforge.net/projects/pyqt/files/sip/sip-${SIP_VERSION}/sip-${SIP_VERSION}.tar.gz
    tar -xzf sip-${SIP_VERSION}.tar.gz
fi
cd sip-${SIP_VERSION}

python3 configure.py \
    --sip-module=PyQt5.sip \
    --bindir=$PREFIX/bin \
    --destdir=$PREFIX/lib/python3/dist-packages/ \
    --incdir=$PREFIX/include \
    --sipdir=$PREFIX/share/sip \
    --stubsdir=$PREFIX/lib/python3/dist-packages/

make -j${CORES} install

cd ${THIS_DIR}

#######################################
# PyQt5


if [ ! -d  PyQt5_gpl-${QT_VERSION} ]; then
    wget https://sourceforge.net/projects/pyqt/files/PyQt5/PyQt-${QT_VERSION}/PyQt5_gpl-${QT_VERSION}.tar.gz
    tar -xzf PyQt5_gpl-${QT_VERSION}.tar.gz
fi

cd PyQt5_gpl-${QT_VERSION}

# Fix error: Error: Unable to import PyQt5.sip. Make sure you have configured SIP to create
#a private copy of the sip module.
touch $PREFIX/lib/python3/dist-packages/PyQt5/__init__.py

if [ ! -d $PREFIX/designer ]; then
    mkdir $PREFIX/designer
fi

PYTHONPATH=$PREFIX/lib/python3/dist-packages:$PYTHONPATH python3 configure.py \
    --qmake $PREFIX/bin/qmake \
    --sip $PREFIX/bin/sip \
    --sip-incdir $PREFIX/include/ \
    --sipdir $PREFIX/share/sip/PyQt5  \
    --destdir $PREFIX/lib/python3/dist-packages \
    --bindir $PREFIX/bin/ \
    --stubsdir=$PREFIX/lib/python3/dist-packages/PyQt5 \
    --qsci-api-destdir $PREFIX/qsci \
    --designer-plugindir $PREFIX/designer \
    --confirm-license

# Warning: no -j here or it will not complete the build (only god knows why)
make install

cd ${THIS_DIR}


#######################################
# QScintilla bindings (require sip)

cd QScintilla_gpl-${QSCINTILLA_VERSION}
cd Python


PYTHONPATH=$PREFIX/lib/python3/dist-packages:$PYTHONPATH python3 configure.py \
    --qmake=$PREFIX/bin/qmake \
    --sip=$PREFIX/bin/sip \
    --sip-incdir=$PREFIX/include/ \
    --qsci-sipdir=$PREFIX/share/sip/PyQt5  \
    --qsci-incdir=$PREFIX/include \
    --qsci-libdir=$PREFIX/lib \
    --pyqt-sipdir=$PREFIX/share/sip/PyQt5  \
    --destdir=$PREFIX/lib/python3/dist-packages/PyQt5 \
    --stubsdir=$PREFIX/lib/python3/dist-packages/PyQt5 \
    --pyqt=PyQt5

make -j${CORES} install


cd ${THIS_DIR}

# All done
echo "All done: library installed in ${PREFIX}"

