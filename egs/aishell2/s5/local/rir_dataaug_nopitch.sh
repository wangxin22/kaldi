#!/bin/bash
# Augment data using RIR noise

. ./cmd.sh
. ./path.sh
set -euxo pipefail

# general options
affix=nopitch_hires
stage=0
frame_shift=0.01

# directory options
nj=15

. ./utils/parse_options.sh

datadir=$1

# download rir directory
if [ $stage -le 0 ] && [ ! -d "RIRS_NOISES" ]; then
  # Download the package that includes the real RIRs, simulated RIRs, isotropic noises and point-source noises
  wget --no-check-certificate http://www.openslr.org/resources/28/rirs_noises.zip && unzip rirs_noises.zip
fi

# extract feature but with utt2num_frames
if [ $stage -le 1 ]; then
  if [ ! -f $datadir/utt2num_frames ]; then
   #steps/make_mfcc.sh --write-utt2num-frames true --mfcc-config conf/mfcc_hires.conf --nj $nj \
   #   $datadir exp/train_for_rir_pollution_${affix} exp/mfcc_for_rir_pollution_${affix} || exit 1;
   [ ! -f $datadir/utt2num_frames ] && utils/data/get_utt2num_frames.sh $datadir || exit 1;
   utils/fix_data_dir.sh $datadir || exit 1;
  else
    echo "utt2num_frames already exists. We won't re-compute it." 
 fi
fi

# augmentation with RIR
if [ $stage -le 2 ]; then
  awk -v frame_shift=$frame_shift '{print $1, $2*frame_shift;}' ${datadir}/utt2num_frames > ${datadir}/reco2dur
  # need to prepare reco2dur file (column 1 : utt_id; column 2 : duration in sec)
  rvb_opts=()
  rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/smallroom/rir_list")
  rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/mediumroom/rir_list")

  # Make a reverberated version of the SWBD+SRE list.  Note that we don't add any
  # additive noise here.
  # [ -f steps/data/reverberate_data_dir_notext.py ] || \
  #   cp /efs/mlteam/raymond/kaldi/egs/ami-lbi-emo/s5d-si-rvms/steps/data/reverberate_data_dir_notext.py \
  #   steps/data/
  python steps/data/reverberate_data_dir.py \
    "${rvb_opts[@]}" \
    --speech-rvb-probability 1 \
    --pointsource-noise-addition-probability 0 \
    --isotropic-noise-addition-probability 0 \
    --num-replications 1 \
    --source-sampling-rate 16000 \
    $datadir ${datadir}_rev
  utils/fix_data_dir.sh ${datadir}_rev

  #cp ${datadir}/vad.scp ${datadir}_rev/
  utils/copy_data_dir.sh --utt-suffix "-reverb" \
    ${datadir}_rev ${datadir}_rev.new
  rm -rf ${datadir}_rev
  mv ${datadir}_rev.new ${datadir}_rev
fi

if [ $stage -le 5 ]; then
  # re-extract features and perform combination
  steps/make_mfcc.sh --mfcc-config conf/mfcc_hires.conf --cmd "$train_cmd" --nj $nj \
    ${datadir}_rev exp/train_hires_rev_${affix} exp/mfcc_train_hires_rev_${affix} || exit 1;
  utils/combine_data.sh ${datadir}_clean_plus_rir ${datadir} ${datadir}_rev
  utils/fix_data_dir.sh ${datadir}_clean_plus_rir
fi

# hacky step: generate utt2dur file manually
if [ $stage -le 6 ]; then
  python local/utt2dur_deploy.py --prefix "I" --src-utt2dur ${datadir}/utt2dur \
    --tar-utt2spk ${datadir}_clean_plus_rir/utt2spk \
    --tar-utt2dur ${datadir}_clean_plus_rir/utt2dur || exit 1;
fi
