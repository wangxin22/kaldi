<<<<<<< HEAD
#export KALDI_ROOT=`pwd`/../../..
export KALDI_ROOT=/efs/mlteam/xuechen/kaldi-lingo
=======
export KALDI_ROOT=`pwd`/../../..
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh
export LC_ALL=C
<<<<<<< HEAD

export LD_LIBRARY_PATH=/efs/mlteam/raymond/cuda-8.0/lib64

=======
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
