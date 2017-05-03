#!/usr/bin/perl

use Pod::Usage;
use Getopt::Long;
use XML::LibXML;
use Data::Dumper;

=head1 SYNOPSIS

 usage: tc_vsp.pl [--base] [--verbose] [--help]

=cut

my ($optVerbose,$optHelp,$optDebug,$optBase);
GetOptions( "verbose+"=>\$optVerbose,
            "base"=>\$optBase,
            "help|?",\$optHelp);
pod2usage(1) if ( $optHelp );

$GLOBAL::optVerbose = defined $optVerbose ? $optVerbose : 0;

#require "../library/commun.pl";

use vars qw($separateur);
use vars qw($separateur2);

$separateur2 = ";";
$separateur = "\n";


#use vars qw($separateur);
my $chemin;
$chemin = "/admin/Emc_mig/trait_baies";
use strict;

my $res=`/produit/CCI/HiCommandCLI GetStorageArray model=R700 subtarget=ReplicationInfo -f xml`;
my %repls = ();

my $parser = XML::LibXML->new();
my $tree = $parser->parse_string($res);
my $root = $tree->getDocumentElement;

my @storages = $root->getElementsByTagName('StorageArray');

foreach my $storage (@storages) {
        print "Baie : ".$storage->getAttribute('description')."\n" if ( $optVerbose );
        my @replications = $storage->getElementsByTagName('ReplicationInfo');
        foreach my $replication (@replications) {
            $repls{$replication->getAttribute('objectID')}=join("$separateur" ,($replication->getAttribute('pvolSerialNumber'),$replication->getAttribute('displayPvolDevNum'),$replication->getAttribute('svolSerialNumber'),$replication->getAttribute('displaySvolDevNum'),$replication->getAttribute('replicationFunction'),$replication->getAttribute('status')));
        }
}
        open (fichier,">$chemin/Ldev_TC.log") || die ("Erreur d'ouverture de fichier");

my @keys = keys(%repls);
foreach my $key (@keys) {
 	   my ($baie_p,$dev_p,$baie_s,$dev_s,$synchro,$status) = split("$separateur",$repls{$key});
	    print fichier "$dev_p;$baie_p\n";	
#    insertion_rdf ( $baie_p, $dev_p, $baie_s, $dev_s, $synchro, $status) if ( $optBase );
    print "P-VOL ".$dev_p." (Baie ".$baie_p.") S-VOL ".$dev_s." (Baie ".$baie_s.") de type ".$synchro." status " .$status."\n" if ( $optVerbose );
}

