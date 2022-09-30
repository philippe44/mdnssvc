#!/bin/sh
make -f Makefile.armhf $1
make -f Makefile.aarch64 $1
make -f Makefile.x86 $1
#make -f Makefile.i86pc-solaris $1
#make -f Makefile.bsd-x64 $1
#make -f Makefile.osx $1
