// online2bin/online2-wav-chain-am-compute.cc

// Copyright 2014  Johns Hopkins University (author: Daniel Povey)
//           2014  David Snyder
//           2019  Emotech LTD (Author: Xuechen Liu)

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

#include "feat/wave-reader.h"
#include "online2/online-nnet3-decoding.h"
#include "online2/online-nnet2-feature-pipeline.h"
#include "online2/onlinebin-util.h"
#include "nnet3/nnet-am-decodable-simple.h"
#include "nnet3/decodable-online-looped.h"
#include "nnet3/nnet-utils.h"
#include "util/kaldi-thread.h"
#include "lat/lattice-functions.h"

namespace kaldi {
namespace nnet3 {

// run nnet frame-level forwarding and get the output likelihood estimation,
// optionally performing acoustic scaling.
static void RunNnetDecodableComputation(Matrix<BaseFloat> feats,
  Matrix<BaseFloat> ivectors, DecodableNnetSimpleLoopedInfo info,
  Matrix<BaseFloat> *output) {

  NnetComputer computer_(info.opts.compute_config, info.computation,
                         info.nnet, NULL);
  
  CuMatrix<BaseFloat> cu_feats(feats.NumRows(), feats.NumCols());
  cu_feats.CopyFromMat(feats);
  computer_.AcceptInput("input", &cu_feats);
  if (ivectors.NumCols() != 1) {
    CuMatrix<BaseFloat> cu_ivectors(ivectors.NumRows(), ivectors.NumCols());
    cu_ivectors.CopyFromMat(ivectors);
    computer_.AcceptInput("ivector", &cu_ivectors);
  }
  
  computer_.Run();
  
  CuMatrix<BaseFloat> cu_output;
  computer_.GetOutputDestructive("output", &cu_output);
  if (info.log_priors.Dim() != 0) {
    // subtract log-prior (divide by prior)
    cu_output.AddVecToRows(-1.0, info.log_priors);
  }
  // apply the acoustic scale
  cu_output.Scale(info.opts.acoustic_scale);

  output->Resize(0, 0);
  output->Swap(&cu_output);
}

static void SelectVoicedFrames(Matrix<BaseFloat> feats,
  Vector<BaseFloat> voiced, Matrix<BaseFloat> *voiced_feats) {

  int32 num_vframes = 0;
  for (int32 i = 0; i < voiced.Dim(); i++) {
    if (voiced(i) != 0.0) {num_vframes++;}
  }
  voiced_feats->Resize(num_vframes, feats.NumCols());
  int32 index = 0;
  // here we ignore last frames due to an unexpected numerical 
  // processing bug. Can be investigated later
  for (int32 i = 0; i < feats.NumRows() - 1; i++) {
    if (voiced(i) != 0.0) {
      voiced_feats->Row(index).CopyFromVec(feats.Row(i));
      index++;
    }
  }
  KALDI_ASSERT(index == num_vframes);
}

} // namespace nnet3
} // namespace kaldi



int main(int argc, char *argv[]) {
  try {
    
    using namespace kaldi;
    using namespace kaldi::nnet3;
    typedef kaldi::int32 int32;
    typedef kaldi::int64 int64;

    const char *usage = "";

    ParseOptions po(usage);

    OnlineNnet2FeaturePipelineConfig feature_opts;
    NnetSimpleLoopedComputationOptions decodable_opts;

    BaseFloat chunk_length_secs = 0.05;
    bool apply_log = false;
    bool pad_input = true;
    bool online = true;
    bool do_vad = false;
    po.Register("apply-log", &apply_log, "Apply a log to the result of the computation "
                "before outputting.");
    po.Register("pad-input", &pad_input, "If true, duplicate the first and last frames "
                "of input features as required for temporal context, to prevent #frames "
                "of output being less than those of input.");
    po.Register("chunk-length", &chunk_length_secs,
                "Length of chunk size in seconds, that we process.");
    po.Register("online", &online,
                "You can set this to false to disable online iVector estimation "
                "and have all the data for each utterance used, even at "
                "utterance start.  This is useful where you just want the best "
                "results and don't care about online operation.  Setting this to "
                "false has the same effect as setting "
                "--use-most-recent-ivector=true and --greedy-ivector-extractor=true "
                "in the file given to --ivector-extraction-config, and "
                "--chunk-length=-1.");
    po.Register("do-vad", &do_vad,
                "apply vad transformation on features before processing or not. "
                "By setting this to false, one can apply any vector scp file and "
                "it won't get read");
    
    feature_opts.Register(&po);
    decodable_opts.Register(&po);
    po.Read(argc, argv);
    if (po.NumArgs() != 5) {
      po.PrintUsage();
      return 1;
    }

    std::string nnet3_rxfilename = po.GetArg(1),
      spk2utt_rspecifier = po.GetArg(2),
      wav_rspecifier = po.GetArg(3),
      vad_rspecifier = po.GetArg(4),
      loglikes_wspecifier = po.GetArg(5);
    
    OnlineNnet2FeaturePipelineInfo feature_info(feature_opts);
    if (!online) {
      feature_info.ivector_extractor_info.use_most_recent_ivector = true;
      feature_info.ivector_extractor_info.greedy_ivector_extractor = true;
      chunk_length_secs = -1.0;
    }

    TransitionModel trans_model;
    nnet3::AmNnetSimple am_nnet;
    {
      bool binary;
      Input ki(nnet3_rxfilename, &binary);
      trans_model.Read(ki.Stream(), binary);
      am_nnet.Read(ki.Stream(), binary);
      SetBatchnormTestMode(true, &(am_nnet.GetNnet()));
      SetDropoutTestMode(true, &(am_nnet.GetNnet()));
      nnet3::CollapseModel(nnet3::CollapseModelConfig(), &(am_nnet.GetNnet()));
    }

    // this object contains precomputed stuff that is used by all decodable
    // objects.  It takes a pointer to am_nnet because if it has iVectors it has
    // to modify the nnet to accept iVectors at intervals.
    DecodableNnetSimpleLoopedInfo decodable_info(decodable_opts, &am_nnet);

    int32 num_done = 0, num_err = 0;
    int64 num_frames = 0;
    SequentialTokenVectorReader spk2utt_reader(spk2utt_rspecifier);
    RandomAccessTableReader<WaveHolder> wav_reader(wav_rspecifier);
    RandomAccessBaseFloatVectorReader vad_reader(vad_rspecifier);
    BaseFloatMatrixWriter writer(loglikes_wspecifier);

    // iterate over spk2utt file (by design?)
    for (; !spk2utt_reader.Done(); spk2utt_reader.Next()) {
      std::string spk = spk2utt_reader.Key();
      const std::vector<std::string> &uttlist = spk2utt_reader.Value();
      OnlineIvectorExtractorAdaptationState adaptation_state(
          feature_info.ivector_extractor_info);
      
      // iterate over utterances for each speaker
      for (size_t i = 0; i < uttlist.size(); i++) {
        std::string utt = uttlist[i];
        if (!wav_reader.HasKey(utt)) {
          KALDI_WARN << "Did not find audio for utterance " << utt;
          continue;
        }
        const WaveData &wave_data = wav_reader.Value(utt);
        // get the data for channel zero (if the signal is not mono, we only
        // take the first channel).
        SubVector<BaseFloat> data(wave_data.Data(), 0);

        OnlineNnet2FeaturePipeline feature_pipeline(feature_info);
        feature_pipeline.SetAdaptationState(adaptation_state);

        BaseFloat samp_freq = wave_data.SampFreq();
        int32 chunk_length;
        if (chunk_length_secs > 0) {
          chunk_length = int32(samp_freq * chunk_length_secs);
          if (chunk_length == 0) chunk_length = 1;
        } else {
          chunk_length = std::numeric_limits<int32>::max();
        }
        
        int32 samp_offset = 0;
        while (samp_offset < data.Dim()) {
          int32 samp_remaining = data.Dim() - samp_offset;
          int32 num_samp = chunk_length < samp_remaining ? chunk_length
                                                         : samp_remaining;
          
          SubVector<BaseFloat> wave_part(data, samp_offset, num_samp);
          feature_pipeline.AcceptWaveform(samp_freq, wave_part);
          
          samp_offset += num_samp;
          if (samp_offset == data.Dim()) {
            // no more input. flush out last frames
            feature_pipeline.InputFinished();
          }
        }
        
        OnlineFeatureInterface *input_features = feature_pipeline.InputFeature();
        int32 feats_num_frames = input_features->NumFramesReady(),
              feats_dim = input_features->Dim();

        Matrix<BaseFloat> feats(feats_num_frames, feats_dim);
        for (int32 i = 0; i < feats_num_frames; i++) {
          SubVector<BaseFloat> frame_vector(feats, i);
          input_features->GetFrame(i, &frame_vector);
        }

        // do VAD
        if (do_vad) {
          if (!vad_reader.HasKey(utt)) {
             KALDI_WARN << "No VAD input found for utterance " << utt;
             num_err++;
             continue;
          }
          const Vector<BaseFloat> &voiced = vad_reader.Value(utt);
          // KALDI_ASSERT(voiced.Dim() == feats.NumRows() - 1);
          KALDI_LOG << "VAD dimension for " << utt << " is: " << voiced.Dim()
                    << " while number of feat frames is: " << feats.NumRows();
          Matrix<BaseFloat> voiced_feats;
          SelectVoicedFrames(feats, voiced, &voiced_feats);
          KALDI_LOG << "original number of frames in feats is " << feats.NumRows()
                    << " while after processing, numner of voiced frames remain "
                    << " is: " << voiced_feats.NumRows();
          feats.Resize(voiced_feats.NumRows(), voiced_feats.NumCols());
          feats.CopyFromMat(voiced_feats);
          feats_num_frames = feats.NumRows();
          KALDI_LOG << "number of feats frames after: " << feats.NumRows(); 
        }

        // fetch ivector matrix, which is simply copy of rows from ivectors
        Matrix<BaseFloat> ivectors(1, 1);
        if (decodable_info.has_ivectors) {
          // check if ivectors are set to be NULL in feature pipeline
          // and computation request
          OnlineFeatureInterface *ivector_features = feature_pipeline.IvectorFeature();
          KALDI_ASSERT(ivector_features != NULL);
          KALDI_ASSERT(decodable_info.request1.inputs.size() == 2);

          int32 num_ivectors = decodable_info.request1.inputs[1].indexes.size(),
                ivec_dim = ivector_features->Dim();
          // Matrix<BaseFloat> ivectors(ivec_num_frames, ivec_dim);
          ivectors.Resize(num_ivectors, ivec_dim);

          Vector<BaseFloat> ivector(ivector_features->Dim());
          int32 most_recent_input_frame = feats_num_frames - 1,
                num_ivector_frames_ready = ivector_features->NumFramesReady();
          if (num_ivector_frames_ready > 0) {
            int32 ivector_frame_to_use = std::min<int32>(
              most_recent_input_frame, num_ivector_frames_ready - 1);
            ivector_features->GetFrame(ivector_frame_to_use, &ivector);
          }
          ivectors.CopyRowsFromVec(ivector);
        }     
        
        // get number of chunks to be decoded for this utterance
        int32 total_num_chunks = feats_num_frames / decodable_opts.frames_per_chunk;

        // initialize a big matrix for storing output likelihoods
        Matrix<BaseFloat> out_frames(total_num_chunks * (decodable_opts.frames_per_chunk+1),
                                     decodable_info.output_dim);

        // different from what's defined in decodable-simple-looped.cc, we move w.r.t the feats
        // chunk-by-chunk, starting from index 0. For example, if we set left and right context
        // to be 40 while frames_per_chunk being 20, we start from (-40, 20+40) and increase
        // both values by 20 for each chunk.
        int32 num_chunks_computed = 0;
        while (num_chunks_computed < total_num_chunks) {
          // int32 begin_input_frame, end_input_frame;
          // if (num_chunks_computed == 0) {
          //   begin_input_frame = -decodable_info.frames_left_context;
          //   end_input_frame = decodable_info.frames_per_chunk +
          //     decodable_info.frames_right_context;
          // } else {
          //   begin_input_frame = num_chunks_computed * decodable_info.frames_per_chunk +
          //     decodable_info.frames_right_context;
          //   end_input_frame = begin_input_frame + decodable_info.frames_per_chunk;
          // }
          int32 begin_input_frame = -decodable_info.frames_left_context,
                end_input_frame = decodable_info.frames_per_chunk +
                  decodable_info.frames_right_context;
          Matrix<BaseFloat> this_feats(end_input_frame - begin_input_frame,
                                       feats.NumCols(), kUndefined);
          if (begin_input_frame >= 0 && end_input_frame <= feats.NumRows()) {
            SubMatrix<BaseFloat> src_feats(feats, begin_input_frame,
              end_input_frame - begin_input_frame, 0, feats.NumCols());
            this_feats.CopyFromMat(src_feats);
          } else {
            Matrix<BaseFloat> src_feats(end_input_frame - begin_input_frame,
              feats.NumCols());
            for (int32 r = begin_input_frame; r < end_input_frame; r++) {
              int32 input_frame = r;
              if (input_frame < 0 ) input_frame = 0;
              if (input_frame >= feats.NumRows()) input_frame = feats.NumRows() - 1;
              src_feats.Row(r - begin_input_frame).CopyFromVec(feats.Row(input_frame));
            }
            this_feats.CopyFromMat(src_feats);
          }

          Matrix<BaseFloat> this_output;
          RunNnetDecodableComputation(this_feats, ivectors, decodable_info, &this_output);

          for (int32 i = 1; i < this_output.NumRows(); i++) {
            SubVector<BaseFloat> this_output_row(out_frames, i * (num_chunks_computed + 1) - 1);
            this_output_row.CopyRowFromMat(this_output, i);
          }

          num_chunks_computed++;
          begin_input_frame += decodable_info.frames_per_chunk;
          end_input_frame += decodable_info.frames_per_chunk;
        }
        // In an application you might avoid updating the adaptation state if
        // you felt the utterance had low confidence.  See lat/confidence.h
        feature_pipeline.GetAdaptationState(&adaptation_state);

        // write output to target file
        writer.Write(utt, out_frames);
        KALDI_LOG << "Processed data for utterance " << utt;
        num_done++;
        num_frames += feats_num_frames;
      }
    }
    KALDI_LOG << "Processed " << num_done << " utteranes. "
              << num_frames << " frames of input were processed. ";

    return (num_done != 0 ? 0 : 1);
  } catch (const std::exception& e) {
    std::cerr << e.what() <<'\n';
    return -1;
}

}
