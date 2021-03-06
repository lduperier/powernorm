#!/usr/bin/env bash

CODE_PATH=.
cd $CODE_PATH
export PYTHONPATH=$CODE_PATH:$PYTHONPATH
ENC_NORM=$1
ENC_NORM_ff=$2
DEC_NORM=$3
DEC_NORM_ff=$4
suffix=$5

model=transformer
PROBLEM=wmt14_en_de
ARCH=transformer_wmt_en_de_big_t2t
DATA_PATH=data-bin/wmt14_en_de_joined_dict/
OUTPUT_PATH=log/$PROBLEM/$ARCH\_$ENC_NORM\_$ENC_NORM_ff\_$DEC_NORM\_$DEC_NORM_ff\_warm$suffix
NUM=10
mkdir -p $OUTPUT_PATH

# Example usage with 8 * 4 = 32 P40 GPUs. Change the --max-tokens and --update-freq to match your hardware settings.

# MASTER_HOST="0.0.0.0" # Replace it with your master's IP

python distributed_train.py $DATA_PATH \
  --distributed-init-method tcp://$MASTER_HOST:23456 \
  --distributed-world-size $OMPI_COMM_WORLD_SIZE \
  --distributed-rank $OMPI_COMM_WORLD_RANK \
  --device-id $OMPI_COMM_WORLD_LOCAL_RANK \
  --distributed-backend nccl \
  --seed 1 \
  --arch $ARCH --share-all-embeddings \
  --optimizer adam --adam-betas '(0.9, 0.98)' --clip-norm 0.0 \
  --lr-scheduler inverse_sqrt --warmup-init-lr 1e-07 --warmup-updates 8000 \
  --lr 0.003 --min-lr 1e-09 \
  --criterion label_smoothed_cross_entropy --label-smoothing 0.1 --weight-decay 0.0 \
  --max-tokens 4096 --save-dir $OUTPUT_PATH \
  --update-freq 1 --no-progress-bar --log-interval 50 \
  --ddp-backend c10d \
  --save-interval-updates 10000 --keep-interval-updates 20 \
  --encoder-norm-self $ENC_NORM --decoder-norm-self $DEC_NORM \
  --encoder-norm-ff $ENC_NORM_ff --decoder-norm-ff $DEC_NORM_ff --keep-last-epochs $NUM --early-stop $NUM \
| tee -a $OUTPUT_PATH/train_log.txt

python scripts/average_checkpoints.py --inputs $OUTPUT_PATH --num-epoch-checkpoints $NUM --output $OUTPUT_PATH/averaged_model.pt
