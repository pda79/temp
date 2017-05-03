=pod

=head1 NOM

- Module commun contenant les fonctions de bases

=head1 SYNOPSIS


=head1 DESCRIPTION

Module commun contenant les fonctions de bases néssaires àa gestion de la base de donné san

=head2 Fonctions

=over 4

=item connexion_base_san($l_base)

Connexion àa base de donné passéen paramèe.
Cette fonction n'est pas appeléirectement par le programme, mais par l'interméare
des difféntes fonctions de gestion des bases de donné (ajout, suppression, mise àour, ...).
Un objet global est créC<$::dbh> et utiliséar la fonction appelante et déuit àa fin du traitement
par la fonction C<deconnexion_base_san()>.

=item deconnexion_base_san()

Desctructeur du handler de connexion àa base de donné.
Cette fonction n'est pas appeléirectement par le programme, mais par l'interméare
des difféntes fonctions de gestion des bases de donné (ajout, suppression, mise àour, ...).
L'objet globale C<$::dbh> utiliséour l'accèàa base de donné est déuit par l'appel àette
fonction.

=back

=cut

use strict;
use DBI;
#use Net::SSH::Perl;
use Date::Manip;
use Time::Local;

use Switch;
use vars qw($separateur @baie $optVerbose);

@baie = ( "53317","85183" );
$separateur="#!#";
$optVerbose = defined $GLOBAL::optVerbose ? $GLOBAL::optVerbose : 0;

###########################################
##
## connexion_base "/var/lib/mysql/san"
##
###########################################

sub connexion_base_san
{
        my $l_base=shift;
        my $l_debug=0;
        my $l_user;
        my $l_passwd;
        my $l_host;

        print "DEB CONNEXION_BASE : $l_base\n" if ( $l_debug ne '0' );

        if ( $l_base eq "san" ) {
                $l_user="san";
                $l_passwd="71q13&3";
                $::dbh=DBI->connect("DBI:mysql:database=san;host=slapp370a",$l_user,$l_passwd) or die "Connection at data base $l_base is not possible!";
        }
	elsif ($l_base eq "inv") {
		$l_user="inv";
                $l_passwd="Maif1234";
		 print "base: INV\n";
                $::dbh=DBI->connect("DBI:mysql:database=inventaire_serveurs;host=SWAPP1519;3306",$l_user,$l_passwd) or die "Connection at data base $l_base is not possible!";

	}
 #       
        
        
}

###########################################
##
## deconnexion_base
##
###########################################

sub deconnexion_base_san
{
        $::dbh->disconnect();
}

###########################################
##
## delete_row_unique_table
##
###########################################

sub delete_row_unique_table
{
        my $l_delete_table = shift;
        my $l_delete_where = shift;
        my $l_base = shift;
	my $l_multi = shift;

        my ($l_sub_ordre_sql,$l_info_supp,$l_requete);
        my (@l_tab);
        my $l_debug = 0;

	if ( !defined $l_base || $l_base eq "" ) {
		$l_base="san";
	}

        if ( $l_delete_where ne "" ) {
                $l_info_supp.=" WHERE $l_delete_where";
        }

        $l_requete="DELETE FROM $l_delete_table $l_info_supp";
        print "$l_requete\n" if ( $l_debug != 0 );

	@l_tab=selection_table("$l_delete_table",'*',"$l_delete_where",undef,undef,"$l_base");
	die "Trop d'enregistrement ( $#l_tab ) a supprimer : $l_delete_where \n" if ( $#l_tab ne 0 && ( !defined $l_multi || $l_multi eq "" ) );

        connexion_base_san($l_base);

        $l_sub_ordre_sql=$::dbh->prepare("$l_requete");
        $l_sub_ordre_sql->execute();
        $l_sub_ordre_sql->finish;
        undef $l_sub_ordre_sql;

        deconnexion_base_san($l_base);
        $l_delete_table =~ s/'//g;
        $l_delete_where =~ s/'//g;
#	insertion_journal("DELETE de la table $l_delete_table : $l_delete_where"); 
}

###########################################
##
## insert_row_unique_table
##
###########################################

sub insert_row_unique_table
{
        my $l_insert_table = shift;
        my $l_insert_value = shift;
        my $l_base = shift;

        my ($l_sub_ordre_sql,$l_requete);

	if ( !defined $l_base || $l_base eq "" ) {
		$l_base="san";
	}

        $l_requete="INSERT INTO $l_insert_table VALUES ($l_insert_value)";
        print "$l_requete\n" if ( $optVerbose );
	print "$l_requete\n";

        connexion_base_san($l_base);

        $l_sub_ordre_sql=$::dbh->prepare("$l_requete");
        $l_sub_ordre_sql->execute();
        $l_sub_ordre_sql->finish;
        undef $l_sub_ordre_sql;

        deconnexion_base_san($l_base);
        $l_insert_table =~ s/'//g;
        $l_insert_value =~ s/'//g;
#	insertion_journal("INSERT dans la table $l_insert_table : $l_insert_value"); 
}

###########################################
##
## update_row_unique_table
##
###########################################

sub update_row_unique_table
{
        my $l_update_table = shift;
        my $l_update_value = shift;
        my $l_update_where = shift;
        my $l_base = shift;

        my ($l_sub_ordre_sql,$l_requete);
        my $l_debug = 0;

	if ( !defined $l_base || $l_base eq "" ) {
		$l_base="san";
	}

        $l_requete="UPDATE $l_update_table SET $l_update_value WHERE $l_update_where";
        print "$l_requete\n" if ( $l_debug != 0 );

        connexion_base_san($l_base);

        $l_sub_ordre_sql=$::dbh->prepare("$l_requete");
        $l_sub_ordre_sql->execute();
        $l_sub_ordre_sql->finish;
        undef $l_sub_ordre_sql;

        deconnexion_base_san($l_base);

        $l_update_table =~ s/'//g;
        $l_update_value =~ s/'//g;
        $l_update_where =~ s/'//g;
#	insertion_journal("UPDATE dans la table $l_update_table : $l_update_value WHERE $l_update_where"); 
}


###########################################
##
## insertion_devices_vsp
##
###########################################

sub insertion_devices_vsp
{
        my @devices = @{(shift)};
        my $debug = shift;
#	print "debug \n@devices\n" ;
        my ($l_baie,$l_device,$l_taille,$l_taille_consum,$l_type_perf);
        my (%db_devices, %devices);

        my @db_devices = selection_table('DEVICES','baie,device,taille,taille_consum,type_perf');
        foreach ( @db_devices ){
            ($l_baie,$l_device,$l_taille,$l_taille_consum,$l_type_perf) = split /${separateur}/;
            $db_devices{${l_baie}.${separateur}.${l_device}.${separateur}.${l_taille}.${separateur}.${l_taille_consum}.${separateur}.${l_type_perf}} .= ','
                if ( $db_devices{${l_baie}.${separateur}.${l_device}.${separateur}.${l_taille}.${separateur}.${l_taille_consum}.${separateur}.${l_type_perf}} != "" );
            $db_devices{${l_baie}.${separateur}.${l_device}.${separateur}.${l_taille}.${separateur}.${l_taille_consum}.${separateur}.${l_type_perf}} .= $l_device;
        }
        undef @db_devices;

        foreach ( @devices ){
            ($l_baie,$l_device,$l_taille,$l_taille_consum,$l_type_perf) = split /${separateur}/;
            $devices{${l_baie}.${separateur}.${l_device}.${separateur}.${l_taille}.${separateur}.${l_taille_consum}.${separateur}.${l_type_perf}} .= ','
                if ( $devices{${l_baie}.${separateur}.${l_device}.${separateur}.${l_taille}.${separateur}.${l_taille_consum}.${separateur}.${l_type_perf}} != "" );
            $devices{${l_baie}.${separateur}.${l_device}.${separateur}.${l_taille}.${separateur}.${l_taille_consum}.${separateur}.${l_type_perf}} .= $l_device;
        }
        undef @devices;

        my ($insert_to_db, $delete_from_db, $update_db) = check_diff(\%devices, \%db_devices);
        undef %devices;
#        undef %db_devices;

        foreach ( keys %$update_db ){
            print "UPDATING => $_ : $db_devices{$_} \t->\t $update_db->{$_}\n" if ( $debug != 0 );
            ($l_baie,$l_device,$l_taille,$l_taille_consum,$l_type_perf) = split /${separateur}/;
            $l_device = $update_db->{$_};
            update_row_unique_table("DEVICES","taille = '$l_taille', taille_consum = '$l_taille_consum', type_perf = '$l_type_perf'","baie = '$l_baie' AND device = '$l_device'") if ( $debug <= 1 );
        }

        foreach ( keys %$delete_from_db ){
            print "DELETING => $_ : $delete_from_db->{$_}\n" if ( $debug != 0 );
            ($l_baie,$l_device,$l_taille,$l_taille_consum,$l_type_perf) = split /${separateur}/;
            $l_device = $delete_from_db->{$_};
            delete_row_unique_table("DEVICES","baie = '$l_baie' AND device = '$l_device' AND taille = '$l_taille' AND type_perf = '$l_type_perf'") if ( $debug <= 1 );
        }

        foreach ( keys %$insert_to_db ){
            print "ADDING => $_ : $insert_to_db->{$_}\n" if ( $debug != 0 );
            ($l_baie,$l_device,$l_taille,$l_taille_consum,$l_type_perf) = split /${separateur}/;
            $l_device = $insert_to_db->{$_};
            insert_row_unique_table("DEVICES","'$l_baie','$l_device','$l_taille','$l_taille_consum','$l_type_perf'") if ( $debug <= 1 );
        }
}
###########################################
##
##
## 	Insertion volume Vipr dans base inventaire serveur
##
###########################################

sub insertion_devices_vipr
{
	#my @value = @{(shift)};
	my @value = @_;
        my ($l_volume,$l_label,$l_wwn,$l_urn,$vpool,$l_taille);
        my (%db_value, %value);


	connexion_base_san("inv");
	print "Delete FROM stockage_disques\n";
	my $l_sub_ordre_sql=$::dbh->prepare("DELETE FROM stockage_disques WHERE baie = 'EMC'");
	        $l_sub_ordre_sql->execute();
	  $l_sub_ordre_sql->finish;
	        undef $l_sub_ordre_sql;
	deconnexion_base_san();

        foreach ( @value){
#            print "ADDING => $_ : $insert_to_db->{$_}\n"; # if ( $optVerbose );
            ($l_volume,$l_label,$l_wwn,$l_urn,$vpool,$l_taille) = split /${separateur}/;
            insert_row_unique_table("stockage_disques","'EMC','$l_volume','$l_label','$l_wwn','$l_urn','$vpool','$l_taille'","inv") if ( $optVerbose <= 1 );
        }



}
###########################################
##
##
##      Insertion host Vipr dans base inventaire serveur
##
###########################################

sub insertion_hosts_vipr
{
	my @value = @_;
        my ($l_export,$l_volume);
        my (%db_value, %value);


        connexion_base_san("inv");
        print "Delete FROM stockage_host\n";
        my $l_sub_ordre_sql=$::dbh->prepare("DELETE FROM stockage_host WHERE baie = 'EMC'");
        $l_sub_ordre_sql->execute();
        $l_sub_ordre_sql->finish;
        undef $l_sub_ordre_sql;
        deconnexion_base_san();
        foreach ( @value){
#            print "ADDING => $_ : $insert_to_db->{$_}\n"; # if ( $optVerbose );
            ($l_export,$l_volume) = split /${separateur}/;
            insert_row_unique_table("stockage_host","'EMC','$l_export','$l_volume'","inv") if ( $optVerbose <= 1 );
        }
}

###########################################
##
##
##      Insertion  host HUSVM dans base inventaire serveur
##
###########################################

sub insertion_hosts_husvm{

	my @value = @_;
        my ($l_export,$l_volume);
        my (%db_value, %value);


        connexion_base_san("inv");
        print "Delete FROM stockage_host\n";
        my $l_sub_ordre_sql=$::dbh->prepare("DELETE FROM stockage_host WHERE baie = 'HUSVM'");
	$l_sub_ordre_sql->execute();
        $l_sub_ordre_sql->finish;
        undef $l_sub_ordre_sql;
        deconnexion_base_san();
        foreach ( @value){
#            print "ADDING => $_ : $insert_to_db->{$_}\n"; # if ( $optVerbose );
            ($l_export,$l_volume) = split /${separateur}/;
            insert_row_unique_table("stockage_host","'HUSVM','$l_export','$l_volume'","inv") if ( $optVerbose <= 1 );
        }




}


###########################################
##
##
##      Insertion  device HUSVM dans base inventaire serveur
##
###########################################

sub insertion_devices_husvm {

 #my @value = @{(shift)};
        my @value = @_;
        my ($l_volume,$urn,$vpool,$l_taille);
        my (%db_value, %value);


        connexion_base_san("inv");
        print "Delete FROM stockage_disques\n";
        my $l_sub_ordre_sql=$::dbh->prepare("DELETE FROM stockage_disques WHERE baie = 'HUSVM'");
        $l_sub_ordre_sql->execute();
        $l_sub_ordre_sql->finish;
        undef $l_sub_ordre_sql;
        deconnexion_base_san();

        foreach ( @value){
#            print "ADDING => $_ : $insert_to_db->{$_}\n"; # if ( $optVerbose );
            ($l_volume,$urn,$vpool,$l_taille) = split /${separateur}/;
            insert_row_unique_table("stockage_disques","'HUSVM','$l_volume','N/A','N/A','$urn','$vpool','$l_taille'","inv") if ( $optVerbose <= 1 );
        }



}




###########################################
##
## insertion_pool_vsp
##
###########################################

sub insertion_pool_vsp
     {
            my @pool_vsp = @{(shift)};
             print "debug \n@pool_vsp\n" if ( $optVerbose > 1 );
    
            foreach ( @pool_vsp ){
                 my ($l_baie,$l_id,$l_capacity_all,$l_capacity_free,$l_taux_occup,$l_nb_vvol,$l_capacity_aloue,$l_taux_suralloc,$l_time) = split /${separateur}/;
                 #$l_time = UnixDate("$l_time", "%s");
		 	
                 #$l_response = $l_response/1000;
                 print "ADDING => $_ : $l_baie,$l_id,$l_capacity_all,$l_capacity_free,$l_taux_occup,$l_nb_vvol,$l_capacity_aloue,$l_taux_suralloc,$l_time\n" if ( $optVerbose );
                 insert_row_unique_table("CAPACITY","'$l_baie','$l_id','$l_capacity_all','$l_capacity_free','$l_taux_occup','$l_nb_vvol','$l_capacity_aloue','$l_taux_suralloc',now()") if ( $optVerbose <= 1 );
             	

		}
     }



###########################################
##
## insertion_nas_emc
##
###########################################

sub insertion_treequota
     {
            my @treequota = @{(shift)};
             print "debug \n@treequota\n" if ( $optVerbose > 1 );

            foreach ( @treequota ){
                 my ($l_fs,$l_qtree,$l_quota,$l_usage_vol) = split /${separateur}/;
                 #$l_time = UnixDate("$l_time", "%s");

                 #$l_response = $l_response/1000;
                 print "ADDING => $_ : $l_fs,$l_qtree,$l_quota,$l_usage_vol\n" if ( $optVerbose );
                 insert_row_unique_table("supervision","'$l_fs','$l_qtree','$l_quota','$l_usage_vol',now()") if ( $optVerbose <= 1 );


                }
     }




###########################################
##
## insertion_devices_response_time
##
###########################################

sub insertion_devices_response_time
{
        my @data = @{(shift)};
        print "debug \n@data\n" if ( $optVerbose > 1 );

        foreach ( @data ){
            my ($l_device,$l_time,$l_response,$l_baie) = split /,/;
            #$l_time = UnixDate("$l_time", "%s");
            $l_response = $l_response/1000;
	  #  my ($year,$mon,$mday,$hour,$min,$sec) = split(/[\s\/:]+/, $l_time);	
	  #  my $time = timelocal($sec,$min,$hour,$mday,$mon-1,$year);
	    print "ADDING => $_ : $l_baie,$l_device,$l_time,$l_response\n" if ( $optVerbose );	
	    insert_row_unique_table("LDEV_RES_TIME","'$l_device','$l_time','$l_response','$l_baie'") if ( $optVerbose <= 1 );
    
    }
}

###########################################
##
## Insertion Parity Group
##
###########################################

sub insertion_parity_group
{
	my @data = @{(shift)};
        print "debug \n@data\n" if ( $optVerbose > 1 );

        foreach ( @data ){
		#print "@insert\n";
            #$l_time = UnixDate("$l_time", "%s");
            print "ADDING => $_\n" if ( $optVerbose );
            insert_row_unique_table("PARITY_GROUP","$_") if ( $optVerbose <= 1 );
        }
	



}
###########################################
###
### Insertion Port_iops
###
############################################
#
sub insertion_port_iops
{
        my @data = @{(shift)};
        print "debug \n@data\n" if ( $optVerbose > 1 );

        foreach ( @data ){
print "ADDING => $_\n" if ( $optVerbose );
            insert_row_unique_table("Port_iops","$_") if ( $optVerbose <= 1 );
        }




}

###########################################
####
#### Insertion Port_debits
####
#############################################
##
#

sub insertion_port_debit
{
        my @data = @{(shift)};
        print "debug \n@data\n" if ( $optVerbose > 1 );

        foreach ( @data ){
        print "ADDING => $_\n" if ( $optVerbose );
            insert_row_unique_table("Port_debit","$_") if ( $optVerbose <= 1 );
        }




}




###########################################
##
## insertion_hostgroup_vsp
##
###########################################

sub insertion_hostgroup_vsp
{
        my @hostgroup = @{(shift)};
        my $debug = shift;

        #my ($l_baie,$l_device,$l_taille,$l_type_perf);
	my ($l_baie,$l_hostgroup,$l_port_name,$l_hostmode,$l_device,$l_wwn);
	#my (%db_hostgroup,%hostgroup,%devices);
	my (%db_hostgroup,%hostgroup);

        my @db_hostgroup = selection_table('HOSTGROUP','baie,device,hostgroup,port_name,hostmode,wwn');
        foreach ( @db_hostgroup ){
            ($l_baie,$l_device,$l_hostgroup,$l_port_name,$l_hostmode,$l_wwn) = split /${separateur}/;
            #$db_hostgroup{${l_baie}.${separateur}.${l_device}.${separateur}.${l_hostgroup}.${separateur}.${l_port_name}.${separateur}.${l_hostmode}.${separateur}.${l_wwn}} .= ','
                #if ( $db_hostgroup{${l_baie}.${separateur}.${l_device}.${separateur}.${l_hostgroup}.${separateur}.${l_port_name}.${separateur}.${l_hostmode}.${separateur}.${l_wwn}} != "" );
            #$db_hostgroup{${l_baie}.${separateur}.${l_device}.${separateur}.${l_hostgroup}.${separateur}.${l_port_name}.${separateur}.${l_hostmode}.${separateur}.${l_wwn}} .= $l_hostgroup;
            $db_hostgroup{${l_baie}.${separateur}.${l_device}.${separateur}.${l_hostgroup}.${separateur}.${l_port_name}.${separateur}.${l_hostmode}.${separateur}.${l_wwn}} = $l_device;
            print "DB_HOSTGROUP:${l_baie} ${l_device} ${l_hostgroup}\n" if ( $optVerbose );
        }
        undef @db_hostgroup;

        foreach ( @hostgroup ){
            ($l_baie,$l_device,$l_hostgroup,$l_port_name,$l_hostmode,$l_wwn) = split /${separateur}/;
            #$hostgroup{${l_baie}.${separateur}.${l_device}.${separateur}.${l_hostgroup}.${separateur}.${l_port_name}.${separateur}.${l_hostmode}.${separateur}.${l_wwn}} .= ','
                #if ( $db_hostgroup{${l_baie}.${separateur}.${l_device}.${separateur}.${l_hostgroup}.${separateur}.${l_port_name}.${separateur}.${l_hostmode}.${separateur}.${l_wwn}} != "" );
            #$db_hostgroup{${l_baie}.${separateur}.${l_device}.${separateur}.${l_hostgroup}.${separateur}.${l_port_name}.${separateur}.${l_hostmode}.${separateur}.${l_wwn}} .= $l_hostgroup;
            $hostgroup{${l_baie}.${separateur}.${l_device}.${separateur}.${l_hostgroup}.${separateur}.${l_port_name}.${separateur}.${l_hostmode}.${separateur}.${l_wwn}} = $l_device;
            print "LOCAL_HOSTGROUP:${l_baie} ${l_device} ${l_hostgroup}\n" if ( $optVerbose );
	}
	undef @hostgroup;
	print "DB_HOSTGROUP:#" . scalar(keys %db_hostgroup) ."\nLOCAL_HOSTGROUP:#" . scalar(keys %hostgroup) . "\n" if ( $optVerbose );
        

	#print "Press ENTER to continue..."if ( $optVerbose );
#	<STDIN>;
	my ($insert_to_db, $delete_from_db, $update_db) = check_diff(\%hostgroup, \%db_hostgroup);
#	print "Press ENTER to continue..."if ( $optVerbose );
#	<STDIN>;
        undef %hostgroup;
#        undef %db_hostgroup;

        foreach ( keys %$update_db ){
            print "UPDATING => $_ : $db_hostgroup{$_} \t->\t $update_db->{$_}\n" if ( $debug != 0 );
            ($l_baie,$l_device,$l_hostgroup,$l_port_name,$l_hostmode,$l_wwn) = split /${separateur}/;
            #$l_device = $update_db->{$_};
            update_row_unique_table("HOSTGROUP","baie = '$l_baie'","device = '$l_device'","hostgroup = '$l_hostgroup'","port_name = '$l_port_name'","hostmode = '$l_hostmode'","wwn = '$l_wwn'") if ( $debug <= 1 );
        }

        foreach ( keys %$delete_from_db ){
            print "DELETING => $_ : $delete_from_db->{$_}\n" if ( $debug != 0 );
            ($l_baie,$l_device,$l_hostgroup,$l_port_name,$l_hostmode,$l_wwn) = split /${separateur}/;
            #$l_device = $delete_from_db->{$_};
            delete_row_unique_table("HOSTGROUP","baie = '$l_baie' AND device = '$l_device' AND hostgroup = '$l_hostgroup' AND port_name ='$l_port_name' AND hostmode = '$l_hostmode' AND wwn = '$l_wwn'") if ( $debug <= 1 );
        }

        foreach ( keys %$insert_to_db ){
            print "ADDING => $_ : $insert_to_db->{$_}\n" if ( $debug != 0 );
            ($l_baie,$l_device,$l_hostgroup,$l_port_name,$l_hostmode,$l_wwn) = split /${separateur}/;
            #$l_device = $insert_to_db->{$_};
            insert_row_unique_table("HOSTGROUP","'$l_baie','$l_device','$l_hostgroup','$l_port_name','$l_hostmode','$l_wwn'") if ( $debug <= 1 );
        }
}

###########################################
##
## insertion_rdf
##
###########################################

sub insertion_rdf
{
        my $l_baie_r1=shift;
        my $l_device_r1=shift;
        my $l_baie_r2=shift;
        my $l_device_r2=shift;
        my $l_type_synchro=shift;
        my $l_etat_synchro=shift;

        my $l_sub_ordre_sql;
        my $l_cpt=0;
        my $l_base = "san";

        my @row;
        
	my ($l_select_baie_r1, $l_select_device_r1, $l_select_baie_r2, $l_select_device_r2, $l_select_type_synchro, $l_select_etat_synchro);
        my @l_membres;

        print "INSERTION_RDF : $l_baie_r1, $l_device_r1, $l_baie_r2, $l_device_r2, $l_type_synchro, $l_etat_synchro\n" if ( $optVerbose > 1 );

        connexion_base_san($l_base);

        print "SELECT baie_r1,device_r1,baie_r2,device_r2,type_synchro,etat_synchro FROM RDF WHERE baie_r1 = '$l_baie_r1' AND device_r1 = '$l_device_r1'\n" if ( $optVerbose > 1 );
        $l_sub_ordre_sql=$::dbh->prepare("SELECT baie_r1,device_r1,baie_r2,device_r2,type_synchro,etat_synchro FROM RDF WHERE baie_r1 = '$l_baie_r1' AND device_r1 = '$l_device_r1'");
        $l_sub_ordre_sql->execute();

        while (my @row = $l_sub_ordre_sql->fetchrow_array()) {
                ($l_select_baie_r1, $l_select_device_r1, $l_select_baie_r2, $l_select_device_r2, $l_select_type_synchro, $l_select_etat_synchro) = @row;
                $l_cpt++;
        }

        $l_sub_ordre_sql->finish;
        undef $l_sub_ordre_sql;

        deconnexion_base_san($l_base);

        die "Problèans la table RDF : $l_baie_r1 $l_device_r1\n" if ( $l_cpt > 1 );

        if ( $l_cpt == 0 ) {
                connexion_base_san($l_base);
                $::dbh->do("INSERT INTO RDF ( baie_r1, device_r1, baie_r2, device_r2, type_synchro, etat_synchro ) VALUES ( '$l_baie_r1','$l_device_r1','$l_baie_r2','$l_device_r2','$l_type_synchro','$l_etat_synchro')");
                deconnexion_base_san($l_base);
                insertion_journal("Insertion RDF : Baie_r1=$l_baie_r1, Device_r1=$l_device_r1, Baie_r2=$l_baie_r2, Device_r2=$l_device_r2, Etat_synchro=$l_etat_synchro, Type_synchro=$l_etat_synchro");
        }
        else {
                print "$l_select_baie_r1, $l_select_device_r1, $l_select_baie_r2, $l_select_device_r2, $l_select_type_synchro, $l_select_etat_synchro\n" if ( $optVerbose > 1 );

                mise_a_jour_information_table('RDF','baie_r1',$l_baie_r1,'device_r1',$l_device_r1,'baie_r2',$l_baie_r2,$l_select_baie_r2) if ( $l_select_baie_r2 ne $l_baie_r2 && $l_baie_r2 ne '' );
                mise_a_jour_information_table('RDF','baie_r1',$l_baie_r1,'device_r1',$l_device_r1,'device_r2',$l_device_r2,$l_select_device_r2) if ( $l_select_device_r2 ne $l_device_r2 && $l_device_r2 ne '' );
                mise_a_jour_information_table('RDF','baie_r1',$l_baie_r1,'device_r1',$l_device_r1,'type_synchro',$l_type_synchro,$l_select_type_synchro) if ( $l_select_type_synchro ne $l_type_synchro && $l_type_synchro ne '' );
                mise_a_jour_information_table('RDF','baie_r1',$l_baie_r1,'device_r1',$l_device_r1,'etat_synchro',$l_etat_synchro,$l_select_etat_synchro) if ( $l_select_etat_synchro ne $l_etat_synchro && $l_etat_synchro ne '' );
        }
}


###########################################
##
## mise_a_jour_information_table
##
###########################################

sub mise_a_jour_information_table
{
        my ($l_table,$l_colonne_baie,$l_baie,$l_colonne_device,$l_device,$l_colonne,$l_valeur,$l_ancienne_valeur,$l_base)=@_;

	if ( $l_base eq "" ) {
		$l_base="san";
	}	

        connexion_base_san($l_base);
        $::dbh->do("UPDATE $l_table SET $l_colonne='$l_valeur' WHERE ( $l_colonne_baie=$l_baie AND $l_colonne_device='$l_device')");
        deconnexion_base_san($l_base);

	insertion_journal("Maj de la table $l_table ( $l_baie - $l_device ): Colonne=$l_colonne ( $l_ancienne_valeur --> $l_valeur )"); 
}

###########################################
##
## selection_table
##
###########################################

sub selection_table
{
        my $l_select_table = shift;
        my $l_select_column= shift;
        my $l_select_where = shift;
        my $l_select_order = shift;
        my $l_select_limit = shift;
	my $l_base = shift;	
	
        my ($l_sub_ordre_sql,$l_info_supp,$l_requete);
	my (@row,@result);
	my $debug = 1;
	if ( $l_base eq "" ) {
		$l_base="san";
	}
	
	if ( $l_select_where ne "" ) {
		$l_info_supp.=" WHERE $l_select_where";
	}
        if ( $l_select_order ne "" ) {
                $l_info_supp.=" ORDER BY $l_select_order";
        }
        if ( $l_select_limit ne "" ) {
                $l_info_supp.=" LIMIT $l_select_limit";
        }

	$l_requete="SELECT $l_select_column FROM $l_select_table $l_info_supp";
	print "$l_requete\n" if ( $debug != 0 );
	print "base:$l_base\n";
        connexion_base_san($l_base);
	print "connexion\n"; 
        $l_sub_ordre_sql=$::dbh->prepare("$l_requete");
        $l_sub_ordre_sql->execute();

        while (my @row = $l_sub_ordre_sql->fetchrow_array()) {
                push @result,join("$separateur" ,@row);
        }
        $l_sub_ordre_sql->finish;
        undef $l_sub_ordre_sql;

        deconnexion_base_san($l_base);
        return @result;
}


###########################################
##
## insertion_journal
##
###########################################

sub insertion_journal
{
        my ($l_message,$l_base)=@_;
	if ( $l_base eq "" ) {
		$l_base="san";
	}	
	my $debug = 0;

	print "$l_message\n" if ( $debug != 0 );

        connexion_base_san($l_base);
        $::dbh->do("INSERT INTO JOURNAL ( message ) VALUES ( '$l_message' )");
        deconnexion_base_san($l_base);
}


###########################################
##
## check_diff
##
###########################################
sub check_diff
{
    my $debug = 0;
    my %local_tab = %{(shift)};
    my %db_tab    = %{(shift)};
    my %db_update;
    foreach ( keys %local_tab ){
        print "local : $_ => $local_tab{$_}\n" if ( $debug == 1 );
        print "db    : $_ => $db_tab{$_}\n" if ( $debug == 1 );
        if ( $db_tab{$_} ne "" && $local_tab{$_} ne "" ){
            if ( $db_tab{$_} eq $local_tab{$_} ){
                print "SKIPPING => $_ : $local_tab{$_}\n" if ( $debug == 1 );
                delete $local_tab{$_};
                delete $db_tab{$_};
            } else {
                print "UPDATING => $_ : $db_tab{$_} -> $local_tab{$_}\n" if ( $debug == 1 );
                $db_update{$_} = $local_tab{$_};
                delete $local_tab{$_};
                delete $db_tab{$_};
            }
        }
    }
    if ( $debug == 1 ) {
        foreach ( keys %db_tab ){
            print "local : $_ => $local_tab{$_}\n";
            print "db    : $_ => $db_tab{$_}\n";
            print "DELETING => $_ : $db_tab{$_}\n";
        }
    }

    return \%local_tab, \%db_tab, \%db_update;
}

1
