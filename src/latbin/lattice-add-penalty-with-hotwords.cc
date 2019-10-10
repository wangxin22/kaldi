// latbin/lattice-add-penalty-with-hotwords.cc

// Copyright 2013     Bagher BabaAli
//                    Johns Hopkins University (Author: Daniel Povey)
//           2019     Emotech LTD (Author: Xuechen Liu)

// See ../../COPYING for clarification regarding multiple authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
// WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
// MERCHANTABLITY OR NON-INFRINGEMENT.
// See the Apache 2 License for the specific language governing permissions and
// limitations under the License.

// This binary is for adding word insertion penalty except for selected hotwords,
// which, when passed to the binary, shall be in terms of transition ids. It has
// two versions for experimental purposes: no penalty and weak penalty, for hotwords.

#include "lat/lattice-functions.h"

namespace kaldi {

typedef CompactLatticeArc Arc;
typedef kaldi::int32 int32;
typedef kaldi::int64 int64;

// this is referenced from AddWordInsPenToCompactLattice in 
// lat/lat-functions.cc.
void AddWordInsPenWithHotwords(BaseFloat word_ins_penalty,
  std::vector<kaldi::int64> hotword_ids,
  CompactLattice *clat) {

  int64 num_states = clat->NumStates();

  for (int32 state = 0; state < num_states; state++) {
    for (fst::MutableArcIterator<CompactLattice> aiter(clat, state);
        !aiter.Done(); aiter.Next()) {
      
      Arc arc(aiter.Value());

      // different from original ver, if the olabel id is in hotword
      // trans id list, we continue
      if (arc.ilabel != 0) {
        if (std::find(hotword_ids.begin(), hotword_ids.end(), arc.olabel) != hotword_ids.end()) {
          // we have hotwords
          KALDI_LOG << "we won't give penalty for " << arc.olabel;
          continue;
        } else {
          LatticeWeight weight = arc.weight.Weight();
          // add word insertion penalty
          weight.SetValue1(weight.Value1() + word_ins_penalty);
          arc.weight.SetWeight(weight);
          aiter.SetValue(arc);
        } 
      } // end if-logic over hotwords

    } // end iterating over arcs
  } // end iterating over states

}

// TODO
void AddWordInsPenWithHotwordsSpecial(BaseFloat word_ins_penalty,
  BaseFloat hotword_ins_penalty, std::vector<kaldi::int64> hotword_ids,
  CompactLattice *clat) {
    
  int64 num_states = clat->NumStates();

  for (int32 state = 0; state < num_states; state++) {
    for (fst::MutableArcIterator<CompactLattice> aiter(clat, state);
        !aiter.Done(); aiter.Next()) {
      
      Arc arc(aiter.Value());

      // different from original ver, if the olabel id is in hotword
      // trans id list, we continue
      if (arc.ilabel != 0) {
        LatticeWeight weight = arc.weight.Weight();
        if (std::find(hotword_ids.begin(), hotword_ids.end(), arc.olabel) != hotword_ids.end()) {
          // add hotword insertion penalty
          KALDI_LOG << "we give penalty " << hotword_ins_penalty
                    << " specially for " << arc.olabel;
          
          weight.SetValue1(weight.Value1() + hotword_ins_penalty);
        } else {
          // add regular word insertion penalty
          weight.SetValue1(weight.Value1() + word_ins_penalty);
        }
        arc.weight.SetWeight(weight);
        aiter.SetValue(arc);
      } // end if-logic over hotwords

    } // end iterating over arcs
  } // end iterating over states  
}

void word_ids_to_vector(std::string hotword_file_name,
  std::vector<kaldi::int64> *hotword_trans_ids ) {
    std::ifstream is(hotword_file_name);
    std::string line;
    while(std::getline(is, line)) {
      hotword_trans_ids->push_back(std::stoi(line));
    }
}

} // namespace kaldi


int main(int argc, char *argv[]) {
  try {
    using namespace kaldi;
    typedef kaldi::int64 int64;
    
    const char *usage =
        "Add word insertion penalty to the lattice with hotwords less or not penalized.\n"
        "Note: penalties are negative log-probs, base e, and are added to the\n"
        "'language model' part of the cost.\n"
        "\n"
        "Usage: lattice-add-penalty [options] <lattice-rspecifier> <lattice-wspecifier>\n"
        " e.g.: lattice-add-penalty --word-ins-penalty=1.0 ark:- ark:-\n";
      
    ParseOptions po(usage);
    
    BaseFloat word_ins_penalty = 0.0, hotword_ins_penalty = 0.0;
    std::string hotword_ids_file = "";

    po.Register("word-ins-penalty", &word_ins_penalty, "Word insertion penalty");
    po.Register("horword-ins-penalty", &hotword_ins_penalty, "Insertion Penalty for hotwords");
    po.Register("hotword-ids", &hotword_ids_file, "transition id file for selected hotwords");

    po.Read(argc, argv);

    if (po.NumArgs() != 2) {
      po.PrintUsage();
      exit(1);
    }

    std::string lats_rspecifier = po.GetArg(1),
        lats_wspecifier = po.GetArg(2);
    
    SequentialCompactLatticeReader clat_reader(lats_rspecifier);
    CompactLatticeWriter clat_writer(lats_wspecifier); // write as compact.

    std::vector<int64> hotword_ids;
    word_ids_to_vector(hotword_ids_file, &hotword_ids);    

    int64 n_done = 0;
    for (; !clat_reader.Done(); clat_reader.Next()) {
      CompactLattice clat(clat_reader.Value());
      if (hotword_ins_penalty != 0.0) {
        AddWordInsPenWithHotwords(word_ins_penalty, hotword_ids, &clat);
      } else {
        // we need to make sure that hotword insertion penalty input is 
        // less than regular one (in some sense, much less...)
        KALDI_ASSERT(hotword_ins_penalty <= word_ins_penalty);
        AddWordInsPenWithHotwordsSpecial(word_ins_penalty, hotword_ins_penalty,
                                         hotword_ids, &clat);
      }
      clat_writer.Write(clat_reader.Key(), clat);
      n_done++;
    }
    KALDI_LOG << "Done adding word insertion penalty with hotwords to " << n_done << " lattices.";
    return (n_done != 0 ? 0 : 1);

  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}

