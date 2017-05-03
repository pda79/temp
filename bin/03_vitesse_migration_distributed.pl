#!/usr/bin/perl
# Auteur : Jean-Laurent MARTINEZ
# Creation : 23 Nov 2011 15:27:31
# Derniere modification : 10 fevrier 2016

use strict;

use Pod::Usage;
use Getopt::Long;
use XML::LibXML;
use Data::Dumper;
use POSIX qw(strftime);
my $datestring = strftime "%Y-%m-%d_%H-%M", localtime;
print("date and time :$datestring\n");

=head1 SYNOPSIS

usage: distributed.pl [--verbose] [--help] [--debug] [--optimise] [--normal]
        Debug : Affhichage des tableaux
        optimise : Augmente le transfert size des volumes du serveurs 
        normal : Remet le transfert size par defaut
=cut


my ($optVerbose,$optHelp,$optdebug,$opt_optimise,$opt_normal,$opt_status);

GetOptions( "verbose!"=>\$optVerbose,
                "help|?",\$optHelp,
                "debug"=>\$optdebug,
                "optimise"=>\$opt_optimise,
		"status"=>\$opt_status,
                "normal"=>\$opt_normal);

pod2usage(1) if ( $optHelp );
#---------------------------------------------------------------------------------------------
if ( $optHelp ){
print "usage: $0 [-h | -?] [-l]
        -h|?    : Affichage de l'aide
        arg 1   : Hostgroup
        -help   : Affichage de l'aide\n";
exit -1;
}

my $HG = sprintf uc ($ARGV[0]);

print "###############################################################################\n";
print "#                                                                              #\n";
print "############     ./distributed SAAPPXX --status	                 ##############\n";
print "############	./distributed SAAPPXX --optimise		 ##############\n";
print "############     ./distributed SAAPPXX --normal	                 ##############\n";
print "#									      #\n";
print "#						  			      #\n";
print "###############################################################################\n";

if (!$ARGV[0] ){ print "Merci de saisir le Nom du serveur suivi de optimise ou normal \n\n\n";}


if ($opt_optimise){
	my $command_optimise = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/rebuild+set-transfer-size\" -X POST -d \"{\\\"args\\\":\\\"--devices *_$HG --limit 2M \\\"}\" "; 
	print "Veuillez patienter Optimisation en cours .....\n";
	my $cmd_optimise = `$command_optimise`;
	
	print "$cmd_optimise\n";
	##########commande curl pour accelerer les devices 


}

if ($opt_normal){
	my $command_normal = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/rebuild+set-transfer-size\" -X POST -d \"{\\\"args\\\":\\\"--devices *_$HG --limit 128k \\\"}\" ";
	print "Veuillez patienter retour à la normale en cours .......\n";
	my $cmd_normal = `$command_normal`;
	print "$cmd_normal\n";
	
	#########retour à la normale pour les disques du serveur


}

if ($opt_status){
	
	#my $command_status = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/rebuild+show-transfer-size\" -X POST -d \"{\\\"args\\\":\\\"-r *_$HG \\\"}\" | awk -F \\\" '\/device name\/ {print \$4}' "  ;
	
	my $command_status = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/rebuild+show-transfer-size\" -X POST -d \"{\\\"args\\\":\\\"-r *$HG\\\"}\" |sed 's/\\\\n/\\\
/g'" ;
      	print $command_status;	
 	my @cmd_status =`$command_status`;
	
	foreach (@cmd_status){
		chomp $_;
		print "$_\n";	
	}
	

}



















