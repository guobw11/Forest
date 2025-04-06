#!/bin/bash
#title: ITS processing with Qiime2(DADA2)
#The sequence data is a set of Novaseq-sequenced single-end fastq files. 
#primer: ITS2:ITS4- gITS7F TCCTCCGCTTATTGATATGC-GTGARTCATCGARTCTTTG

# Activate Qiime2 environment
source /usr/local/miniconda3/etc/profile.d/conda.sh
conda activate qiime2-2023.2

# Set path and sequence of primer
SEQ="/home/ITS_rawdata"
OUT="/home/ITS"
DATABASE="/home/00Localdb"

# Create Manifest file 
cd $SEQ
ls *fastq | \
    awk -v P="$(pwd)" 'BEGIN { print "sample-id,absolute-filepath,direction" } \
    {print $1","P"/"$0",forward"}' > $OUT/sample_dataset.csv
cd $OUT

# Import the data
time qiime tools import \
    --type 'SampleData[SequencesWithQuality]' \
    --input-path $OUT/sample_dataset.csv \
    --input-format SingleEndFastqManifestPhred33 \
    --output-path $OUT/single-end-demux.qza

# Trim primer and adapter
# ITS4- gITS7F
time qiime cutadapt trim-single \
    --p-cores 30 \
    --p-discard-untrimmed \
    --p-error-rate 0.1 \
    --i-demultiplexed-sequences $OUT/single-end-demux.qza \
    --p-front TCCTCCGCTTATTGATATGC \
    --o-trimmed-sequences $OUT/single-end-demux-trimmed.qza \
    --verbose

# Visualize quality of reads
# https://view.qiime2.org
## before trimming
time qiime demux summarize \
	--i-data $OUT/single-end-demux.qza \
	--o-visualization $OUT/single-end-demux.qzv
## after trimming
time qiime demux summarize \
	--i-data $OUT/single-end-demux-trimmed.qza \
	--o-visualization $OUT/single-end-demux-trimmed.qzv

# Denoise with DADA2
mkdir $OUT/dada2
time qiime dada2 denoise-single \
	--i-demultiplexed-seqs $OUT/single-end-demux-trimmed.qza \
	--p-trim-left 0 \
	--p-trunc-len 180 \
	--p-max-ee 2 \
	--p-chimera-method consensus \
	--o-denoising-stats $OUT/dada2/stats-dada2.qza \
	--o-table $OUT/dada2/fungi_count.qza \
	--o-representative-sequences $OUT/dada2/fungi_rep_seqs.qza \
	--verbose

# Visualize denoized results
# https://view.qiime2.org
## table
time qiime feature-table summarize \
	--i-table $OUT/dada2/fungi_count.qza \
	--o-visualization $OUT/dada2/fungi_count.qzv
## rep-seq
time qiime feature-table tabulate-seqs \
	--i-data $OUT/dada2/fungi_rep_seqs.qza \
	--o-visualization $OUT/dada2/fungi_rep_seqs.qzv

# Assign taxonomy
## self-trained Silva Naive Bayes classifier
mkdir $OUT/classified_sequences
time qiime feature-classifier classify-sklearn \
	--i-classifier $DATABASE/unite-ver9-dynamic-classifier-03.16.2023.qza \
	--i-reads $OUT/dada2/fungi_rep_seqs.qza \
	--o-classification $OUT/classified_sequences/classification.qza

# Visualize taxonomic classification
# https://view.qiime2.org
## Visualize taxonomic classification
time qiime metadata tabulate \
	--m-input-file $OUT/classified_sequences/classification.qza \
	--o-visualization $OUT/classified_sequences/classification.qzv
## Visualize feature stats table
time qiime metadata tabulate \
	--m-input-file $OUT/dada2/fungi_count.qza \
	--o-visualization $OUT/dada2/stats-dada2.qzv
	
# Export the data 
## taxonomic table 
qiime tools export \
	--input-path $OUT/classified_sequences/classification.qza \
	--output-path $OUT/final_export
mv $OUT/final_export/taxonomy.tsv $OUT/final_export/fungi_taxonomy.tsv
## feature table 
qiime tools export \
	--input-path $OUT/dada2/fungi_count.qza \
	--output-path $OUT/final_export
biom convert \
	-i $OUT/final_export/feature-table.biom \
    -o $OUT/final_export/fungi_count.txt \
    --to-tsv	
