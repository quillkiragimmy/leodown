#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;
use LWP::Simple;
BEGIN {
	if ( $^O =~ /Win/ ) {
		require Win32::Console::ANSI;
		Win32::Console::ANSI->import();
	}
}
use Term::ANSIColor;
use Pod::Usage;
use Date::Parse;
use HTML::TreeBuilder::XPath;
use File::HomeDir;
use File::Copy 'move';
use utf8;
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

$| = 1;
my $leourl = 'http://leopard-raws.org/index.php?search=';
my $leolist = File::HomeDir->my_documents . "/leodown.list";
my $leolist_tmp = File::HomeDir->my_documents . "/.leodown.list";

sub datecomp {
	return ( str2time $_[0] ) <=> ( str2time $_[1] );
}

GetOptions(
	'help|h' => \my $help,
	'list|l' => \my $list,
	) or pod2usage ( -verbose => 1 );

if ( $help ) {
	pod2usage ( -verbose => 2 );
}
elsif ( $list ) {#list ongonings.
	my $site_source = get $leourl;
	if ( ! $site_source ) { print "MSG|","Error when fetching list!\n"; exit 1; }

	my $tree = HTML::TreeBuilder->new_from_content( $site_source );
	my @shows = $tree->findnodes_as_strings ( '//div[@class="ongoings-content"]/div' );
	my $show_num = pop @shows;
	print STDERR "Number of Ongoing Shows: $show_num\n";
	my %show_hash = @shows;
	foreach my $key ( keys %show_hash ) {
		print STDERR color('green'), "$key\n", color('reset'), "$show_hash{$key}\n\n";
	}
	$tree->delete();
}
elsif ( scalar(@ARGV) != 0 ) {# searching.
	my ( $key, $key_spaced ) = ( join('+', @ARGV), join(' ',@ARGV) );
	$key =~ s/\s/%20/g;
	my $tree = HTML::TreeBuilder->new_from_content( get "$leourl$key" );
	my @shows = $tree->findnodes_as_strings ( '//div[@class="torrent_name"]' );
	print STDERR join("\n", grep { index ( lc $_, lc $key_spaced ) != -1 } @shows);
	print STDERR colored ['green'], "\nAdd torrent? (N/y)";
	my $name = <STDIN>; chomp $name;
	if ( $name eq 'y' ) {
		open my $f_leolist, ">>", $leolist;
		print $f_leolist join('_', @ARGV), "\t1970/01/02 00:00:00\n";
		close $f_leolist;
		check ( join('_', @ARGV), '1970/01/02 00:00:00' );
	}
	$tree->delete();
}
else {
	open my $f_leolist, "+<", $leolist;# r/w, create if not exist.
	my @watchlist = <$f_leolist>;
	chomp @watchlist;
	close $f_leolist;
	open my $f_leolist_tmp, ">", $leolist_tmp;

	my @sifted_list;
	foreach ( @watchlist ) {
		if ( /^#/ ) {
			print $f_leolist_tmp "$_\n";
			print STDERR colored ['red'], "skipping $_\n"
		}
		else {
			push @sifted_list, $_;
		}
	}

	for my $i ( 0 .. $#sifted_list ) {
		my ( $title, $last_date ) = split("\t", $sifted_list[$i]);
		my $new_date = check($title, $last_date);
		print "MSG|(", $i+1, "/", $#sifted_list+1, ") $title\n";
		print $f_leolist_tmp $new_date? "$title\t$new_date\n" : "#$title\t$last_date\n";
	}
	close $f_leolist_tmp;
	move $leolist_tmp, $leolist;
}

sub check {# check update.
	my ( $title, $last_date ) = @_;
	my $key = $title =~ s/_/+/gr;
	my $key_spaced = lc $title =~ s/_/ /gr; # lowering the case for exact match.

	my $site_source = get "$leourl$key";
	if ( ! $site_source ) { print "MSG|","Error when fetching page!\n"; return $last_date; }

	my $tree = HTML::TreeBuilder->new_from_content( $site_source );
	my @titles = $tree->findnodes_as_strings ( '//div[@class="torrent_name"]' );
	my @links = $tree->findnodes( '//div[@class="torrent_name"]/a[@href]' );
	my @infos = $tree->findnodes_as_strings ( '//div[@class="info"]' );
	my @dates = map { s/^.*Date:\s(.*?)\|.*$/$1/r } @infos;

	my $index_newest = $#titles+1;
	push @dates, $last_date;

	for my $i ( 0 .. $#titles ) {
		if ( (index ( lc ($titles[$i]), $key_spaced) != -1 ) and ($titles[$i]=~/-\s[0-9]{2}\s(RAW|END)/) ) {
			if ( datecomp($dates[$i], $last_date) > 0 ) {
				my $magnet = ($leourl=~s/index.*$//r) . ($links[$i]->attr('href')=~s/\.\///r);
				print "ADD|$titles[$i]|$magnet\n";
				print "comp date & newest_date\n";
				if ( datecomp($dates[$i], $dates[$index_newest]) > 0 ) { $index_newest = $i; }
			}
		}
	}
	$tree->delete();
	return ( $titles[$index_newest] =~ /-\s[0-9]{2}\sEND/ )? undef : $dates[$index_newest];
}

__END__

=head1 NAME

leodown - check new uploads from leopardraws.org.

=head1 SYNOPSIS

leodown [ keywords | -h, --help | -l, --list ]

=head1 DESCRIPTION

A lazy-man script for checking bunch of Leopard-Raws objects for update.
It will take a list file called leodown.list inside your $HOME ( $HOME/Documents/ on Windows ), which contains anime titles and last updated time, when it is run without parameter. This list should be generated by search function.

The lines in leodown.list prefixed with # will be ignored during the update process.

Precaution: B<the key words should match the original english title, keys like 'Durar shou' won't match 'Durarara!!x2 Shou'.> This behaviour is intended for preventing matching season one when tring to match season two.

=head1 OPTIONS

=over 12

=item B<<keywords>>

Search the keywords on leopardraws.org and enlist matched object. lower/upper cases won't matter.

e.g: leodown.pl Shigatsu wa Kimi no Uso

=item B<-h, --help>

Show this help.

=item B<-l, --list>

List ongoning shows.

=back

=head1 AUTHOR

Any bug report will be welcome at 'quillkiragimmy@gmail.com'.

=cut


