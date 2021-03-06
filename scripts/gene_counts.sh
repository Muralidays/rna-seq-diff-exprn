#!/bin/sh

# Author: Olga Botvinnik (olga.botvinnik@gmail.com)
# Date: 21 June 2012
# Purpose of this script: Finds gene- and genome-wide counts
# of a BED file using both bedtools and HTSeq
#
# This gene_counts.sh script does:
# 1. Estimate gene counts from BAM via bedtools and HTSeq
# 2. Calls another script to:
#    a. Estimate genome-wide coverage via bedtools and HTSeq
#    b. Make circos plot of coverage for this sample
# 3. Estimates differential exon usage counts using
#    dexseq_counts.py (does not perform DEXSeq analysis)

BAM_PREFIX=$1
# EXPRN_DIR=$2
GENDER=$2

# Need the ID for circos file creation/plotting
ID=$3
STRAND=$4
COMMON_VARS=$5
i=$6

# Initialize common variables
source $COMMON_VARS

BEDTOOLS_DIR=$EXPRN_DIR/bedtools/$ID
HTSEQ_DIR=$EXPRN_DIR/htseq/$ID

if [[ ! -d $BEDTOOLS_DIR ]]; then
    mkdir -p $BEDTOOLS_DIR
fi

if [[ ! -d $HTSEQ_DIR ]]; then
    mkdir -p $HTSEQ_DIR
fi

BAM=$BAM_PREFIX.bam
echo "finding gene counts for" $BAM

######## Begin gene count estimation via Bedtools #########
# Do the intersect
BAM_INTERSECT=$BAM_PREFIX\_intersect.bam

if [[ ! -e $BAM_INTERSECT ]]; then
    samtools view -b $BAM | \
        bedtools intersect -abam - \
        -b $BED > $BAM_INTERSECT
fi

# Gene expression estimation via bedtools
# -counts: Only report the count of overlaps, 
#          don't compute fraction, etc.
# -hist: Report a histogram of coverage for each feature in B
#        as well as a summary histogram for _all_ 
#        features in B.
#        Output (tab delimited) after each feature in B:
#           1) depth
#           2) # bases at depth
#           3) size of B
#           4) % of B at depth
# -d: Report the depth at each position in each B feature.
#     Positions reported are one based.  Each position
#     and depth follow the complete B feature.


THIS_COUNTS_BED=$BEDTOOLS_DIR/$COUNTS_BED
coverageBed_options='-counts -hist -d'

# if [[ ! -e $THIS_COUNTS_BED ]]; then
    bedtools coverage \
        $coverageBed_options \
        -abam $BAM_INTERSECT \
        -b $BED >$THIS_COUNTS_BED
# fi

######## END gene count estimation via Bedtools #########


######## BEGIN gene count estimation via HTSeq #########
############### For some reason this does NOT work when
############### executed from this script but works fine 
############### from the command line

# COUNTS_HTSEQ_PREFIX=htseq_counts

# echo 'COUNTS_HTSEQ=$COUNTS_HTSEQ' | cat - >> $COMMON_VARS

# 'sort -s -k 1,1': Sort SAM file by read name before HTSeq
SAM_SORTED=$BAM_PREFIX\_sorted_read_name.sam
if [[ ! -e $SAM_SORTED ]] ; then
    samtools view $BAM | \
        sort -s -k 1,1 >$SAM_SORTED
fi

if [[ $STRAND == strand_specific ]]; then
    HTSeqCount_options='--stranded=yes'
else
    HTSeqCount_options='--stranded=no'
fi

THIS_COUNTS_HTSEQ_PREFIX=$HTSEQ_DIR/$COUNTS_HTSEQ_PREFIX
# if [[ ! -e $THIS_COUNTS_HTSEQ_PREFIX.txt ]]; then
$HTSEQ_BIN \
    $HTSeqCount_options $SAM_SORTED $GTF \
    >$THIS_COUNTS_HTSEQ_PREFIX.txt\
    2>$THIS_COUNTS_HTSEQ_PREFIX.err
# fi
######## END gene count estimation via HTSeq #########


# --- BEGIN Circos file preparation and plotting --- #
$SCRIPTS_DIR/circos_single_sample.sh \
    $BAM $SAM_SORTED $GENDER $ID $COMMON_VARS $i
# --- END Circos file preparation and plotting   --- #

############# BEGIN DEXSeq counts ##################
THIS_DEXSEQ_OUT=$DEXSEQ_DIR/$ID/$DEXSEQ_OUT
if [[ ! -d $DEXSEQ_DIR/$ID ]]; then
    mkdir -p $DEXSEQ_DIR/$ID
fi

samtools view $BAM | \
    python2.7 $SCRIPTS_DIR/external/dexseq_count.py \
    $HTSeqCount_options \
    $DEXSEQ_GTF - $THIS_DEXSEQ_OUT
########################