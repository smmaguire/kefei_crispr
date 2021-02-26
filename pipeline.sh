#!/bin/bash
## By Sean Maguire
## smaguire@neb.com
## 2/25/2021


function usage {
        echo "Usage: $(basename $0) [-vs] [-l LENGTH]" 2>&1
        echo 'Demultiplex with flexbar, then run crispresso and map the 
reads'
        echo '   -i     Multiplexed fastq r1 '
        echo '   -u     Multiplexed fastq r2 ' 
        echo '   -e     Experimental prefix to name folders'
        echo '   -o     output dir, no end slash'
        echo '   -b     barcode fasta'
        echo '   -r     reference file fasta'
        exit 1
}

# if no input argument found, exit the script with usage
if [[ ${#} -eq 0 ]]; then
   usage
fi

# Define list of arguments expected in the input
optstring=":i:u:e:o:b:r:"

while getopts ${optstring} arg; do
  case ${arg} in
    i)
      start_fq_r1="${OPTARG}"
      ;;
    u)
      start_fq_r2="${OPTARG}"
      ;;
    e)
      out_prefix="${OPTARG}"
      ;;
    o)
      main_out_dir="${OPTARG}"
      ;;
    b)
      barcodes="${OPTARG}"
      ;;
    r)
      ref="${OPTARG}"
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      echo
      usage
      ;;
  esac
done

out_demux1=$main_out_dir/$out_prefix/"demux_reads1"
out_demux2=$main_out_dir/$out_prefix/"demux_reads2"
out_demux_final=$main_out_dir/$out_prefix/"demux_reads_final"
out_mapped=$main_out_dir/$out_prefix/"mapped_reads"
out_crispresso=$main_out_dir/$out_prefix/"crispresso2_output"

#Check if the main directory already exists. If it does erase everything inside of it

if [ -d "$main_out_dir/$out_prefix/" ]; then
  ### Take action if $DIR exists ###
  rm -r $main_out_dir/$out_prefix/*
  #echo "skip"
else
  mkdir -p $main_out_dir/$out_prefix
fi

mkdir -p $out_demux1
mkdir -p $out_demux2
mkdir -p $out_demux_final
mkdir -p $out_mapped
mkdir -p $out_crispresso

source activate variant_calling
echo "starting flexbar demux round 1"
flexbar -r $start_fq_r1 -p $start_fq_r2 -b $barcodes -bt ANY -bu -t $out_demux1"/first_pass"
echo "done"
echo "starting flexbar demux round 2"
flexbar -r $out_demux1/first_pass_barcode_unassigned_2.fastq -p $out_demux1/first_pass_barcode_unassigned_1.fastq -b $barcodes -bt ANY -bu -t $out_demux2/second_pass
echo "done"
echo "combining fastqs"
for i in $( ls $out_demux1/*.fastq); do
  name=${i#$out_demux1/}
  suffix=${name#"first_pass"}
  r2=$out_demux2/"second_pass"$suffix
  cat $i $r2 >> $out_demux_final"/merge"$suffix
done

echo "done"

echo "Starting Crispresso 2"

source activate crispresso2_env

for i in $( ls $out_demux_final/merge*1.fastq); do
  r2=${i%1.fastq}
  r2=$r2"2.fastq"
  new_name=${i#merge_barcode_bc_}
  new_name=${new_name%_1.fastq}

  CRISPResso --fastq_r1 $i --fastq_r2 ${r2} \
  --amplicon_seq GCCGCTCTAGCCTCGAGGTCGGCTCGCCGGCGGGAGGCTCGCGGGCAGCAATGTGGGTTGCCGCGCTGGCGTGAGTGATGCGCTGGCTGCTGCCGCTGTCCCGCACAGTGACACTGGCCGTCGTACGCCTGAGGCGAGGCATTTGCGGGCTCGGGATGTTCTATGCGGTGAGGAGAGGCCGCAGGACCGGAGTCTTCCTGAGTTGGTGAGACGGAGCCTGGCGGAGCCCTTTATTCTAAACACCTAACAGCTCGTTTAGCCCTTCCGTGTTGTAGTCAAATCCTCCCAAAGAGAACACATGGTCACCGCAGCCAGAATTTACACAAGGCTTCCCACGTTCTGATCGTT \
  --amplicon_name amplicon \
  --file_prefix $new_name \
  --output_folder $out_crispresso \
  --keep_intermediate
done

echo "starting mapping"
source activate bbtools

for i in $( ls $out_demux_final/merge*1.fastq); do
       r2=${i%1.fastq}
        r2=$r2"2.fastq"
        new_name=${i#$out_demux_final/merge_barcode_}
        new_name=${new_name%_1.fastq}
  echo $new_name
  bbmap.sh in=$i in2=$r2 out=$out_mapped/$new_name"_mapped.sam" ref=$ref nodisk=t
done

source activate samtools2

echo "starting indexing"
for i in $( ls $out_mapped/*_mapped.sam); do
        echo $i
  sam_name=${i%_mapped.sam}
  echo $sam_name
  samtools view -b $i | samtools sort - > $sam_name.bam 
  samtools index $sam_name.bam
done

exit 0
