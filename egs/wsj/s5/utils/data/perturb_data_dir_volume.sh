#!/bin/bash

# Copyright 2016  Johns Hopkins University (author: Daniel Povey)
# Apache 2.0

# This script operates on a data directory, such as in data/train/, and modifies
# the wav.scp to perturb the volume (typically useful for training data when
# using systems that don't have cepstral mean normalization).

reco2vol=   # A file with the format <reco-id> <volume> that specifies the 
            # factor by which the volume of the recording must be scaled.
            # If not provided, then the volume will be chosen randomly to 
            # be between --scale-low and --scale-high.
write_reco2vol=     # File to write volume-scales applied to the recordings.
                    # Can be passed to --reco2vol to use the same volumes for 
                    # another data directory. 
                    # e.g. the unperturbed data directory.

perturb_mode=scale  # scale or absvol

# scale perturbation
# scaling factors between [scale_low, scale_high] are applied to wavs
scale_low=0.125
scale_high=2

# absvol perturbation
# absolute volume of output wavs will be bounded in [abs_low, abs_high]
abs_low=800
abs_high=25000

local_seed=1234

. utils/parse_options.sh

if [ $# != 1 ]; then
  echo "Usage: $0 [options] <datadir>"
  echo "e.g.:"
  echo " $0 data/train"
  echo "Options:"
  echo "  --perturb-mode [absvol|scale] # perturbation via scale(default) or absolute-volume controlling"
  exit 1
fi

export LC_ALL=C

data=$1

if [ ! -f $data/wav.scp ]; then
  echo "$0: Expected $data/wav.scp to exist"
  exit 1
fi

# Check if volume perturbation is already this. We assume that the volume
# perturbation is done if it has a line 'sox --vol' applied on the whole 
# recording.
# e.g. 
# foo-1 cat foo.wav | sox --vol 1.6 -t wav - -t wav - |    # volume perturbation done
# bar-1 sox --vol 1.2 bar.wav -t wav - |                   # volume perturbation done
# foo-2 wav-reverberate --additive-signals="sox --vol=0.1 noise1.wav -t wav -|" foo.wav |   # volume perturbation not done
volume_perturb_done=`head -n100 $data/wav.scp | python -c "
import sys, re
for line in sys.stdin.readlines():
  if len(line.strip()) == 0:
    continue
  # Handle three cases of rxfilenames appropriately; 'input piped command', 'file offset' and 'filename'
  parts = line.strip().split()
  if line.strip()[-1] == '|':
    if re.search('sox --vol', ' '.join(parts[-11:])):
      print 'true'
      sys.exit(0)
  elif re.search(':[0-9]+$', line.strip()) is not None:
    continue
  else:
    if ' '.join(parts[1:3]) == 'sox --vol':
      print 'true'
      sys.exit(0)
print 'false'
"` || exit 1

if $volume_perturb_done; then
  echo "$0: It looks like the data was already volume perturbed.  Not doing anything."
  exit 0
fi

if [ $perturb_mode == absvol ]; then
  reco2vol=$data/reco2vol
  wav-to-volume scp:$data/wav.scp ark,t:- | awk -v awk_seed=${local_seed}  \
    -v awk_low=${abs_low} -v awk_high=${abs_high}                          \
    -v awk_out=${reco2vol}                                                 \
    'BEGIN{ srand(awk_seed); }                                             \
    {                                                                      \
      dst_vol=int(rand() * (awk_high - awk_low) + awk_low);                \
      scale=(dst_vol * 1.0) / ($2 * 1.0);                                  \
      print $1,scale > awk_out;                                            \
    }'
fi

cat $data/wav.scp | utils/data/internal/perturb_volume.py \
  --reco2vol=$reco2vol ${write_reco2vol:+--write-reco2vol=$write_reco2vol} \
  --scale-low=$scale_low --scale-high=$scale_high > \
  $data/wav.scp_scaled || exit 1;

len1=$(cat $data/wav.scp | wc -l)
len2=$(cat $data/wav.scp_scaled | wc -l)
if [ "$len1" != "$len2" ]; then
  echo "$0: error detected: number of lines changed $len1 vs $len2";
  exit 1
fi

mv $data/wav.scp_scaled $data/wav.scp

if [ -f $data/feats.scp ]; then
  echo "$0: $data/feats.scp exists; moving it to $data/.backup/ as it wouldn't be valid any more."
  mkdir -p $data/.backup/
  mv $data/feats.scp $data/.backup/
fi

echo "$0: added volume perturbation to the data in $data"
exit 0

