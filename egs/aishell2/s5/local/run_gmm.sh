#!/bin/bash
# Copyright 2018 AIShell-Foundation(Authors:Jiayu DU, Xingyu NA, Bengu WU, Hao ZHENG)
#           2018 Beijing Shell Shell Tech. Co. Ltd. (Author: Hui BU)
#           2018 Emotech LTD (Author: Xuechen LIU)
# Apache 2.0

set -euxo pipefail

# number of jobs
<<<<<<< HEAD
stage=0
nj=20

. ./cmd.sh
[ -f ./path.sh ] && . ./path.sh;
. parse_options.sh

dev_nj=$(wc -l data/dev/spk2utt | awk '{print $1}' || exit 1;)
test_nj=$(wc -l data/test/spk2utt | awk '{print $1}' || exit 1;)

# Now make MFCC plus pitch features.
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
if [ $stage -le 0 ]; then
  for x in train dev test; do
    mfccdir=exp/mfcc_$x
    steps/make_mfcc_pitch.sh --mfcc-config conf/mfcc.conf --pitch-config conf/pitch.conf \
      --cmd "$train_cmd" --nj $nj data/$x exp/make_mfcc/$x $mfccdir || exit 1;
    steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir || exit 1;
    utils/fix_data_dir.sh data/$x || exit 1;
  done

=======
nj=20
stage=1

. ./cmd.sh
[ -f ./path.sh ] && . ./path.sh;
. ./utils/parse_options.sh

# nj for dev and test
dev_nj=$(wc -l data/dev/utt2spk | awk '${print $1}' || exit 1;)
test_nj=$(wc -l data/test/utt2spk | awk '${print $1}' || exit 1;)


# Now make MFCC plus pitch features.
if [ $stage -le 1 ]; then
  # mfccdir should be some place with a largish disk where you
  # want to store MFCC features.
  for x in train dev test; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj data/$x exp/make_mfcc/$x mfcc || exit 1;
    steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x mfcc || exit 1;
    utils/fix_data_dir.sh data/$x || exit 1;
  done
  
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
  # subset the training data for fast startup
  for x in 100 300; do
    utils/subset_data_dir.sh data/train ${x}000 data/train_${x}k
  done
fi

<<<<<<< HEAD
# mono training
if [ $stage -le 1 ]; then
  steps/train_mono.sh --cmd "$train_cmd" --nj $nj \
    data/train_100k data/lang exp/mono || exit 1;
fi


# mono decoding
if [ $stage -le 2 ]; then
  utils/mkgraph.sh data/lang_test exp/mono exp/mono/graph || exit 1;
  steps/decode.sh --cmd "$decode_cmd" --config conf/decode.conf --nj $dev_nj \
    exp/mono/graph data/dev exp/mono/decode_dev
  steps/decode.sh --cmd "$decode_cmd" --config conf/decode.conf --nj $test_nj \
    exp/mono/graph data/test exp/mono/decode_test
fi

# mono alignment
if [ $stage -le 3 ]; then
  steps/align_si.sh --cmd "$train_cmd" --nj $nj \
    data/train_300k data/lang exp/mono exp/mono_ali || exit 1;
fi

# tri1 training
if [ $stage -le 4 ]; then
  steps/train_deltas.sh --cmd "$train_cmd" \
    4000 32000 data/train_300k data/lang exp/mono_ali exp/tri1 || exit 1;
fi

# tri1 decoding
if [ $stage -le 5 ]; then
=======
# mono
if [ $stage -le 2 ]; then
  # training
  steps/train_mono.sh --cmd "$train_cmd" --nj $nj \
    data/train_100k data/lang exp/mono || exit 1;

  # decoding
  utils/mkgraph.sh data/lang_test exp/mono exp/mono/graph || exit 1;
  steps/decode.sh --cmd "$decode_cmd" --config conf/decode.conf --nj ${dev_nj} \
    exp/mono/graph data/dev exp/mono/decode_dev
  steps/decode.sh --cmd "$decode_cmd" --config conf/decode.conf --nj ${test_nj} \
    exp/mono/graph data/test exp/mono/decode_test
  
  # alignment
  steps/align_si.sh --cmd "$train_cmd" --nj $nj \
    data/train_300k data/lang exp/mono exp/mono_ali || exit 1;
fi 

# tri1
if [ $stage -le 3 ]; then
  # training
  steps/train_deltas.sh --cmd "$train_cmd" \
   4000 32000 data/train_300k data/lang exp/mono_ali exp/tri1 || exit 1;
  
  # decoding
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
  utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph || exit 1;
  steps/decode.sh --cmd "$decode_cmd" --config conf/decode.conf --nj ${dev_nj} \
    exp/tri1/graph data/dev exp/tri1/decode_dev
  steps/decode.sh --cmd "$decode_cmd" --config conf/decode.conf --nj ${test_nj} \
    exp/tri1/graph data/test exp/tri1/decode_test
<<<<<<< HEAD
fi

# tri1 alignment
if [ $stage -le 6 ]; then
=======
  
  # alignment
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
  steps/align_si.sh --cmd "$train_cmd" --nj $nj \
    data/train data/lang exp/tri1 exp/tri1_ali || exit 1;
fi

<<<<<<< HEAD
# tri2 training
if [ $stage -le 7 ]; then
  steps/train_deltas.sh --cmd "$train_cmd" \
    7000 56000 data/train data/lang exp/tri1_ali exp/tri2 || exit 1;
fi

# tri2 decoding
if [ $stage -le 8 ]; then
=======
# tri2
if [ $stage -le 4 ]; then
  # training
  steps/train_deltas.sh --cmd "$train_cmd" \
   7000 56000 data/train data/lang exp/tri1_ali exp/tri2 || exit 1;

  # decoding
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
  utils/mkgraph.sh data/lang_test exp/tri2 exp/tri2/graph
  steps/decode.sh --cmd "$decode_cmd" --config conf/decode.conf --nj ${dev_nj} \
    exp/tri2/graph data/dev exp/tri2/decode_dev
  steps/decode.sh --cmd "$decode_cmd" --config conf/decode.conf --nj ${test_nj} \
    exp/tri2/graph data/test exp/tri2/decode_test
<<<<<<< HEAD
fi

# tri2 alignment
if [ $stage -le 9 ]; then
=======
  
  # alignment
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
  steps/align_si.sh --cmd "$train_cmd" --nj $nj \
    data/train data/lang exp/tri2 exp/tri2_ali || exit 1;
fi

<<<<<<< HEAD
# tri3 training [LDA+MLLT]
if [ $stage -le 10 ]; then
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    10000 80000 data/train data/lang exp/tri2_ali exp/tri3 || exit 1;
fi

# tri3 decoding
if [ $stage -le 11 ]; then
=======
# tri3
if [ $stage -le 5 ]; then
  # training [LDA+MLLT]
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
   10000 80000 data/train data/lang exp/tri2_ali exp/tri3 || exit 1;

  # decoding
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
  utils/mkgraph.sh data/lang_test exp/tri3 exp/tri3/graph || exit 1;
  steps/decode.sh --cmd "$decode_cmd" --nj ${dev_nj} --config conf/decode.conf \
    exp/tri3/graph data/dev exp/tri3/decode_dev
  steps/decode.sh --cmd "$decode_cmd" --nj ${test_nj} --config conf/decode.conf \
    exp/tri3/graph data/test exp/tri3/decode_test
<<<<<<< HEAD
fi

# tri3 alignment
if [ $stage -le 12 ]; then
  steps/align_si.sh --cmd "$train_cmd" --nj $nj \
    data/train data/lang exp/tri3 exp/tri3_ali || exit 1;
fi

if [ $stage -le 13 ]; then
=======
  
  # alignment
  steps/align_si.sh --cmd "$train_cmd" --nj $nj \
    data/train data/lang exp/tri3 exp/tri3_ali || exit 1;
  
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
  steps/align_si.sh --cmd "$train_cmd" --nj ${nj} \
    data/dev data/lang exp/tri3 exp/tri3_ali_dev || exit 1;
fi

echo "local/run_gmm.sh succeeded"
exit 0;
<<<<<<< HEAD
=======

>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
