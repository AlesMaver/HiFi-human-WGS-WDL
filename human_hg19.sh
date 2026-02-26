#!/usr/bin/env bash
set -eu

NAME="human_hg19"
FASTA_URL="https://hgdownload.cse.ucsc.edu/goldenPath/hg19/bigZips/hg19.fa.gz"

echo "Downloading reference fasta, decompressing as ${NAME}.fasta, and converting all non-AGCT bases to N"
wget -qO - "$FASTA_URL" \
    | gunzip -c \
    | sed '/^[^>]/ y/BDEFHIJKLMOPQRSUVWXYZbdefhijklmopqrsuvwxyz/NNNNNNNNNNNNNNNNNNNNNnnnnnnnnnnnnnnnnnnnnn/' \
    > "${NAME}.fasta"
echo "Indexing ${NAME}.fasta"
samtools faidx "${NAME}.fasta"
echo "Creating sequence dictionary"
samtools dict "${NAME}.fasta" > "${NAME}.dict"
md5sum "${NAME}.fasta" > "${NAME}.fasta.md5"
# b5a9506794ce4fa471663380bdbb4a14  human_hs37d5.fasta