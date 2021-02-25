#!/bin/bash

function usage {
        echo "Usage: $(basename $0) [-vs] [-l LENGTH]" 2>&1
        echo 'Demultiplex with flexbar, then run crispresso and map the reads'
        echo '   -i 		Multiplexed fastq r1 '
        echo '   -u     Multiplexed fastq r2 ' 
        echo '   -e     Experimental prefix to name folders'
        echo '	 -o 		output dir, no end slash'
        echo '   -b  		barcode fasta'
        echo '   -r 		reference file fasta'
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
flexbar -r $start_fq_r1 -p $start_fq_r2 -b $barcodes -bt ANY -bu -t first_pass


exit 0