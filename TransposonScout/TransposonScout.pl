use Tk;
use Tk::Dialog;
use Bio::SeqIO;
use Bio::Tools::Run::RemoteBlast;
use strict;

#Author: Prasath Pararajalinngam, Jungwha Chae, David Miao, Kenny Cheung
#Date: May 24th, 2013
#Purpose: TransposonScout code

#---------------------Global Variables---------------------------#
my $input_file;
my $species_name;
my $remote_blast_status = 0;
my $blast_parser_status = 0;
my %blast_hash;

#---------------------Input Window-------------------------------#
my $mw = MainWindow->new();
$mw->geometry("405x155");
$mw->title("TransposonScout");

my $menu = $mw->Menu();
$mw->configure(-menu => $menu);
my $file_menu = $menu->Menubutton(-label => 'File', -tearoff => 0);
$file_menu->command(-label => 'Exit', -command => sub{exit});
my $run_menu = $menu->Menubutton(-label => 'Run', -tearoff => 0);
$run_menu->command(-label => 'Run RepeatScout', -command => sub{$remote_blast_status = 0; $blast_parser_status = 0; configure_label();});
$run_menu->command(-label => 'Run RemoteBlast', -command => sub{$remote_blast_status = 1; $blast_parser_status = 0; configure_label();});
#$run_menu->command(-label => 'Run Local Blast');
$run_menu->command(-label => 'Run Blast Parser', -command => sub{$remote_blast_status = 0; $blast_parser_status = 1; configure_label();});

my $inputLabel = $mw->Label(-text => "Inputs");
$inputLabel->place(-x => 0, -y => 0);

my $sequenceLabel = $mw->Label(-text => "Select sequence (FASTA format):");
$sequenceLabel->place(-x => 0, -y => 20);

my $sequenceEntry = $mw->Entry(-textvariable => \$input_file)->place(-width => 350, -x => 20, -y => 40);

my $folder_image = $mw->Photo(-file => 'folder_icon.gif');
my $sequenceButton = $mw->Button(-image => $folder_image,
                               -command => \&toggle_file_selection);
$sequenceButton->place(-x => 373, -y => 40);

my $speciesLabel = $mw->Label(-text => "Binomial species name:");
$speciesLabel->place(-x => 0, -y => 65);

my $speciesEntry = $mw->Entry(-textvariable => \$species_name)->place(-width => 350, -x => 20, -y => 85);

my $submitButton = $mw->Button(-text => 'Submit', -command => \&check_fields)->place(-x => 170, -y => 115);

#---------------------Processing Window----------------------------#
my $processWidget = $mw->Toplevel();
$processWidget->withdraw();
$processWidget->geometry("405x100");
$processWidget->title("Processing...");

my $processText = $processWidget->Text(-width => 30, -height => 30)->pack();
my $scrlText = $processText->Scrolled('Text', -scrollbars => 'e')->pack();

$processWidget->protocol('WM_DELETE_WINDOW', [\&_destroy, $processWidget]);

#---------------------Output Window--------------------------------#
my $outputWidget = $mw->Toplevel();
$outputWidget->withdraw();
$outputWidget->geometry("1000x600");
$outputWidget->title("TranposonScout");

my $outputMenu = $outputWidget->Menu();
$outputWidget->configure(-menu => $outputMenu);
my $outputFileMenu = $outputMenu->Menubutton(-text => 'File', -tearoff => 0);
$outputFileMenu->command(-label => 'Back to Input', -command => [\&_destroy, $outputWidget]);
$outputFileMenu->command(-label => 'Exit', -command => sub{exit});

my $listFrame = $outputWidget->Frame()->pack(-side => 'left');
my $listLabel = $listFrame->Label(-text => "  Select species:")->pack(-side => 'top', -pady => 2, -anchor => 'w');
my $listBox = $listFrame->Scrolled("Listbox", -scrollbars => 'se', -height=>32, -width=>30, -selectmode => 'single')->pack(-side=>"top", -padx => 5);

my $dataFrame = $outputWidget->Frame()->pack(-side => 'left', -expand => 1, -fill => 'both', -pady => 2);
my $outputLabel = $dataFrame->Label(-text => ' Output:')->pack(-side=>'top', -pady => 2, -anchor => 'w');
my $dataTextBox = $dataFrame->Scrolled("Text", -scrollbars => 'se', -height=>32, -wrap => 'none')->pack(-side=>'top', -padx => 3, -fill => 'both', -expand => 1);

$outputWidget->protocol('WM_DELETE_WINDOW', sub {exit});

$listBox->bind('<ButtonRelease-1>', \&check_selected_item);

MainLoop;

#---------------------Subroutines--------------------------------#
sub toggle_file_selection{
    if ($blast_parser_status == 1){
        $input_file = $mw->chooseDirectory(-title => 'Select directory...',
                                           -initialdir => "./results");
        
    }else{
        $input_file = $mw->getOpenFile();
    }
}

sub configure_label{
    if ($remote_blast_status == 0 && $blast_parser_status == 0){ 
        $sequenceLabel->configure(-text => "Select sequence (FASTA format):");
    }elsif($remote_blast_status == 1 && $blast_parser_status == 0){
        $sequenceLabel->configure(-text => "Select FASTA format repeat consensus library:");
    }elsif($remote_blast_status == 0 && $blast_parser_status == 1){
        $sequenceLabel->configure(-text => "Select directory containing XML format BLAST reports:");
    }
}

sub check_fields{
    if (!$input_file || !$species_name){
        my $errorBox = $mw->Dialog(-title => "Missing Fields",
                                -text => "Please ensure both fields are filled.",
                                -buttons => ["OK"]);
        if ($errorBox->Show eq 'OK'){
            $errorBox->destroy();
        }
    }else{
        process();
    }
}

sub process {
    $mw->withdraw();
    
    $processWidget->deiconify();
    $processWidget->raise();
    
    $scrlText->delete('1.0', 'end');
    
    my $dir_name;
    unless ($remote_blast_status == 1 || $blast_parser_status == 1 ){
        $dir_name = dir_name($input_file);
        make_dir($dir_name);
    }
    
    unless ($remote_blast_status == 1 || $blast_parser_status == 1){
        repeatscout($dir_name);
    }
    
    unless ($blast_parser_status == 1 ){
        fragmenter($dir_name);
        remote_blast_sub($dir_name);
    }
    
    parser($dir_name);
    
}

sub _destroy {
    my $self = shift;
    $self->withdraw();
    $mw->deiconify();
    $mw->raise();
}

sub dir_name {
    my $fasta_file = shift;
    chomp $fasta_file;
    
    my ($time_string, $dir_name);
    $time_string = localtime();
    $time_string =~ s/[^a-zA-Z0-9]/-/g;
    
    $fasta_file =~ /.+(\/|\\)(.+?)\..+?$/;
    my $file_name = $2;
    
    $dir_name = $file_name . "-" . $time_string;
    
    return $dir_name;
}

sub make_dir {
    my $dir_name = shift;
    
    $scrlText->insert('end', "Making directory...\n");
    $scrlText->see('end');
    $mw->update();
    
    if (mkdir "./results/$dir_name"){
        $scrlText->insert('end', "   Done.\n");
    }else{
        $scrlText->insert('end', "   Error: Cannot create results directory for this file.\n");
        $scrlText->see('end');
        while (1){
            $mw->update();
        }
    }
    $scrlText->see('end');
    $mw->update();
}

sub repeatscout {
    my $status;
    my $dir_name = shift;
    
    $scrlText->insert('end', "Building seeds...\n");
    $scrlText->see('end');
    $mw->update();

    $status = system("./RepeatScout-1/build_lmer_table -sequence $input_file -freq ./results/$dir_name/lmer_table.tbl");
    if ($status == 0) {
        $scrlText->insert('end', "   Done.\n");
    }else{
        $scrlText->insert('end', "   Error: Cannot build seeds.\n");
        $scrlText->see('end');
        while (1){
            $mw->update();
        }
    }
    $scrlText->see('end');
    $mw->update();
    
    $scrlText->insert('end', "Compiling repeat consensus sequences...\n");
    $scrlText->see('end');
    $mw->update();
    
    $status = system("./RepeatScout-1/RepeatScout -sequence $input_file -output ./results/$dir_name/output_repeats.fa -frequency ./results/$dir_name/lmer_table.tbl");
    if($status == 0) {
        $scrlText->insert('end', "   Done.\n");
    }else{
        $scrlText->insert('end', "   Error: Unable to complete consensus building.\n");
        $scrlText->see('end');
        while(1){
            $mw->update();
        }
    }
    $scrlText->see('end');
    $mw->update();
    
    $scrlText->insert('end', "Filtering short and low-complexity repeats...\n");
    $scrlText->see('end');
    $mw->update();
    
    $status = system("perl ./RepeatScout-1/filter-stage-1.prl ./results/$dir_name/output_repeats.fa > ./results/$dir_name/output_repeats.unfrag");
    if($status == 0) {
        $scrlText->insert('end', "   Done.\n");
    }else{
        $scrlText->insert('end', "   Error: Unable to complete filtering process.\n");
        $scrlText->see('end');
        while(1){
            $mw->update();
        }
    }
    $scrlText->see('end');
    $mw->update();
    
}

sub fragmenter {
    
    my $unfrag_file;
    my $dir_name = shift;
    
    $scrlText->insert('end', "Fragmenting repeat library...\n");
    $scrlText->see('end');
    $mw->update();
    
    if ($remote_blast_status == 1){
        $unfrag_file = $input_file;
    }else{
        opendir DIR, "./results/$dir_name";
        my @repeat_lib = grep /output_repeats\.unfrag$/, readdir DIR;
        
        if (scalar @repeat_lib == 0){
            $scrlText->insert('end', "   Error: Unable to locate repeat library.\n");
            $scrlText->see('end');
            while (1){
                $mw->update();
            }
        }else{
            $unfrag_file = "./results/$dir_name/" . shift @repeat_lib;
        }
    }
    
    my $seq_i = Bio::SeqIO->new(-file => "$unfrag_file",
                                 -format => 'fasta');
    
    mkdir "./results/$dir_name/fragmented";
    my $filename = 0;
    while (my $seq = $seq_i->next_seq()){
        $filename++;
        my $seq_out = Bio::SeqIO->new(-file => ">./results/$dir_name/fragmented/$filename.filtered_1",
                                      -format => 'fasta');
        $seq_out->write_seq($seq);
        
    }
    
    $scrlText->insert('end', "   Done.\n");
    $scrlText->see('end');
    $mw->update();

}

sub remote_blast_sub {
    my $dir_name = shift;
    
    my $fragment_dir = "./results/$dir_name/fragmented";
    
    opendir DIR, $fragment_dir;
    my @blast_input_files = grep /\.filtered_1$/, readdir DIR;
    
    $scrlText->insert('end', "Querying NCBI...");
    $scrlText->see('end');
    $mw->update();
    
    if (scalar @blast_input_files == 0) {
        $scrlText->insert('end', "\n   Error: Unable to locate BLAST input files.\n");
        $scrlText->see('end');
        while(1){
            $mw->update();
        }
    }
    
    my $remote_blast = Bio::Tools::Run::RemoteBlast->new('-prog' => 'blastn',
                                                '-data' => 'nr',
                                                '-expect' => '1e-10',
                                                '-megablast' => 'yes'
                                                );
    $remote_blast->retrieve_parameter('FORMAT_TYPE', 'XML');
    $Bio::Tools::Run::RemoteBlast::HEADER{'ENTREZ_QUERY'} = "all [FILTER] NOT $species_name [ORGANISM]";
    
    mkdir "./results/$dir_name/blast_reports";
    
    foreach my $blast_input_file (@blast_input_files){
        my $response = $remote_blast->submit_blast("$fragment_dir/$blast_input_file");
        
        while (my @rids = $remote_blast->each_rid()){
            foreach my $rid (@rids){
                my $response_retrieve = $remote_blast->retrieve_blast($rid);
                if (!ref($response_retrieve)){
                    if ($response_retrieve < 0){
                        $remote_blast->remove_rid($rid);
                    }
                    $scrlText->insert("end lineend", ".");
                    $scrlText->see('end');
                    $mw->update();
                    
                    sleep 5;
                }else{
                    $blast_input_file =~ /^(.+?)\./;
                    my $filename = $1 . ".blast_xml";
                    $remote_blast->save_output("./results/$dir_name/blast_reports/$filename");
                    $remote_blast->remove_rid($rid);
                    $mw->update();
                }
            }
        }
        sleep 5;
    }
    
    $scrlText->insert('end', "\nDone.\n");
    $scrlText->see('end');
    $mw->update();
    
}

sub parser {
    my $blast_dir;
    
    if ($blast_parser_status == 1){
        $blast_dir = $input_file;
    }else{
        my $dir_name = shift;
        $blast_dir = "./results/$dir_name/blast_reports";
    }
    
    opendir DIR, $blast_dir;
    my @blast_xml_files = grep /\.blast_xml$/, readdir DIR;
    
    $scrlText->insert('end', "Executing parser...");
    $scrlText->see('end');
    $mw->update();
    
    if (scalar @blast_xml_files == 0){
        $scrlText->insert('end', "\n   Error: Unable to locate BLAST XML reports.\n");
        $scrlText->see('end');
        while(1){
            $mw->update();
        }
    }
    
    foreach my $blast_xml_file (@blast_xml_files){
        
        my $in = Bio::SearchIO->new(-file => "$blast_dir/$blast_xml_file",
                                    -format => 'blastxml');
        
        while (my $result = $in->next_result()){
            
            if ($result->num_hits() > 0){
                
                $result->query_description() =~ /^(R=[0-9]+?) /;
                my $repeat_family = $1;
                
                while (my $hit = $result->next_hit()){
                    if ($hit->num_hsps() > 0){
                        my @hit_array = ($hit->name(), $hit->description(), $hit->accession(), $hit->length(), $hit->significance()); 
                        
                        my $species;
                        if ($hit->description() =~ /^[A-Z]+?: ([a-zA-Z]+? [a-z]+?) .+?/) {
                            $species = $1;
                        }elsif ($hit->description() =~ /^[A-Z]+?: ([A-Z]\. ?[a-z]+?) .+?/){
                            $species = $1;
                        }elsif($hit->description() =~ /^([a-zA-Z]+? [a-z]+?) .+?/){
                            $species = $1;
                        }elsif ($hit->description() =~ /^([a-zA-Z]+? [a-zA-Z]+?) .+?/){
                            $species = $1;
                        }elsif ($hit->description() =~ /^([A-Z]\. ?[a-z]+?) .+?/){
                            $species = $1;
                        }else{
                            $species = $hit->description();
                        }
                        
                        while (my $hsp = $hit->next_hsp()){
                            
                            push @hit_array, [$hsp->evalue(), $hsp->frac_identical(), $hsp->start('query'), $hsp->end('query'), $hsp->start('hit'), $hsp->end('hit')];
                            
                        }
                        
                        if (exists $blast_hash{$species}){
                            push @{$blast_hash{$species}->{$repeat_family}}, \@hit_array; 
                        }else{
                            $blast_hash{$species} = { $repeat_family => [] };
                            push @{$blast_hash{$species}->{$repeat_family}}, \@hit_array;
                        }
                    }
                }
            }
        }
        $scrlText->insert("end lineend", ".");
        $scrlText->see('end');
        $mw->update();
        
    }
    $scrlText->insert('end', "\nDone.\n");
    $scrlText->see('end');
    $mw->update();
    
    my $successBox = $processWidget->Dialog(-title => "Completed",
                                            -text => "Proceed to output?",
                                            -buttons => ["OK"]);
    
    if ($successBox->Show eq 'OK'){
        $processWidget->withdraw();
        
        populate_list_with_species();
        
        $outputWidget->deiconify();
        $outputWidget->raise();
        
    }
}

sub populate_list_with_species{
    foreach (sort {$a cmp $b} keys %blast_hash){
        my $species = $_;
        $species = "[+]" . $species;
        $listBox->insert('end', $species);
    }
}

sub check_selected_item{
    my @selected_indices = $listBox->curselection();
    my $selected_index;
    if (scalar @selected_indices == 1){
        $selected_index = shift @selected_indices;
    }
    my $selected = $listBox->get($listBox->curselection());
    
    if ($selected =~ /^\[\+\](.+)/){
        display_repeat_families($1, $selected_index);
    }elsif($selected =~ /^\[\-\](.+)/){
        collapse_species_list($1, $selected_index);
    }elsif($selected =~ /^    -(.+)/){
        display_hits($1, $selected_index);
    }
}

sub display_repeat_families {
    my ($species, $index) = @_;
    
    $listBox->delete($index);
    $listBox->insert($index, "[-]$species");
    $listBox->activate($index);
    $listBox->focus();
    
    my @repeats = keys %{$blast_hash{$species}};
    @repeats = sort {(split /=/, $a)[1] <=> (split /=/, $b)[1]} @repeats;
    
    foreach my $repeat (@repeats){
        $repeat = "    -" . $repeat;
    }
    
    $listBox->insert(++$index, @repeats);
    
}

sub collapse_species_list{
    my ($species, $index) = @_;
    
    $listBox->delete($index);
    $listBox->insert($index, "[+]$species");
    $listBox->activate($index);
    $listBox->focus();
    
    $index++;
    
    while ($listBox->get($index) =~ /^    -/){
        $listBox->delete($index);
    }
    
}

sub display_hits{
    my ($repeat, $index) = @_;
    
    $dataTextBox->delete('1.0', 'end');
    
    while ($listBox->get($index) !~ /^\[\-\]/){
        $index--;
    }
    
    $listBox->get($index) =~ /^\[\-\](.+)/;
    my $species = $1;
    
    my $out_string = "";
    foreach my $hit_array (@{$blast_hash{$species}->{$repeat}}){
        $out_string .= "Hit Name: " . @{$hit_array}[0] . "\n";
        $out_string .= "Hit Description: " . @{$hit_array}[1] . "\n";
        $out_string .= "Hit Accession Number: " . @{$hit_array}[2] . "\n";
        $out_string .= "Hit Length: " . @{$hit_array}[3] . "\n";
        $out_string .= "Hit Significance: " . @{$hit_array}[4] . "\n\n";
        for (my $i = 5; $i < scalar @{$hit_array}; $i++){
            $out_string .= "   HSP E-value: " . @{@{$hit_array}[$i]}[0] . "\n";
            $out_string .= "   HSP Fraction-Identical: " . @{@{$hit_array}[$i]}[1] . "\n";
            $out_string .= "   HSP Query Start: " . @{@{$hit_array}[$i]}[2] . "\n";
            $out_string .= "   HSP Query End: " . @{@{$hit_array}[$i]}[3] . "\n";
            $out_string .= "   HSP Hit Start: " . @{@{$hit_array}[$i]}[4] . "\n";
            $out_string .= "   HSP Hit End: " . @{@{$hit_array}[$i]}[5] . "\n\n";
        }
    }
    
    $dataTextBox->insert('end', $out_string);
    $mw->update();
    
}