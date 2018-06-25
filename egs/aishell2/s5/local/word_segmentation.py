#!/usr/bin/env python
# encoding=utf-8
# Copyright 2018 AIShell-Foundation(Authors:Jiayu DU, Xingyu NA, Bengu WU, Hao ZHENG)
#           2018 Beijing Shell Shell Tech. Co. Ltd. (Author: Hui BU)
# Apache 2.0

import sys
import jieba
reload(sys)
sys.setdefaultencoding('utf-8')

if len(sys.argv) < 3:
<<<<<<< HEAD
	sys.stderr.write("word_segmentation.py <vocab> <trans> > <word-segmented-trans>\n")
	exit(1)
=======
  sys.stderr.write("word_segmentation.py <vocab> <trans> > <word-segmented-trans>\n")
  exit(1)
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e

vocab_file=sys.argv[1]
trans_file=sys.argv[2]

jieba.set_dictionary(vocab_file)
for line in open(trans_file):
<<<<<<< HEAD
	key,trans = line.strip().split('\t',1)
	words = jieba.cut(trans)
	new_line = key + '\t' + " ".join(words)
	print(new_line)
=======
  key,trans = line.strip().split('\t',1)
  words = jieba.cut(trans)
  new_line = key + '\t' + " ".join(words)
  print(new_line)
>>>>>>> 60141df48253b86258c8f3afe5b1468aa3b2b59e
