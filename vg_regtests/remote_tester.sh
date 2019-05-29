#! /bin/bash

die(){
  echo "$*" 1>&2 ;
  exit 1;
}

pretty_print(){
  printf "\n------------------- $* -------------------------------\n\n"
}

verbose_print(){
  if [ $verbose ];then printf "$*";fi
}

#------------------- copy test files from valgrind to test dir -----------------
#$1 = relative path after cd $AP_VG
pull_tests(){
  for next_dir in $(ls -l $1 | grep ^d | awk '{ print $9 }' | grep -v nto-)
  do
    if [[ $next_dir == 'tests' ]]; then
      if [ ! -d "$AP_TESTS/$1" ]; then mkdir $AP_TESTS/$1;fi
      cp -r $1/$next_dir $AP_TESTS/$1/tests
    else pull_tests $1/$next_dir ;fi
    cp $1/*.h $AP_TESTS/$1 2>/dev/null
  done
}


# --------------------------- main ---------------------------------------------
#
#$1 = AP_VG
#
# ------------------------------------------------------------------------------
if [[ $# != 1 ]];then die 'Illegal amount of arguments\n';fi

verbose=''
AP_VG=$(realpath $1)
TEST_DIR="vg_remote_test_dir"
CUR_DIR=$(pwd)
AP_TESTS=$CUR_DIR/$TEST_DIR #save absolute path to TEST_DIR
TOOLS=memcheck
LINKED_DIRS='include
             VEX/pub'

# ---------------------------- create dir with test files -----------------------
if [ ! -d $TEST_DIR ]; then
  mkdir $TEST_DIR;
  cd $AP_VG
  for tool in $TOOLS;do pull_tests $tool; done
  cp -r $AP_VG/tests $AP_TESTS/
else printf "vg_remote_test_dir already exist\n";fi
# ----------------------------- create symlinks ---------------------------------
# TODO too dirty one
pretty_print "creating symlinks"

for tool in $TOOLS;do
  for lndir in  $LINKED_DIRS;do
    for f in $(ls $AP_VG/$lndir);do
      if [ ! -L $AP_TESTS/$tool/tests/$f ] && [ ! -f $AP_TESTS/$tool/tests/$f ];then
        ln -s $AP_VG/$lndir/$f $AP_TESTS/$tool/tests/$f;
      fi
    done
  done
  ln -s $AP_TESTS/$tool $AP_TESTS/$tool/tests/$tool
  ln -s $AP_VG/include $AP_TESTS/$tool/include
  ln -s $AP_VG/config.h.in~ $AP_TESTS/$tool/config.h
  ln -s $AP_VG/config.h.in~ $AP_TESTS/$tool/tests/config.h
  ln -s $AP_VG/coregrind $AP_TESTS/$tool/tests/coregrind
  ln -s $AP_VG/tests/ $AP_TESTS/$tool/tests/tests

  for f in $(ls $AP_VG/coregrind/ | grep 'pub_core_');do
    ln -s $AP_VG/coregrind/$f $AP_TESTS/$tool/tests/$f
  done

  for f in $(ls $AP_VG/coregrind/ | grep 'pub_tool_');do
    ln -s $AP_VG/coregrind/$f $AP_TESTS/$tool/tests/$f
  done

  for f in 'm_libcbase.c';do
    ln -s $AP_VG/coregrind/$f $AP_TESTS/$tool/tests/$f
  done


done


mkdir -p $AP_TESTS/vg_stdlib
ln -s $AP_VG/include/valgrind.h $AP_TESTS/vg_stdlib/valgrind.h
ln -s $AP_VG/config.h.in~ $AP_TESTS/vg_stdlib/config.h
ln -s $AP_VG/include/vki $AP_TESTS/vg_stdlib/vki


ln -s $AP_VG/include/valgrind.h $AP_TESTS/memcheck/valgrind.h
ln -s $AP_VG/include $AP_TESTS/include
cp $AP_VG/config.h.in~ $AP_TESTS/config.h
#cp $AP_VG/config.h.in~ $AP_TESTS/none/config.h

#---------------------------- compiling C files --------------------------------
# TODO
pretty_print "compiling"

bad_progs='buflen_check.vgtest
           null_socket.vgtest
           reach_thread_register.vgtest
           sendmsg.vgtest
           stpncpy.vgtest
           suppvarinfo5.vgtest
           unit_oset.vgtest
           varinfo5.vgtest
           varinforestrict.vgtest
           vcpu_fnfns.vgtest
           wrap7.vgtest'


CC='powerpc-unknown-nto-qnx6.5.0-gcc'
CCFLAGS='-D VGO_nto -D VGA_ppc32'

tnum=0
tcpp=0
tnfound=0 #not found tests
tall=0
talrexs=0
tbuilded=0


for tool in $TOOLS;do
  cd $AP_TESTS/$tool/tests
  rm -f $bad_progs
  for f in $(ls | grep '.vgtest');do

    tname=$(cat $f | grep 'prog:' | sed -e 's/prog: //' -e 's/ //g' )
    verbose_print "f = $f, tname = $tname\n";

    #TODO what about *.cpp
    if [ ! -f $tname ] && [ -f $tname.c ];then
      $CC -I $AP_TESTS/vg_stdlib -o $tname $CCFLAGS $tname.c 1>/dev/null 2>$tname.log;
      if [ ! -f $tname ];then die "compilation failed \n $(cat $tname.log)\n";
      else
        verbose_print "$tname compilation done\n\n";
        rm -f $tname.log;
        tbuilded=$((tbuilded+1));
      fi
      tnum=$((tnum+1));
    elif [ -f $tname.cpp ];then
      verbose_print "$tname.cpp found\n";
      tcpp=$((tcpp+1));
    elif [ -f $tname ];then
      verbose_print "compiled file already exists\n";
      tnum=$((tnum+1));
      talrexs=$((talrexs+1));
    else
      verbose_print "$tname: c or cpp files not found in"
      tnfound=$((tnfound+1));
    fi
    tall=$((tall+1));
  done
done

pretty_print "compiling done"
printf "Compiled tests number = $tnum \ $tall ($tcpp cpp files, $tnfound not found )\n"
printf "builded               = $tbuilded\n"
printf "was already builded   = $talrexs\n"

#---------------------------- removing symlinks ----------------------------------
# TODO too dirty one
pretty_print "removing symlinks"
for tool in $TOOLS;do
  for lndir in  $LINKED_DIRS;do
    for f in $(ls $AP_TESTS/$tool/tests/);do
      # if [ -L $AP_TESTS/$tool/tests/$f ] || [ $(echo $f | cut -d . -f2) = 'c' ];then
      if [ -L $AP_TESTS/$tool/tests/$f ];then
        rm $AP_TESTS/$tool/tests/$f;
      fi
    done
  done
  rm -f $AP_TESTS/$tool/tests/$tool
  rm -f $AP_TESTS/$tool/include
  rm -f $AP_TESTS/$tool/config.h
  rm -f $AP_TESTS/$tool/tests/config.h
  rm -f $AP_TESTS/$tool/tests/coregrind

  for f in $(ls $AP_VG/coregrind/ | grep 'pub_core_');do
    rm -f $AP_TESTS/$tool/tests/$f
  done

  for f in $(ls $AP_VG/coregrind/ | grep 'pub_tool_');do
    rm -f $AP_TESTS/$tool/tests/$f
  done

  for f in 'm_libcbase.c';do
    rm -f $AP_TESTS/$tool/tests/$f
  done


done

rm -r $AP_TESTS/vg_stdlib

rm -f $AP_TESTS/memcheck/valgrind.h
rm -f $AP_TESTS/include
rm -f $AP_TESTS/config.h
rm -f $AP_TESTS/none/config.h


#---------------------------- load & test on remote machine for testing --------

pretty_print "remote testing"

TARGET_PATH='/home'
TARGET='root@172.16.36.99'
TARGET_LOG_FILE='/home/vg_tests_remote.log'

printf "loading $TEST_DIR to $TARGET... "

ssh -q $TARGET [[ -d /home/vg_remote_test_dir ]] &&
 printf "$TARGET_PATH/$TEST_DIR already exists\nexiting... " ||
 scp -r $AP_TESTS $TARGET:$TARGET_PATH;

printf "done\n"

ssh $TARGET $TARGET_PATH/$TEST_DIR/tests/vg_regtest_try.sh $TARGET_LOG_FILE

pretty_print "testing finished"
