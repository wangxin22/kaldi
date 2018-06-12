#!/usr/bin/python3
# Copyright 2018 Emotech LTD (Author: Xuechen LIU)
# Apache 2.0

# this file deploy the utt2dur file from src directory to the
# RIR+musan augmented directory, where the utterance with prefix
# same as original utterance.

import argparse
import os
import sys


if __name__ == "__main__":
    # read options
    argparser = argparse.ArgumentParser()
    argparser.add_argument('--src-utt2dur', action='store')
    argparser.add_argument('--tar-utt2dur', action='store')
    argparser.add_argument('--tar-utt2spk', action='store')
    # for prefix, since it's for aishell, we set BAC as default
    argparser.add_argument('--prefix', action="store", default="BAC")
    args = argparser.parse_args()

    # read utt2dur of source file
    src_utt2dur_list = {}
    with open(args.src_utt2dur, 'r') as src:
        for line in src:
            utt_dur = line.split()
            src_utt2dur_list[utt_dur[0]] = utt_dur[1]
    
    # read utt list of target file, with augmentation marking
    tar_utt_list = []
    with open(args.tar_utt2spk, 'r') as tar_src:
        for line in tar_src:
            utt_spk = line.split()
            tar_utt_list.append(utt_spk[0])
    
    # perform augmentation
    with open(args.tar_utt2dur, 'w') as tar_tar:
        for item in tar_utt_list:
            utt_mark = [s for s in item.split("-") if args.prefix in s][0]
            tar_tar.write(item + " " + src_utt2dur_list[utt_mark] + "\n")
    
