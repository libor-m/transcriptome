use warnings;
use strict;
use File::Basename;
#Ke Bi kebi@berkekley.edu

die (qq/

(version 0.11 July 31 2013)

Formats raw sequences for 2-scrubReads.pl 

Usage: 1-pre-cleanup.pl <raw data file folder> [option]

Option 

fastqc   if fastqc is provided, it will provide evaluation of the raw sequence data files

\n/) if !@ARGV;


my $orig_folder;
  
  if ($ARGV[0] =~ m/\/$/ ){
    $orig_folder = $ARGV[0]; 
  }
  else {
    $orig_folder = $ARGV[0] . "/";
  }

my $Result_dir1 = $orig_folder . 'combined/';
mkdir $Result_dir1 unless -e  $Result_dir1;
my $Result_dir2 = $orig_folder . 'pre-clean/';
mkdir $Result_dir2 unless -e  $Result_dir2;

my @orig_files = <$orig_folder*.gz>; 

die(qq/\nHmm...Is it the right folder? \n\n/) if (scalar (@orig_files) == 0);

foreach (<@orig_files>) {
	my $file = basename($_) =~ /(\S+_R[1|2])_\d+.fastq.gz/;
	die(qq/\nHmm...the name of the library doesn't match. Check\/modify line 34 of this script. \n\n/) if (!basename($_));
	my $lib_name = $1;
	my $file2 = $orig_folder . $1 .  '*'. '.fastq.gz';
	my $combined = $Result_dir1 . $1 . '.fastq.gz'; 
	system ("cat $file2 > $combined ") unless -e $combined;
	}


my @merged_files = < $Result_dir1*.fastq.gz> ;
foreach my $file (<@merged_files>) {
	my $out = $Result_dir2 .  $1 . $2 . ".fq" if basename($file)  =~ /(\S+)_[A|T|C|G|-]+_L\d+(_R[1|2]).fastq.gz/;
	my $redundancy = '^--$' ; 
	print "cleaning","\t",$file,"\n";
		if ($file =~ m/R(\d+)/) {
			if ($1 == 1) {
				system ("zcat $file | grep -A 3 \'^@.* [^:]*:N:[^:]*:\'  | grep -v $redundancy | sed \'s/ 1:N:0:.*/\\/1/g\' > $out");
			}
			if ($1 == 2) {
				system ("zcat $file | grep -A 3 \'^@.* [^:]*:N:[^:]*:\' | grep -v $redundancy | sed  \'s/ 2:N:0:.*/\\/2/g\' > $out");
			}

		}
}


if ($ARGV[1] && $ARGV[1] eq 'fastqc' ){
	my @raw = < $Result_dir2*.fq> ;
	my $outdir =  $Result_dir2.'evaluation/';
	mkdir $outdir unless -e $outdir;
	foreach (<@raw>) {
		
	my $call1 = system("fastqc -t 2 $_ -o $outdir");
	die(qq/\nThe program "fastQC" is not in path! \n\n/) if ($call1 == -1 );
	
	system ("rm $outdir*fastqc.zip");
	}
}

if (!$ARGV[1]) {
  
  print "This is a reminder: No evaluation on raw sequence reads. If you would like to do so please use fastqc option." , "\n";

}


