#!/usr/bin/perl

# Auteur : Jean-Laurent MARTINEZ
# Creation : 28 07 2016 15:27:31
# Derniere modification : 28 07 2016

use strict;

use Pod::Usage;
use Getopt::Long;
use XML::LibXML;
use Data::Dumper;
use POSIX qw(strftime);
my $datestring = strftime "%Y-%m-%d_%H-%M", localtime;
print("date and time :$datestring\n");
my $chemin;
my $cheminsrc;

#print "heure:$date_modif";
$chemin = "/admin/Emc_mig/log";
$cheminsrc = "/admin/Emc_mig/trait_baies";
chomp ($chemin);
#------------------------------------Synopsis pour Option------------------------------------
=head1 SYNOPSIS

usage:  05_Vmware.pl nom_vm [--verbose] [--help] [--debug] [--BatI] [--BatG]
        arg 1: nom de la vm
        arg 2: Preference de batiment
        arg 3: Environnement
        Debug : Affhichage des tableaux
        BatI : Liste des Ldev Batiment I
        BatG : Liste des Ldev Batiment G
=cut


my ($optVerbose,$optHelp,$optdebug,$optBase,$optBati,$optBatg,$optprincipal,$optforce,$optlinux);
GetOptions( "verbose!"=>\$optVerbose,
                "help|?",\$optHelp,
                "debug"=>\$optdebug,
                "auto"=>\$optforce,
                "principal"=>\$optprincipal,
                "linux"=>\$optlinux, # modif du 25 juillet
                "BatI"=>\$optBati,
                "BatG"=>\$optBatg);

pod2usage(1) if ( $optHelp );
#---------------------------------------------------------------------------------------------
if ( $optHelp ){
print "usage: $0 [-h | -?] [-l]
        -h|?    : Affichage de l'aide
        arg 1   : Nom de la vm
        arg 2   : Environnement P ou HP
        -help   : Affichage de l'aide\n";
exit -1;
}
print "\033[2J";


print "##########################################################################################\n";
print "########  Script de création des disques VNX et Encapsulation VSP   ######################\n";
print "########                Raw device Vmware	                  ######################\n";
print "########                                                            ######################\n";
print "##########################################################################################\n\n\n\n\n";
print "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";

my $VM = sprintf uc ($ARGV[0]);
#my $pref = $ARGV[];
my $env = $ARGV[1];
my $cluster = $ARGV[2];
my $LUNID = $ARGV[3];

chomp($VM);
#chomp($pref);
chomp($env);

if (($VM eq "")){
        print "\n###################Merci de saisir le nom de la vm###################\n\n";
        exit 1;
}

if (( $env ne "P") && ( $env ne "HP")) {
        print "\n###################Merci de saisir l'environnement du serveur P ou HP###################\n\n";
        exit 1;

}
if (($cluster eq "")){
        print "\n###################Merci de saisir Cluster de destination###################\n\n";
        exit 1;
}

if ( $LUNID eq "") {
        print "\n###################Merci de saisir le numero de la lun de destination###################\n\n";
        exit 1;

}

print "$VM -> $env\n";

#--------------------------------ouverture des fichiers créé par les autres pl-----------
open(FIC,"<$cheminsrc/Ldev_bat_all.log");# if ($optBati);
my @tab_contenu_LDEV = <FIC>;
close(FIC);

open (FIC,"<$cheminsrc/Ldev_TC.log");
my @tabtc =<FIC>;
close(FIC);

open(FIC,"<$cheminsrc/host_group_device_all.log");
my @tabhg = <FIC>;
close(FIC);

open(FIC,"<$cheminsrc/cluster_esx.log");
my @tabvmware = <FIC>;
close(FIC);
my @tab_Vmware_tmp = grep {/$cluster/} @tabvmware;
my @tab_Vmware = split /[;,]/,@tab_Vmware_tmp[0];

#-----------------------------------------------------------------------------------------



#------------------------ Traitement et memo du fichier Ldev-----------------------------------------
my %infos_ldev_tb;
my %infos_ldev_pid;
my %infos_ldev_tk;
my %infos_ldev_lab;
my $ligne;
my $new_ldev;
my $wwn2;

foreach $ligne (@tab_contenu_LDEV)
{
        $ligne =~ s/\r?\n//gi;

        my ( $baie, $ldev, $taille_ko, $taille_bloc, $pool_id, $taille_use, $label) = split /;/, $ligne;
        $infos_ldev_tb{"$ldev#$baie"} = $taille_bloc;
        $infos_ldev_tk{"$ldev#$baie"} = $taille_ko;
        $infos_ldev_pid{"$ldev#$baie"} = $pool_id;
        $infos_ldev_lab{"$ldev#$baie"} = $label;
        #print "Volume : $ldev -> ".$infos_ldev_tk{"$ldev"}." -> ".$infos_ldev_lab{"$ldev"}."\n";
}
#----------------------------------------------------------------------------------------------------

my @tab_vm_rd = grep {/$VM/i} @tab_contenu_LDEV;

foreach (@tab_vm_rd){
	my ($l_baie,$l_ldev,undef,undef,undef,undef,undef) = split /;/, $_;
	my $tc;
	chomp ($l_ldev,$l_baie);
	if (grep (/$l_ldev;$l_baie/,@tabtc)){
		$tc = "yes";
		print "volume True_copié\n"

	}
	print "\n$l_ldev,$l_baie,$tc \n"  if $optdebug; 
	&prepa_vol($l_ldev,$l_baie,$tc); 
	$LUNID = $LUNID + 1;

}


sub prepa_vol {
	print "\nboucle prepa_vol\n" if $optdebug;
	my ($l_ldev,$l_baie,$l_tc) = @_;
	my($pool,$bat);
 	print $infos_ldev_pid{"$l_ldev#$l_baie"}."\n";
	if ($infos_ldev_pid{"$l_ldev#$l_baie"} == 0) {$pool="0";}
        if ($infos_ldev_pid{"$l_ldev#$l_baie"} == 20) {$pool="1";}
        if ($infos_ldev_pid{"$l_ldev#$l_baie"} == 30) {$pool="2";}
	if ($l_baie == "85183") {$bat = "I"}; 	
	if ($l_baie == "53317") {$bat = "G"};
	#----------------------------generation nom du colume-------------------------";
	my $nom_volume = &gen_nom ($bat,$l_tc,$pool,$infos_ldev_lab{"$l_ldev#$l_baie"},$LUNID);
	#-----------------------------------------------------------------------------";
	#----------------------------Lancement action VNX I et VNX G------------------";
	if (($l_baie == "85183")&& ($l_tc ne "yes")){
		my $command_verifVNXI = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38  getlun | grep $nom_volume`;
		if (!$command_verifVNXI){
			&action_vnxI($infos_ldev_tb{"$l_ldev#$l_baie"},$pool,$nom_volume,$bat,$l_ldev,$l_baie,$LUNID);

		}
		else {print "Volume $l_ldev Dèja créé sur la VNX I on passe à la suite\n";}	
	}	
	elsif(($l_baie == "53317") && ($l_tc ne "yes")){
		my $command_verifVNXG = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40  getlun | grep $nom_volume`;
		if (!$command_verifVNXG){
	                &action_vnxG($infos_ldev_tb{"$l_ldev#$l_baie"},$pool,$nom_volume,$bat,$l_ldev,$l_baie,$LUNID);
		}
                else {print "Volume $l_ldev Dèja créé sur la VNX I on passe à la suite\n";}
        }
	elsif ($l_tc eq "yes"){
		my $command_verifVNXI = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38  getlun | grep $nom_volume`;
                if (!$command_verifVNXI){
                        &action_vnxI($infos_ldev_tb{"$l_ldev#$l_baie"},$pool,$nom_volume,$bat,$l_ldev,$l_baie,$LUNID);

                }
                else {print "Volume $l_ldev Dèja créé sur la VNX I on passe à la suite\n";}
		my $command_verifVNXG = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40  getlun | grep $nom_volume`;
                if (!$command_verifVNXG){
                        &action_vnxG($infos_ldev_tb{"$l_ldev#$l_baie"},$pool,$nom_volume,$bat,$l_ldev,$l_baie,$LUNID);
                }
                else {print "Volume $l_ldev Dèja créé sur la VNX I on passe à la suite\n";}

	}	
	#-------------------------------------------------------------------------------";
	#------------------Lancement encapsulation--------------------------------------";
	my $instance;
	if($l_baie eq "85183"){$instance = "1839";}
        if($l_baie eq "53317"){$instance = "3179";}
        my $command_verif = "export HORCMINST=$instance;raidcom get ldev -ldev_id $l_ldev -login maintenance raid-mainte | grep MIGEMC";
        print "$command_verif\n";
        my $cmd_verif = `$command_verif`;
	 if (!$cmd_verif){
		#######################################################virtualisation des disque VSP######################################
                    print " \n#####Voulez vous Encapsuler et virtualiser le disque : $l_ldev source HDS de la baie $l_baie\n";
                    print "Reponse y/n ou q pour quitter le programme :  ";
                    my $input3 = <STDIN>;
                    chomp $input3;
                    if ($input3 =~ m/^[Q]$/i){
                         print "Exit du programme\n";
                         exit(0);
                    }
                     elsif($input3 =~ m/^[Y]$/i){
                         print "ATTENTION La vm doit etre arretée !!!\n";
                         my $commande_VSP = &addvolumevsptovplex($l_ldev,$l_baie,$LUNID,$nom_volume);
                         if ($l_tc eq "yes"){
                         	print "\n\n####Disque TC!! Creation du distributed device? ###\n";
                                print "Reponse y/n ou q pour quitter le programme :  ";
                                my $input = <STDIN>;
                                chomp $input;
                                if ($input =~ m/^[Q]$/i){
                                	print "Exit du programme\n";
                                        exit(0);
                                }
                                elsif($input =~ m/^[Y]$/i){
                #                     my $distributed = &distributed($nomdevice,$baie,$ldev);                  ######geré le Distributed devices!!!!!!!!!!!!!!
                                }
                         }
		    	
			#---------------------------positionnement dans storageview ------------------------------------";
	
			#$cluster		
			foreach (@tab_Vmware){
				if ($_ !~ /VI/){
					&storage_view($l_ldev,$nom_volume,$l_baie,$l_tc,$_);		
				}
			#	exit(0);		
			}
	 }	


	}


	#-------------------------------------------------------------------------------";	

}

sub storage_view{
        my ($l_dev,$l_lun,$l_baie,$l_tc,$l_hg) = @_;
        $l_hg = lc($l_hg);
        my $lunid = substr($l_lun, -3);
        print "storageview $l_baie->$l_tc->$l_dev->$l_lun->$lunid->$l_hg\n";
        if ($l_baie eq "85183" || $l_tc eq "yes"){
                print "Ajout dans la storage view V1_$l_hg du disque $l_dev\n";
                my $command_virtual = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/export+storage-view+addvirtualvolume\" -X POST -d \"{\\\"args\\\":\\\" -v V1_$l_hg -o ($l_lun) -f\\\"}\"";
                my $cmd_vitual = `$command_virtual`;
                print "$cmd_vitual\n";
        }
	if ($l_baie eq "53317" || $l_tc eq "yes"){
                print "Ajout dans la storage view V2_$l_hg du disque $l_dev\n";
                my $command_virtual = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA002/vplex/export+storage-view+addvirtualvolume\" -X POST -d \"{\\\"args\\\":\\\" -v V2_$l_hg -o ($l_lun) -f\\\"}\"";
                my $cmd_vitual = `$command_virtual`;
		print "$cmd_vitual\n";
	}	

		
}









sub gen_nom {
        my ($pref,$l_tc,$l_pool,$l_label,$l_lunid) = @_;
        my $nom_def;
        my $label_mod;
        my $type;
        my $lunid;
        if ($l_tc eq "yes"){
                $type = "DD$pref";
        }
        else {
                $type = "DL$pref";
        }
	$l_pool = "G" if ($l_pool == 0);
        $l_pool = "S" if ($l_pool == 1);
        $l_pool = "B" if ($l_pool == 2);
#       if($l_label =~ m/[aA][sS][mM]/ ){ $label_mod = "ASM";}
	
        my (undef,$label) = split /_/,$l_label;
           if ($label =~ m/#/){
                  my ($label_mod0,undef) = split /#/,$label;
                  $label = $label_mod0;
                }
                $label_mod = uc($label);
        $env = "PROD" if ($env eq "P");
        $env = "HPROD" if ($env eq "HP");
        #$dec_num = sprintf("%d", hex($l_lunid));
	$l_lunid = sprintf ('%03.d',$l_lunid);
        $nom_def = "$cluster"."_"."RDM_$label_mod"."_"."$type"."_"."$env"."_"."$l_pool"."_"."$l_lunid";
        return ($nom_def);
}

sub action_vnxI {               ######################## fonction de creation des ldev Vnx Bat I ##########################

                my ($taille,$pool,$mon_volume,$pref,$ldev,$baie,$lunid ) = @_;
                my $sp;
                my $cmd_recupid = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38 storagegroup -list -gname FBVPA001 | awk '\$1~/[0-9]/ && !/:/ {if (\$1>m) m=\$1;n[\$1]=\$2 }END{print n[m]}'`;
                chomp($cmd_recupid);
                my $cmd_sp = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38  getlun $cmd_recupid | awk '/Current\ owner:/ {print \$4}'`;
                chomp ($cmd_sp);
                if ($cmd_sp eq "A"){$sp = "B";}
                elsif ($cmd_sp eq "B"){ $sp = "A";}
                my $commande_creat_I = "/opt/Navisphere/bin/naviseccli -h 172.23.238.38 lun -create -type nonThin -capacity $taille -sq bc -poolId $pool -sp $sp -name $mon_volume-1 -tieringPolicy autoTier -initialTier highestAvailable";
                print "\n\nRecapitulatif: LEDV : $ldev Baie: $baie Lun de $taille Bloc pool $pool Nom du volume: $mon_volume \n\n";
                print "Affichage de la commande:\n";
                print "$commande_creat_I\n";
                print "\n\n####Voulez Vous créer le Ldev $ldev sur la VNX du Batiment I###\n";
                print "Reponse y/n ou q pour quitter le programme :  ";
                my $input = <STDIN>;
                chomp $input;
                if ($input =~ m/^[Q]$/i){
                        print "Exit du programme\n";
                        exit(0);
                }
                elsif($input =~ m/^[Y]$/i){
                          print "Execution Verification VNX I....\n";
                          print "\n\n######Creation des fichiers VNX BatI######\n";
                          my $cmd = `$commande_creat_I`;
                          print $cmd;
                          my $num_hlu = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38 storagegroup -list -gname FBVPA001 | awk '\$1~/[0-9]/ && !/:/ {if (\$1>m) m=\$1 }END{print m}'`;
                          my $num_hlu_end = $num_hlu + 1;
                          my $num_lun = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38 lun -list -name $mon_volume-1 -uid | awk \'\$1~/LOGICAL/ \{print \$4\}\'`;
                          chomp ($num_lun);
                          my $num_uid = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38 getlun $num_lun | awk \'/^UID/ \{print \$2\}\' | sed -e s/\://g | tr A-Z a-z`;
                          chomp ($num_uid);
                          print "Volume :$mon_volume\n Lun:$num_lun \n Hlu:$num_hlu_end \n UID:$num_uid \n";
                          my $num_stroreage = `/opt/Navisphere/bin/naviseccli -h 172.23.238.38 storagegroup -addhlu -gname FBVPA001 -hlu $num_hlu_end -alu $num_lun`;
                          &commande_Vplex($num_uid,$num_lun,$pref,$mon_volume,$ldev);
                }
                else {
                     print "\nOn continue\n";
                     return "next";
                }
}
sub action_vnxG {               ######################## fonction de creation des ldev Vnx Bat G ##########################
                  my ($taille,$pool,$mon_volume,$pref,$ldev,$baie,$lunid) = @_;
                  my $sp;
                  my $cmd_recupid = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40 storagegroup -list -gname FBVPA002 | awk '\$1~/[0-9]/ && !/:/ {if (\$1>m) m=\$1;n[\$1]=\$2 }END{print n[m]}'`; #MODIF 28
                  chomp($cmd_recupid);
                  my $cmd_sp = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40  getlun $cmd_recupid | awk '/Current\ owner:/ {print \$4}'`; #MODIF 28
                  chomp ($cmd_sp);
                  if ($cmd_sp eq "A"){$sp = "B";}
                  elsif ($cmd_sp eq "B"){ $sp = "A";}
                  my $commande_creat_G = "/opt/Navisphere/bin/naviseccli -h 172.23.238.40 lun -create -type nonThin -capacity $taille -sq bc -poolId $pool -sp $sp -aa 1 -name $mon_volume-0 -tieringPolicy autoTier -initialTier highestAvailable";
                  print "\n\nRecapitulatif: LEDV : $ldev Baie: $baie Lun de $taille Block pool $pool Nom du volume: $mon_volume \n\n";
                  print "Affichage de la commande:\n";
                  print "$commande_creat_G\n";
                  print "\n\n####Voulez Vous créer le Ldev $ldev sur la VNX du Batiment G###\n";
                  print "Reponse y/n ou q pour quitter le programme :  ";
                        my $input = <STDIN>;
                        chomp $input;
                        if ($input =~ m/^[Q]$/i){
                                        print "Exit du programme\n";
                                        exit(0);
                        }
                        elsif($input =~ m/^[Y]$/i)
                        {
                          print "\n\n######Creation des fichiers VNX BatG######\n";
                          print "Execution Verification VNX G....\n";
                          my $cmd = `$commande_creat_G`;
                          print $cmd;
                          my $num_hlu = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40 storagegroup -list -gname FBVPA002 | awk '\$1~/[0-9]/ && !/:/ {if (\$1>m) m=\$1 }END{print m}'`;
                          my $num_hlu_end = $num_hlu + 1;
                          my $num_lun = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40 lun -list -name $mon_volume-0 -uid | awk \'\$1~/LOGICAL/ \{print \$4\}\'`;
                          chomp ($num_lun);
                          my $num_uid = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40 getlun $num_lun | awk \'/^UID/ \{print \$2\}\' | sed -e s/\://g | tr A-Z a-z`;
                          chomp ($num_uid);
                          print "Volume :$mon_volume\n Lun:$num_lun \n Hlu:$num_hlu_end \n UID:$num_uid \n";
                          my $num_stroreage = `/opt/Navisphere/bin/naviseccli -h 172.23.238.40 storagegroup -addhlu -gname FBVPA002 -hlu $num_hlu_end -alu $num_lun`;
                          &commande_Vplex($num_uid,$num_lun,$pref,$mon_volume,$ldev);
                        }
                         else {
                            print "\nOn continue\n";
                            return "next";
                        }
}


sub commande_Vplex {
        my ($l_num_uid,$l_num_lun,$l_pref,$nom_vol,$l_ldev) = @_;
        my ($OX1,$OX2,$OX3) = split /:/, $l_ldev;
        if ($l_pref eq "I"){
                my $command_redisco = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/array+re-discover\" -X POST  -d \"{\\\"args\\\":\\\"-a /clusters/cluster-1/storage-elements/storage-arrays/*0075 -c cluster-1 -f\\\"}\"";
                my $cmd_redisco = `$command_redisco`;
                print "$cmd_redisco\n";
                my $lun_claim = sprintf ('%05.d',$l_num_lun);
                my $command_claim = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/storage-volume+claim\"  -X POST -d \"{\\\"args\\\":\\\"-n VCKM00152300075-$lun_claim -d VPD83T3:$l_num_uid -f\\\"}\"";
               print "$command_claim\n";
                sleep(3);
                my $cmd_claim = `$command_claim`;
                print "$cmd_claim\n";
                my $command_extend = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/extent+create\" -X POST  -d \"{\\\"args\\\":\\\"-d VCKM00152300075-$lun_claim\\\"}\"";
                my $cmd_extend = `$command_extend`;
                print "$cmd_extend\n";
                my $command_device = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/local-device+create\" -X POST  -d \"{\\\"args\\\":\\\"-n $VM"."_VCKM00152300075-"."$lun_claim"."_VSP$OX2$OX3"." -g raid-0 -e extent_VCKM00152300075-$lun_claim"."_1 -f\\\"}\"";
                my $cmd_device = `$command_device`;
                print "$cmd_device\n";
        }
	        elsif($l_pref eq "G"){
                my $command_redisco = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/array+re-discover\" -X POST -d \"{\\\"args\\\":\\\"-a /clusters/cluster-2/storage-elements/storage-arrays/*0074 -c cluster-2 -f\\\"}\"";
                my $cmd_redisco = `$command_redisco`;
                print "$cmd_redisco\n";
                my $lun_claim = sprintf ('%05.d',$l_num_lun);
                my $command_claim = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/storage-volume+claim\" -X POST -d \"{\\\"args\\\":\\\"-n VCKM00152300074-$lun_claim -d VPD83T3:$l_num_uid -f\\\"}\"";
                sleep(3);
                my $cmd_claim = `$command_claim`;
                print "$cmd_claim\n";
                my $command_extend = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/extent+create\" -X POST  -d \"{\\\"args\\\":\\\"-d VCKM00152300074-$lun_claim\\\"}\"";
                my $cmd_extend = `$command_extend`;
                print "$cmd_extend\n";
                my $command_device = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/local-device+create\" -X POST  -d \"{\\\"args\\\":\\\"-n $VM"."_VCKM00152300074-"."$lun_claim"."_VSP$OX2$OX3"." -g raid-0 -e extent_VCKM00152300074-$lun_claim"."_1 -f\\\"}\"";
                my $cmd_device = `$command_device`;
                print "$cmd_device\n";
        }
}









sub addLock() {
        my $baie = shift;
        my $ret = 1;
        my $retcode=0;
        my $lock_inst;
        $lock_inst = 1839 if ($baie == "85183");
        $lock_inst = 3179 if ($baie == "53317");

        my $cmd="raidcom get resource -s '$baie' -ITC$lock_inst -login maintenance raid-mainte | grep \"Locked\"";
        $ret = system( $cmd );
        if ($ret == 0) {
                print("######################################################################\n");
                print("ECHEC : Baie $baie deja lockee, merci de re-essayer plus tard !!\n");
                print fichierlog ("ECHEC : Baie $baie deja lockee, merci de re-essayer plus tard !!\n");
                print("Les informations necessaires sont dans le fichier de log \n");
                print "Voulez vous essayer de nouveau?\n";
                print "Reponse Y/N : ";
                my $input_lock = <STDIN>;
                chomp $input_lock;
                while (($input_lock ne "Y")&&($input_lock ne "N")&&($input_lock ne "y")&&($input_lock ne "n")){
                        print "Merci de saisir la bonne valeur Y/N :";
                        $input_lock = <STDIN>;
                        chomp $input_lock;
                }
                        if (($input_lock eq "N")|| ($input_lock eq "n")){
                                print("######################################################################\n");
                                print "Attention encapsulation à refaire car baie lockée\n";
                                print("######################################################################\n");
                                print fichierlog ("Attention encapsulation à refaire car baie lockée\n");
                                $retcode = 1;
                        }
                        elsif (($input_lock eq "Y")|| ($input_lock eq "y")){
                                $retcode = 2;

                        }



        } else {
                print("Pose du lock sur la baie $baie\n") if $optVerbose;
                my $cmd="raidcom lock resource -resource_name meta_resource -s '$baie' -ITC$lock_inst -login maintenance raid-mainte";
                my $ret_lock = system( $cmd );
                if ($ret_lock == 0) {
                        print("Pose du lock OK.\n");
                        $retcode = 0;
                } else {
                        print("ECHEC : impossible de poser un verrou.\n");
                         print fichierlog ("ECHEC : impossible de poser un verrou !!\n");
                        $retcode = 1;
                }
        }
        return $retcode;
}


sub delLock() {
        my $baie = shift;
        my $ret = 1;
        my $lock_inst;
        $lock_inst = 1839 if ($baie == "85183");
        $lock_inst = 3179 if ($baie == "53317");

        print("Suppression du lock sur la baie $baie\n") if $optVerbose;
        my $cmd="raidcom unlock resource -resource_name meta_resource -s '$baie' -ITC$lock_inst -login maintenance raid-mainte";
        $ret = system( $cmd );
        if ($ret == 0) {
                print("Suppression du lock OK.\n");
        } else {
                print("ECHEC : impossible de supprimer le verrou.\n");
                exit(1);
        }
}


sub addvolumevsptovplex {
        my ($l_dev,$l_baies,$l_lunid,$l_nomdevice) = @_;
        my $vplex;
        my $monfic;
        my $operation;
        my $inst;
        chomp ($l_lunid);
        print "Volume to vplex\n";
        $inst = 1839 if ($l_baies == "85183");
        $inst = 3179 if ($l_baies == "53317");

#        print fichierlog "###########################   Ajout du volume dans les 4 hostgroups sur les VSP        ################################################\n";
        print "Lock baie $l_baies\n";
#        print fichierlog "Lock baie $l_baies\n";
        my $command_vsp0 = "export HORCMINST=$inst; raidcom add lun -port 'CL1-B' 'HG_MIGEMC_1B' -ldev_id '$l_dev' -s '$l_baies'";
#        print fichierlog "$command_vsp0\n";
        my $command_vsp1 = "export HORCMINST=$inst; raidcom add lun -port 'CL2-B' 'HG_MIGEMC_2B' -ldev_id '$l_dev' -s '$l_baies'";
#        print fichierlog "$command_vsp1\n";
        my $command_vsp2 = "export HORCMINST=$inst; raidcom add lun -port 'CL5-D' 'HG_MIGEMC_5D' -ldev_id '$l_dev' -s '$l_baies'";
#        print fichierlog "$command_vsp2\n";
        my $command_vsp3 = "export HORCMINST=$inst; raidcom add lun -port 'CL6-D' 'HG_MIGEMC_6D' -ldev_id '$l_dev' -s '$l_baies'";
#        print fichierlog "$command_vsp3\n";

        my $retour_lock = &addLock($l_baies);            ##################Lock baie HDS#######################
        while ($retour_lock == 2){
                $retour_lock = &addLock($l_baies);            ##################Lock baie HDS#######################
        }

        if ($retour_lock == 0 ){
                my $cmd_vsp0 =`$command_vsp0`;          #################### Ajout Lun dans Hostgroup VSP  #########
                if (!(grep /will be used for adding/,$cmd_vsp0)) { print "Erreur Baie HDS on sort du script\n";&delLock($l_baies);exit(0);}
#                print fichierlog "$cmd_vsp0\n";
                my $cmd_vsp1 =`$command_vsp1`;
                if (!(grep /will be used for adding/,$cmd_vsp1)) { print "Erreur Baie HDS on sort du script\n";&delLock($l_baies);exit(0);}
#                print fichierlog "$cmd_vsp1\n";
                my $cmd_vsp2 =`$command_vsp2`;
                if (!(grep /will be used for adding/,$cmd_vsp2)) { print "Erreur Baie HDS on sort du script\n";&delLock($l_baies);exit(0);}
#                print fichierlog "$cmd_vsp2\n";
                my $cmd_vsp3 =`$command_vsp3`;
                if (!(grep /will be used for adding/,$cmd_vsp3)) { print "Erreur Baie HDS on sort du script\n";&delLock($l_baies);exit(0);}
#                print fichierlog "$cmd_vsp3\n";
                $operation = 1;
        }
#       else {exit(0);}
        else {next;}
&delLock($l_baies) if ($operation == 1);        ##################Unlock baie#########################

        ##########################      refresh Vplex plus claim du volume              #########################################################
        my ($OX1,$OX2,$OX3) = split /:/, $l_dev;
        ########        recuperation du SID vplex du volume ########
        if ($l_baies == "85183"){
                 my $command_redisco = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/array+re-discover\" -X POST  -d \"{\\\"args\\\":\\\"-a /clusters/cluster-1/storage-elements/storage-arrays/*85183 -c cluster-1 -f\\\"}\"";
                 my $cmd_redisco = `$command_redisco`;
#                 print fichierlog "$command_redisco\n";
#                 print fichierlog "$cmd_redisco\n";
                 my $command_sid = `curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/clusters/cluster-1/storage-elements/storage-arrays/HITACHI-OPEN-V-$l_baies/logical-units\" | grep -i $OX2$OX3`;
                 chomp $command_sid;
                 my (undef,undef,undef,$SID,undef) = split /"/,$command_sid;
                 print "mon SID = $SID\n";
                 my $command_claim = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/storage-volume+claim\"  -X POST -d \"{\\\"args\\\":\\\"-n VSP$l_baies"."_"."$OX2$OX3 -d $SID -f\\\"}\"";
#                 print fichierlog "$command_claim\n";
                 my $cmd_claim = `$command_claim`;
#                 print fichierlog "$cmd_claim\n";
                 my $command_claim = "storage-volume claim  --thin-rebuild  -n VSP$l_baies"."_"."$OX2$OX3 -d $SID" ;
                 #print "#$command_claim#\n";
#                 print fichiervsp85183 "$command_claim\n";
                 my $command_extend = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/extent+create\" -X POST  -d \"{\\\"args\\\":\\\"-d VSP$l_baies"."_"."$OX2$OX3\\\"}\"";
#                 print fichierlog "$command_extend\n";
                 my $cmd_extent = `$command_extend`;
#                 print fichierlog "fichierlog\n";
                 my $command_extent = "extent create -d VSP$l_baies"."_"."$OX2$OX3";
                 #print "#$command_extent#\n";
#                 print fichiervsp85183 "$command_extent\n";
                 my $command_device = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/local-device+create\" -X POST  -d \"{\\\"args\\\":\\\"-n device_VSP$l_baies"."_"."$OX2$OX3"."_"."$VM -g raid-0 -e extent_VSP$l_baies"."_"."$OX2$OX3"."_1 -f\\\"}\"";
#                 print fichierlog "$command_device\n";
                 my $cmd_device = `$command_device`;
#                 print fichierlog "$cmd_device\n";
                 my $command_device = "local-device create -n device_VSP$l_baies"."_"."$OX2$OX3"."_"."$VM -g raid-0 -e extent_VSP$l_baies"."_"."$OX2$OX3"."_1";
#                print "#$command_device#\n";
#                 print fichiervsp85183 "$command_device\n";
                 my $command_volume = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/virtual-volume+create\"  -X POST  -d \"{\\\"args\\\":\\\"-r device_VSP$l_baies"."_"."$OX2$OX3"."_"."$VM -t 1 \\\"}\"";
#                 print fichierlog "$command_volume\n";
                 my $cmd_volume = `$command_volume`;
#                 print fichierlog "$cmd_volume\n";
                 my $command_volume = "virtual-volume create --device device_VSP$l_baies"."_"."$OX2$OX3"."_"."$VM --set-tier 1";
                 #print "#$command_volume#";
#                 print fichiervsp85183 "$command_volume\n";
		  my $command_rename = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/set\"  -X POST  -d \"{\\\"args\\\":\\\"-a /clusters/cluster-1/virtual-volumes/device_VSP$l_baies"."_"."$OX2$OX3"."_"."$VM"."_vol::name -v $l_nomdevice -f\\\"}\"";
#                 print fichierlog "$command_rename\n";
                 my $cmd_rename = `$command_rename`;
                 print $cmd_rename;
#                 print fichierlog "$cmd_rename\n";
#                 print fichierlog "################encapsulation du ldev:$l_dev de la baie $l_baies ####################\n";
                 print "################encapsulation du ldev:$l_dev de la baie $l_baies -> $l_nomdevice OK ####################\n";
                 #print fichierlog "$command_claim\n$command_extent\n$command_device\n$command_volume\n";
        }
	 if ($l_baies == "53317"){
                my $command_redisco = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/array+re-discover\" -X POST  -d \"{\\\"args\\\":\\\"-a /clusters/cluster-2/storage-elements/storage-arrays/*53317 -c cluster-2 -f\\\"}\"";
                 my $cmd_redisco = `$command_redisco`;
#                 print fichierlog "$command_redisco";
#                 print fichierlog "$cmd_redisco\n";
                 my $command_sid = `curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/clusters/cluster-2/storage-elements/storage-arrays/HITACHI-OPEN-V-$l_baies/logical-units\" | grep -i $OX2$OX3`;
                 chomp $command_sid;
                 my (undef,undef,undef,$SID,undef) = split /"/,$command_sid;
                 print "mon SID = $SID\n";
                 my $command_claim = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/storage-volume+claim\"  -X POST -d \"{\\\"args\\\":\\\"-n VSP$l_baies"."_"."$OX2$OX3 -d $SID -f\\\"}\"";
#                 print fichierlog "$command_claim\n";
                 my $cmd_claim = `$command_claim`;
#                 print fichierlog "$cmd_claim\n";
                 my $command_claim = "storage-volume claim  --thin-rebuild  -n VSP$l_baies"."_"."$OX2$OX3 -d $SID" ;
                 #print "#$command_claim#\n";
#                 print fichiervsp53317 "$command_claim\n";
                 my $command_extend = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/extent+create\" -X POST  -d \"{\\\"args\\\":\\\"-d VSP$l_baies"."_"."$OX2$OX3\\\"}\"";
#                 print fichierlog "$command_extend\n";
                 my $cmd_extent = `$command_extend`;
#                 print fichierlog "fichierlog\n";
                 my $command_extent = "extent create -d VSP$l_baies"."_"."$OX2$OX3";
                 #print "#$command_extent#\n";
#                 print fichiervsp53317 "$command_extent\n";
                 my $command_device = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/local-device+create\" -X POST  -d \"{\\\"args\\\":\\\"-n device_VSP$l_baies"."_"."$OX2$OX3"."_"."$VM -g raid-0 -e extent_VSP$l_baies"."_"."$OX2$OX3"."_1 -f\\\"}\"";
#                 print fichierlog "$command_device\n";
                 my $cmd_device = `$command_device`;
#                 print fichierlog "$cmd_device\n";
                 my $command_device = "local-device create -n device_VSP$l_baies"."_"."$OX2$OX3"."_"."$VM -g raid-0 -e extent_VSP$l_baies"."_"."$OX2$OX3"."_1";
#                print "#$command_device#\n";
#                 print fichiervsp53317 "$command_device\n";
                 my $command_volume = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge  \"https://FBVPA001/vplex/virtual-volume+create\"  -X POST -d \"{\\\"args\\\":\\\"-r device_VSP$l_baies"."_"."$OX2$OX3"."_"."$VM -t 1 \\\"}\"";
#		 print fichierlog "$command_volume\n";
                 my $cmd_volume = `$command_volume`;
#                 print fichierlog "$cmd_volume\n";
                 my $command_volume = "virtual-volume create --device device_VSP$l_baies"."_"."$OX2$OX3"."_"."$VM --set-tier 1";
#                 print fichiervsp53317 "$command_volume\n";
                 my $command_rename = "curl -s -k -H Username:service -H Password:Vplex4St0r\@ge \"https://FBVPA001/vplex/set\"  -X POST  -d \"{\\\"args\\\":\\\"-a /clusters/cluster-2/virtual-volumes/device_VSP$l_baies"."_"."$OX2$OX3"."_"."$VM"."_vol::name -v $l_nomdevice -f\\\"}\"";
#                 print fichierlog "$command_rename\n";
                 my $cmd_rename = `$command_rename`;
                 print $cmd_rename;
#                 print fichierlog "$cmd_rename\n";
#                 print fichierlog "################encapsulation du ldev:$l_dev de la baie $l_baies ####################\n";
                 print "################encapsulation du ldev:$l_dev de la baie $l_baies -> $l_nomdevice OK ####################\n";
                #print fichierlog "$command_claim\n$command_extent\n$command_device\n$command_volume\n";
        }

}



