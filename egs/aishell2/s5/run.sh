#!/bin/bash

# Copyright 2018 AIShell-Foundation(Authors:Jiayu DU, Xingyu NA, Bengu WU, Hao ZHENG)
#           2018 Beijing Shell Shell Tech. Co. Ltd. (Author: Hui BU)
# Apache 2.0

# AISHELL-2 provides:
#  * a Mandarin speech corpus (~1000hrs), free for non-commercial research/education use
#  * an industrial recipe setup for large scale Mandarin ASR system
# For more details, read $KALDI_ROOT/egs/aishell2/README.txt

# modify this to your AISHELL-2 corpus data path
# e.g /disk10/data/AISHELL-2/iOS/data
corpus=

nj=20
stage=1

. ./cmd.sh
. ./path.sh

# we should probably move jieba(for word segmentation) into 
# Kaldi's "tools" dir with Dan's approval
# before you run the entire recipe, run the following command
# local/install_jieba.sh local/jieba

# prepare data, lexicon, and lang etc
if [ $stage -le 1 ]; then
	local/prepare_all.sh $corpus || exit 1;
fi

# GMM
if [ $stage -le 2 ]; then
	local/run_gmm.sh --nj $nj
fi

# xent
if [ $stage -le 3 ]; then
	local/nnet3/run_tdnn.sh --nj $nj
fi

# chain
if [ $stage -le 4 ]; then
	local/chain/run_tdnn.sh --nj $nj
fi

local/show_results.sh

exit 0;
