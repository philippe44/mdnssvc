#/bin/sh
rm *.a *.o
$CC $1 -DNDEBUG -DMDNS_SVC -c *.c
ar rcs tinysvcmdns.a *.o
