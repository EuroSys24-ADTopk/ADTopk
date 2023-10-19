#!/usr/bin/env bash

# Copyright (c) 2019-2020 NVIDIA CORPORATION. All rights reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# SQUAD_DIR='/home/mzq/mingzq/workspaces/project/grace/examples/torch/nlp/bert/dataset/squad/'
# BERT_BASE_DIR='/home/mzq/mingzq/workspaces/project/grace/examples/torch/nlp/bert/pre-model/bert-base-uncased/uncased_L-12_H-768_A-12/'

echo "Container nvidia build = " $NVIDIA_BUILD_ID

# export DIR_Model="/home/mzq/mingzq/workspaces/project/grace/examples/torch/nlp/bert/pre-model/bert-large-uncased/uncased_L-24_H-1024_A-16"
export DIR_Model="/data/dataset/nlp/bert/pre-model/bert-base-uncased/uncased_L-12_H-768_A-12"
export DIR_DataSet="/data/dataset/nlp/bert"


compressor=${1:-"actopk"}
init_checkpoint=${2:-"$DIR_Model/bert_base_wiki.pt"}
epochs=${3:-"2.0"}
batch_size=${4:-"4"}
learning_rate=${5:-"3e-5"}
warmup_proportion=${6:-"0.1"}
precision=${7:-"fp16"}
num_gpu=${8:-"8"}
seed=${9:-"1"}
squad_dir=${10:-"$DIR_DataSet/squad"}
vocab_file=${11:-"$DIR_Model/vocab.txt"}
OUT_DIR=${12:-"./squad_base/output"}
mode=${13:-"train eval"}
CONFIG_FILE=${14:-"$DIR_Model/bert_config.json"}
max_steps=${15:-"-1"}

# init_checkpoint=${1:-"$DIR_Model/bezrt_base_wiki.pt"}
# epochs=${2:-"2.0"}
# batch_size=${3:-"4"}
# learning_rate=${4:-"3e-5"}
# warmup_proportion=${5:-"0.1"}
# precision=${6:-"fp16"}
# num_gpu=${7:-"8"}
# seed=${8:-"1"}
# squad_dir=${9:-"$DIR_DataSet/squad"}
# vocab_file=${10:-"$DIR_Model/vocab.txt"}
# OUT_DIR=${11:-"./squad_base/output"}
# mode=${12:-"train eval"}
# CONFIG_FILE=${13:-"$DIR_Model/bert_config.json"}
# max_steps=${14:-"-1"}




echo "out dir is $OUT_DIR"
mkdir -p $OUT_DIR
if [ ! -d "$OUT_DIR" ]; then
  echo "ERROR: non existing $OUT_DIR"
  exit 1
fi

use_fp16=""
if [ "$precision" = "fp16" ] ; then
  echo "fp16 activated!"
  use_fp16=" --fp16 "
fi

if [ "$num_gpu" = "1" ] ; then
  export CUDA_VISIBLE_DEVICES=0
  mpi_command=""
else
  unset CUDA_VISIBLE_DEVICES
  # mpi_command=" -m torch.distributed.launch --nproc_per_node=$num_gpu"
  # mpi_command=" -m torch.distributed.launch --nproc_per_node=$num_gpu"
fi



CMD=" horovodrun -np 2 -H n15:1,n16:1 python ./pytorch/train_bert_squad.py "
CMD+="--init_checkpoint=$init_checkpoint "
if [ "$mode" = "train" ] ; then
  CMD+="--do_train "
  CMD+="--train_file=$squad_dir/train-v1.1.json "
  CMD+="--train_batch_size=$batch_size "
elif [ "$mode" = "eval" ] ; then
  CMD+="--do_predict "
  CMD+="--predict_file=$squad_dir/dev-v1.1.json "
  CMD+="--predict_batch_size=$batch_size "
  CMD+="--eval_script=$squad_dir/evaluate-v1.1.py "
  CMD+="--do_eval "
elif [ "$mode" = "prediction" ] ; then
  CMD+="--do_predict "
  CMD+="--predict_file=$squad_dir/dev-v1.1.json "
  CMD+="--predict_batch_size=$batch_size "
else
  CMD+=" --do_train "
  CMD+=" --train_file=$squad_dir/train-v1.1.json "
  CMD+=" --train_batch_size=$batch_size "
  CMD+="--do_predict "
  CMD+="--predict_file=$squad_dir/dev-v1.1.json "
  CMD+="--predict_batch_size=$batch_size "
  CMD+="--eval_script=$squad_dir/evaluate-v1.1.py "
  CMD+="--do_eval "
  CMD+="--compressor=$compressor "
fi

CMD+=" --do_lower_case "
# CMD+=" --bert_model=bert-large-uncased "
CMD+=" --bert_model=bert-base-uncased "
CMD+=" --learning_rate=$learning_rate "
CMD+=" --warmup_proportion=$warmup_proportion"
CMD+=" --seed=$seed "
CMD+=" --num_train_epochs=$epochs "
CMD+=" --max_seq_length=384 "
CMD+=" --doc_stride=128 "
CMD+=" --output_dir=$OUT_DIR "
CMD+=" --vocab_file=$vocab_file "
CMD+=" --config_file=$CONFIG_FILE "
CMD+=" --max_steps=$max_steps "
# CMD+=" $use_fp16"

LOGFILE=$OUT_DIR/logfile.txt
echo "$CMD |& tee $LOGFILE"
time $CMD |& tee $LOGFILE
