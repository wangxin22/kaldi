#!/bin/bash
# Copyright 2018 AIShell-Foundation(Authors:Jiayu DU, Xingyu NA, Bengu WU, Hao ZHENG)
#           2018 Beijing Shell Shell Tech. Co. Ltd. (Author: Hui BU)
<<<<<<< HEAD
#           2018 Emotech LTD (Author: Xuechen LIU)
=======
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
# Apache 2.0

# transform raw AISHELL-2 data to kaldi format

. ./path.sh || exit 1;

<<<<<<< HEAD
expected_num_files=1009223
tmp=data/local/train
dir=data/train

if [ $# != 3 ]; then
  echo "Usage: $0 <corpus-data-dir> <dict-dir> <output-dir>"
  echo " $0 /export/AISHELL-2/iOS/data data/local/dict data/train"
=======
tmp=
dir=

if [ $# != 4 ]; then
  echo "Usage: $0 <corpus-data-dir> <dict-dir> <tmp-dir> <output-dir>"
  echo " $0 /export/AISHELL-2/iOS/train data/local/dict data/local/train data/train"
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
  exit 1;
fi

corpus=$1
dict_dir=$2
<<<<<<< HEAD
dir=$3
=======
tmp=$3
dir=$4

echo "prepare_data.sh: Preparing data in $corpus"
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e

mkdir -p $tmp
mkdir -p $dir

# corpus check
if [ ! -d $corpus ] || [ ! -f $corpus/wav.scp ] || [ ! -f $corpus/trans.txt ]; then
  echo "Error: $0 requires wav.scp and trans.txt under $corpus directory."
  exit 1;
fi

<<<<<<< HEAD
# check file number
num_wav=`sed '/^[[space]]*$/d' $corpus/wav.scp | wc -l`
num_trans=`sed '/^[[space]]*$/d' $corpus/trans.txt | wc -l`
if [ $num_wav -ne $expected_num_files ] || [ $num_trans -ne $expected_num_files ]; then
  echo "Warning:"
  echo "  There are $expected_num_files files in AISHELL-2 corpus"
  echo "  Found $num_wav wavs in wav.scp and $num_trans trans in trans.txt"
fi

# validate utt-key list
awk '{print $1}' $corpus/wav.scp   > $tmp/wav_utt.list
awk '{print $1}' $corpus/trans.txt > $tmp/trans_utt.list
cat $tmp/wav_utt.list | sort -k 1 | uniq > $tmp/utt.list
=======
# validate utt-key list
awk '{print $1}' $corpus/wav.scp   > $tmp/wav_utt.list
awk '{print $1}' $corpus/trans.txt > $tmp/trans_utt.list
utils/filter_scp.pl -f 1 $tmp/wav_utt.list $tmp/trans_utt.list > $tmp/utt.list
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e

# wav.scp
awk -F'\t' -v path_prefix=$corpus '{printf("%s\t%s/%s\n",$1,path_prefix,$2)}' $corpus/wav.scp > $tmp/tmp_wav.scp
utils/filter_scp.pl -f 1 $tmp/utt.list $tmp/tmp_wav.scp | sort -k 1 | uniq > $tmp/wav.scp

# text
<<<<<<< HEAD
cat $corpus/trans.txt | awk '{print $2}' | paste -d'\t' $tmp/utt.list - | sort -k 1 | uniq > $tmp/trans.txt
=======
python -c "import jieba" 2>/dev/null || \
  (echo "jieba is not found. Use tools/extra/install_jieba.sh to install it." && exit 1;)
utils/filter_scp.pl -f 1 $tmp/utt.list $corpus/trans.txt | sort -k 1 | uniq > $tmp/trans.txt
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
awk '{print $1}' $dict_dir/lexicon.txt | sort | uniq | awk 'BEGIN{idx=0}{print $1,idx++}'> $tmp/vocab.txt
python local/word_segmentation.py $tmp/vocab.txt $tmp/trans.txt > $tmp/text

# utt2spk & spk2utt
awk -F'\t' '{print $2}' $tmp/wav.scp > $tmp/wav.list
sed -e 's:\.wav::g' $tmp/wav.list | \
  awk -F'/' '{i=NF-1;printf("%s\t%s\n",$NF,$i)}' > $tmp/tmp_utt2spk
utils/filter_scp.pl -f 1 $tmp/utt.list $tmp/tmp_utt2spk | sort -k 1 | uniq > $tmp/utt2spk
utils/utt2spk_to_spk2utt.pl $tmp/utt2spk | sort -k 1 | uniq > $tmp/spk2utt

<<<<<<< HEAD
# copy prepared resouces from tmp_dir to train dir (data/train)
=======
# copy prepared resources from tmp_dir to target dir
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
mkdir -p $dir
for f in wav.scp text spk2utt utt2spk; do
  cp $tmp/$f $dir/$f || exit 1;
done

echo "local/prepare_data.sh succeeded"
exit 0;
