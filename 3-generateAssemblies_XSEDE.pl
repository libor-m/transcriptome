#!/usr/bin/perl 


use strict;
use warnings; 
use Getopt::Std;
use Getopt::Long;
use File::Basename;

##############################################################################################################################
# a script to prepare shell scripts to use for assembly with multiple de novo assemblers on TACC                             #
# external dependencies: to run the script, none but ... to use the scripts: abyss, velvet, trinity, oases, soapdenovo-trans #
# written by Sonal Singhal, sonal.singhal1 [at] gmail.com, 13 Dec 2011                                                       #    
# modified as command line versions by Ke Bi, kebi [at] berkeley.edu, 19 July 2013                                           # 
# useful as a framework but not as an actual script                                                                          #
##############################################################################################################################


&main;
exit;

sub main {
        &usage if (@ARGV<1);
        my $command = shift(@ARGV);
        my %fun = (abyss=>\&abyss, velvet=>\&velvet, trinity=>\&trinity, oases=>\&oases, soapdenovo=>\&soapdenovo);
        die("Unknown command \"$command\"\n") if (!defined($fun{$command}));
        &{$fun{$command}};
      }


sub usage {
  die(qq/
Usage: 5generateAssemblies.pl <command> [<arguments>]\n
Command: 

trinity: Assembly using trinity on the blacklight

abyss: Assembly using ABySS on the blacklight

velvet: Assembly using velvet (to be implemented)

oases: Assembly using oases (to be implemented)

soapdenovo: Assembly using soapdenovo-trans (to be implemented)

\n/);
}

sub trinity {
  die(qq/
Usage 5generateAssemblies.pl trinity [options]

Options: -d CHR folder where cleaned reads are kept
         -h CHR home directory
         -e CHR email address
         -c INT number of cpu required; minimal=32, half lane = 48, one lane =64 [32]
         -o INT number of walltime hours required; >half lane =24hours; half lane = 48 hours [24]   

must provide full path for -d and -h
Assuming the unpaired reads (XXX_u_final.txt) are merged with the left end reads (XXX_1_final.txt), with a new name of "XXX_1_final.txt".
  
\n/) if (!@ARGV);
  
  my %opts = (d=>undef, h=>undef, e=>undef, c=>32, o=>24);
  getopts('d:h:e:i:c:o:', \%opts);

my $dir;
  
  if ($opts{d} =~ m/\/$/ ){
    $dir = $opts{d}; 
  }
  else {
    $dir = $opts{d} . "/";
  }
  
  
  my $home;
  
  if ($opts{h} =~ m/\/$/ ){
    $home = $opts{h}; 
  }
  else {
    $home = $opts{h} . "/";
  }

my @lib = <$dir*_1_final.txt>;

foreach my $lib1 (@lib) {
        my $lib2 = $lib1;
	$lib2 =~ s/_1_/_2_/;
	my $lib = $1 if basename($lib1) =~ m/(\S+)_[1|2]_final.txt/;
	
	makeTrinity($dir, $home, $opts{e}, $lib1, $lib2, $lib, $opts{c}, $opts{o});
		}
	}


sub makeTrinity {
	my ($dir, $home, $email, $file1, $file2, $lib,$cpu,$time) = @_;

	my $resultsDir =  $dir . 'trinityResults';
	my $runfileDir =  $dir . 'trinityScripts';
	mkdir($resultsDir) unless (-d $resultsDir);
	mkdir($runfileDir) unless (-d $runfileDir);
	
	my $libResults = $resultsDir . '/' . $lib;
	mkdir($libResults) unless (-d $libResults);

	my $job = 'trinity' . "_" . $lib;

	my $jm = int(0.9 * 8 * $cpu) . "G";
	open(OUT, ">$runfileDir" . "/" . $job . ".sh");

	print OUT "#!/bin/bash\n";
	print OUT "#PBS -l ncpus=",$cpu,"\n";
	print OUT "#PBS -l walltime=",$time,":00:00\n";
	print OUT "#PBS -j oe\n";
	print OUT "#PBS -q batch\n";
	print OUT "#PBS -m e\n";
	print OUT "#PBS -M $email\n";
	print OUT "#PBS -N $job\n";
	print OUT "#-W group_list=IBN100014\n";
	print OUT "set -x\n";
	print OUT "source /usr/share/modules/init/bash\n";
        print OUT "module load trinity/r2013-02-25\n";
	print OUT "ulimit -u unlimited\n";
	print OUT "ja\n";
	print OUT "cd $libResults\n";
	print OUT "export OMP_NUM_THREADS=32\n";
	print OUT "Trinity.pl --seqType fq --left $file1 --right $file2 --bflyGCThreads 32 --min_kmer_cov 2 --JM $jm --group_pairs_distance 999 --output \$SCRATCH_RAMDISK --CPU $cpu > $libResults" . "/trinity.log\n";
	print OUT "cp -r \$SCRATCH_RAMDISK/Trinity.fasta $libResults\n";
	print OUT "cp -r \$SCRATCH_RAMDISK/\* $libResults\n";
	print OUT "ja -chlst\n";
	close(OUT);
      }


sub abyss {
  die(qq/
Usage 5generateAssemblies.pl abyss [options]

Options: -Dir        CHAR            folder where cleaned reads are kept
         -email      CHAR            email address
         -Res        CHAR            result directory
         -lib        CHAR ...        Particular libraries to process? (e.g. AAA BBB CCC). If -lib is not used then process all libraries in the folder (-Dir)
         -name       CHAR            name of the bash submission file
         -kmer       INT ...         A list of kmers. At least privide one kmer (e.g. 21 43 67 81) [21 41 61 81]
         -kcov       INT ...         A list of non-zero kmer-coverage. Activate default without using kcov (e.g. 5 10 20) [null]
         -cpu        INT             number of cpu required [16]
         -hour       INT             number of walltime hours required [24] 

NOTE: must provide full path for -Dir and -Res
Assuming the naming libraries are XXX_1_final.txt, XXX_2_final.txt and XXX_u_final.txt.
  
\n/) if (!@ARGV);
  my %opts = (kmer => [21,41,61,81],np => 8, cpu => 16 , hour=> 24);
  my ($Dir, $email,$Res, $kcov, $lib, $name) = (undef, undef, undef, undef, undef, undef);
  GetOptions('kmer=s@{1,}' => \$opts{kmer},'Dir=s@{1,1}' => \$Dir,'Res=s@{1,1}' => \$Res, 'kcov=s@{,}' => \$kcov, 'cpu=s@{1,1}' => \$opts{cpu},  'hour=s@{1,1}' => \$opts{hour}, 'name=s@{1,1}' => \$name, 'lib=s@{,}' => \$lib, 'email=s@{1,1}' => \$email);
  
  
  my $dir;
  
  if (@{$Dir}[0] =~ m/\/$/ ){
    $dir = @{$Dir}[0]; 
  }
  else {
    $dir = @{$Dir}[0] . "/";
  }
  
  
  my $res;
  
  if (@{$Res}[0] =~ m/\/$/ ){
    $res = @{$Res}[0]; 
  }
  else {
    $res = @{$Res}[0]. "/";
  }
  
  mkdir $res unless -d $res;
  
  my @files = ();
  if (!$lib) {
    @files= <$dir*_1_final.txt>;
    makeABySS (\@files, $dir, $res, @{$name}[0], $opts{kmer}, $opts{hour}, $opts{cpu}, \@{$kcov}, @{$email}[0]);
  }
  
  if ($lib) { 
    foreach (@{$lib}) {
      my $file = $dir . $_ .'_1_final.txt';	
      push (@files, $file); 
    }
    makeABySS (\@files, $dir, $res, @{$name}[0], $opts{kmer}, $opts{hour},  $opts{cpu}, \@{$kcov}, @{$email}[0]);
  } 
  
  
  sub makeABySS {
    
    my ($files, $dir, $res, $name, $kmer, $hour, $cpu, $kcov, $email) = @_;
    my @reads = @{$files};
    my $lib_results = $res . $name . "/";
    my $bash = $res .  'ABySS_' . $name . '.sh';
   
    mkdir $lib_results unless -d $lib_results; 
    
    
    open (OUT, ">", $bash);
    
    print OUT "/bin/bash" ,"\n";
    print OUT "#PBS -l ncpus=@{$cpu}[0]","\n";
    print OUT "#PBS -l walltime=@{$hour}[0]:00:00","\n";
    print OUT "#PBS -j oe","\n";
    print OUT "#PBS -q batch" ,"\n";
    print OUT "#PBS -m e", "\n";
    print OUT "#PBS -M $email" ,"\n";
    print OUT "#PBS -N $name", "\n";
    print OUT "#-W group_list=IBN100014\n";
    print OUT "set -x\n";
    print OUT "source /usr/share/modules/init/bash\n";
    print OUT "module load abyss-openmpi-gnu/1.3.4-maxk96","\n";
    print OUT "ulimit -u unlimited","\n";
    print OUT "ja","\n";
    print OUT "cd $lib_results","\n";
    print OUT "export OMP_NUM_THREADS=32","\n";
    
    
    foreach my $file1 (@reads) {
      my $file2 = $file1;
      my $fileu = $file1;
      $file2 =~ s/_1_/_2_/;
      $fileu =~ s/_1_/_u_/;
      my $lib = $1 if  basename($file1) =~ m/(\S+)_1_final.txt/;
      
      foreach my $k (@{$kmer}) {
	if ($kcov){
	  foreach my $cov (@{$kcov}) {
	    print OUT "abyss-pe  k=$k c=$cov e=$cov np=@{$cpu}[0] s=200 E=0 n=10 in=\'$file1 $file2\' se=$fileu name=$lib_results$lib", "_k$k","_cov$cov", "\n";
	  }
	}
	if (!$kcov) {
	  print OUT "abyss-pe k=$k np=@{$cpu}[0] s=200 E=0 n=10 in=\'$file1 $file2\' se=$fileu name=$lib_results$lib", "_k$k","_cov_default","\n";
	}
      }
    } 
    print OUT "ja -chlst","\n";
    
   close OUT; 
  }
  
  
  
  
}



