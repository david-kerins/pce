#!/usr/bin/perl -w
#===============================================================================
#
#         FILE:  pce2.cgi
#
#        USAGE:  http://www.somedomain.com/cgi-bin/pce2.cgi
#
#  DESCRIPTION:
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:   David Kerins
#      COMPANY:
#      VERSION:  1.0
#      CREATED:  06/23/2007 02:45:30 PM PST
#     REVISION:  ---
#===============================================================================

use strict;
use SOAP::Lite;
use CGI qw/:standard *table/;
use Data::Dumper qw(Dumper);
use Parse::RecDescent;

#---------------------------------------------------------------------------
#  Following are some expamle Priority Constraint Expressions ( PCE ) used.
#---------------------------------------------------------------------------
# my $theSearchString = "A0ACA011 & B76687DE & C9B136AF & D69CF678 & E7A31779";
# my $theSearchString = "A0ACA011 | B76687DE | C9B136AF | D69CF678 | E7A31779";

#---------------------------------------------------------------------------
#  Declare variables and arrays
#---------------------------------------------------------------------------

my $theSearchString;
my $googleTokens = 0;
my @googleArray;
my @keywords;
my $siteRestriction = "site:pce.bitbox.ca ";
my $pceQueryType;
my $query;
my @googleResultsAoH;
my $google_key  = 'FuOuQPlQFHKWV8N4jkn7G9zuCCtvCxV+';
my $google_wsdl = "GoogleSearch.wsdl";

#---------------------------------------------------------------------------
#  Initialize Error Handling
#---------------------------------------------------------------------------
use CGI::Carp qw( fatalsToBrowser );

BEGIN {

    sub carp_error {
        my $error_message = shift;
        print "<pre>$error_message</pre>";
    }
    CGI::Carp::set_message( \\&carp_error );
}

#---------------------------------------------------------------------------
#  Declare the subroutines
#---------------------------------------------------------------------------
sub trim($);
sub ltrim($);
sub rtrim($);

#---------------------------------------------------------------------------
#  This is where the query interface is generated and the user is asked
#  to supply a PCE search string.
#---------------------------------------------------------------------------

print header(),
  start_html("Priority Constraint Expression (PCE) Search Engine"),
  h1("Priority Constraint Expression (PCE)"), h1("Search Engine"),
  start_form( -method => 'GET' ), 'Query: &nbsp; ',
  textfield(
    -name    => 'query',
    -default => 'A0ACA011 & B76687DE & D69CF678',
    -size    => 45
  ),
  ' &nbsp; ', br(), br(), 'Restrict search to pce.bitbox.ca? &nbsp; ',
  radio_group(
    -name    => 'siteRestriction',
    -values  => [ 'Yes', 'No' ],
    -default => 'Yes'
  ),
  br(), ' &nbsp; ', br(), submit( -name => 'submit', -value => 'Search' ), br(),
  '<font size="-2" color="green">Enter a PCE query</font>', end_form(), p();

if ( param('siteRestriction') =~ /No/ ) { $siteRestriction = ""; }

if ( param('query') ) {
    $theSearchString = param('query');
    $theSearchString = trim($theSearchString);

    #print "The input PCE string: ", $theSearchString, "\n";
    #@keywords = grep !/^\s*$/, split /([+-]?".+?")|\s+/, param('query');
    if ( grep /\|/, param('query') ) { $pceQueryType = "orFailingThat"; }
    elsif ( grep /&/, param('query') ) { $pceQueryType = "andIfPossible"; }

    #print "This is the pceQuerytype: $pceQueryType\n";
    @keywords = grep !/^\s*$/, split / & | \|/, param('query');

   #print "this is keywords @keywords\n";
   #---------------------------------------------------------------------------
   #  This is the parsing section which checks the sanity of the PCE and
   #  enforces some conditions of the number of pcePrefTerms and pceBackupTerms.
   #---------------------------------------------------------------------------

    #---------------------------------------------------------------------------
    #  This the the parser section which will determine the "correctness" of
    #  the Priority Constraint Expression provided by the user and place the
    #  result into $result for further processing.
    #---------------------------------------------------------------------------

    my $grammar = q{
 searchstring:      expression eofile
 expression:        andIfPossible|orFailingThat
 andIfPossible:     (term '&')(s) term
 orFailingThat:     (term '|')(s) term
 term:              paren|google(s)
 paren:             '(' expression(s) ')'
 google:            alphanumeric
 alphanumeric:      /\w+/
 eofile:            /^\z/
};

    my $parser = new Parse::RecDescent($grammar)
      or die "parser generation failure";

    my $parsedSearchString = ( $parser->searchstring($theSearchString) );

    if ( Dumper($parsedSearchString) =~ /[undef]/ ) {
        print "This is not a valid PCE search string\n";
        print "Please try again.\n";
        exit;
    }

 #---------------------------------------------------------------------------
 # If we get this far it indicates a successful parse at the earliest point that
 # correctly satisfies the grammar.
 # So our $theSearchString contains a valid PCE string.
 #---------------------------------------------------------------------------

#---------------------------------------------------------------------------
# The following section creates Google Seach queries and stores them in an array.
#---------------------------------------------------------------------------
    my @makeGoogleTokensArray = @keywords;
    my @makeGoogleQueriesArray;
    my $sizeOfGoogleTokensArray = @makeGoogleTokensArray;
    my $numberOfGoogleQueriesReuired;
    my %truthAndQueryHash;

    #---------------------------------------------------------------------------
    #  This "if" structure is for PCE that contain "&" (andIfPossible) symbols.
    #---------------------------------------------------------------------------
    if ( $pceQueryType =~ /andIfPossible/ ) {
        $numberOfGoogleQueriesReuired = $sizeOfGoogleTokensArray + 1;

    #---------------------------------------------------------------------------
    #  The following "for" loop creates the google queries with the required
    #  "negation" symbols.
    #---------------------------------------------------------------------------
        for ( my $i = 0 ; $i < $numberOfGoogleQueriesReuired ; $i++ ) {
            if ( $i == 0 ) {
                push @makeGoogleQueriesArray, [@makeGoogleTokensArray];
            }
            else {
                my @tempTokensArray      = @makeGoogleTokensArray;
                my $endOfTheArrayPointer = -1;
                for (
                    my $innerCounter = 0 ;
                    $innerCounter <= $sizeOfGoogleTokensArray - 1 ;
                    $innerCounter++
                  )
                {
                    $tempTokensArray[$endOfTheArrayPointer] =~ s/ / -/g;
                    $tempTokensArray[$endOfTheArrayPointer] =
                      "-" . $tempTokensArray[$endOfTheArrayPointer];
                    push @makeGoogleQueriesArray, [@tempTokensArray];
                    $endOfTheArrayPointer--;
                }
            }

#print p("this is the makeGoogleQueriesArray element $i @{$makeGoogleQueriesArray[$i]}");
        }

    #---------------------------------------------------------------------------
    #  This is the end of the processing.  We should have our hash called
    #  %googleSearchStringHashofArrays full of real google queries.  Now we
    #  need to send them to Google via the Google SOAP API.
    #---------------------------------------------------------------------------
    #print p("Results for the search string: @keywords \n");
        print p("Results for the search string: $theSearchString \n");
        print p("The following Google queries were sent to Google:\n");

        for ( my $i = 0 ; $i < $numberOfGoogleQueriesReuired ; $i++ ) {
            my $googleStrings = join( " ", @{ $makeGoogleQueriesArray[$i] } );
            $query = $siteRestriction . $googleStrings;
            my $googleTokensMinusOne = $googleTokens - 1;
            if ( $googleStrings =~ /^-/ ) {
                print p("F0 query: $query");
                $truthAndQueryHash{"F$i"} = $googleStrings;
            }
            else {
                print p("T$i query: $query\n");
                $truthAndQueryHash{"T$i"} = $googleStrings;
            }
            my $google_search = SOAP::Lite->service("file:$google_wsdl");
            my $results       = $google_search->doGoogleSearch(
                $google_key, $query, 0,       10,
                "false",     "",     "false", "",
                "latin1",    "latin1"
            );
            $googleResultsAoH[$i] = $results;
        }

        for my $i ( 0 .. $#googleResultsAoH ) {
            my $googleResults = $googleResultsAoH[$i]->{resultElements};
            my $truthValueNumber;
            my $truthValueNumberPrefix;
            if ( $i == $#googleResultsAoH ) {
                $truthValueNumberPrefix = 'F';
                $truthValueNumber       = 0;
            }
            else {
                $truthValueNumberPrefix = 'T';
                $truthValueNumber       = $i;
            }
            print start_table( { -cellpadding => '10', -border => '1' } ),
              Tr(
                [
                    th(
                        { -colspan => '2' },
                        [
                                'Results for '
                              . $truthValueNumberPrefix
                              . $truthValueNumber
                              . ' query:  '
                              . $truthAndQueryHash{"$truthValueNumberPrefix$i"}
                        ]
                    )
                ]
              ),
              Tr( [ th( { -align => 'left' }, [ 'Truth Score', 'Result' ] ) ] );
            foreach my $result ( @{$googleResults} ) {
                my $url = $result->{URL};
                if ( $url =~ /index/ )
                {    # Don't print if it is the index.html file.
                }
                else {
                    print Tr(
                        td(
                            [
                                $truthValueNumberPrefix . $truthValueNumber,
                                b( $result->{title} || 'no title' ) . br()
                                  . a(
                                    { href => $result->{URL} },
                                    $result->{URL}
                                  )
                            ]
                        )
                    );
                }
            }
        }
        print end_table(), p();
    }

  #---------------------------------------------------------------------------
  #  This "elsif" structure is for PCE that contain "|" (orFailingThat) symbols.
  #---------------------------------------------------------------------------
    elsif ( $pceQueryType =~ /orFailingThat/ ) {

        #print p("Need to fill this out\n");
        #print p("This is makeGoogleTokensArray @makeGoogleTokensArray");
        $numberOfGoogleQueriesReuired = $sizeOfGoogleTokensArray;

        #print p("Results for the search string: @keywords \n");
        print p("Results for the search string: $theSearchString \n");
        print p("The following Google queries were sent to Google:\n");

        for ( my $i = 0 ; $i < $numberOfGoogleQueriesReuired ; $i++ ) {

#print "This is the makeGoogleTokensArray element $i :  @makeGoogleTokensArray[$i]\n";
#my $googleStrings = join( " ", @{ $makeGoogleQueriesArray[$i] } );
#$query = $siteRestriction . $googleStrings;
            $query = $siteRestriction . @makeGoogleTokensArray[$i];

            #my $googleTokensMinusOne = $googleTokens - 1;
            #if ( $googleStrings =~ /^-/ ) {
            #    print p("F0 query: $query");
            #    $truthAndQueryHash{"F$i"} = $googleStrings;
            #}
            #else {
            print p("T$i query: $query\n");
            $truthAndQueryHash{"T$i"} = @makeGoogleTokensArray[$i];

            #}
            my $google_search = SOAP::Lite->service("file:$google_wsdl");
            my $results       = $google_search->doGoogleSearch(
                $google_key, $query, 0,       10,
                "false",     "",     "false", "",
                "latin1",    "latin1"
            );
            $googleResultsAoH[$i] = $results;
        }

        for my $i ( 0 .. $#googleResultsAoH ) {
            my $googleResults = $googleResultsAoH[$i]->{resultElements};
            my $truthValueNumber;
            my $truthValueNumberPrefix;

            #    if ( $i == $#googleResultsAoH ) {
            #        $truthValueNumberPrefix = 'F';
            #        $truthValueNumber       = 0;
            #    }
            #    else {
            $truthValueNumberPrefix = 'T';
            $truthValueNumber       = $i;

            #    }
            print start_table( { -cellpadding => '10', -border => '1' } ),
              Tr(
                [
                    th(
                        { -colspan => '2' },
                        [
                                'Results for '
                              . $truthValueNumberPrefix
                              . $truthValueNumber
                              . ' query:  '
                              . $truthAndQueryHash{"$truthValueNumberPrefix$i"}
                        ]
                    )
                ]
              ),
              Tr( [ th( { -align => 'left' }, [ 'Truth Score', 'Result' ] ) ] );
            foreach my $result ( @{$googleResults} ) {
                my $url = $result->{URL};
                if ( $url =~ /index/ )
                {    # Don't print if it is the index.html file.
                }
                else {
                    print Tr(
                        td(
                            [
                                $truthValueNumberPrefix . $truthValueNumber,
                                b( $result->{title} || 'no title' ) . br()
                                  . a(
                                    { href => $result->{URL} },
                                    $result->{URL}
                                  )
                            ]
                        )
                    );
                }
            }
        }
        print end_table(), p();
    }
    print end_html();
}

#---------------------------------------------------------------------------
# Subroutines
#---------------------------------------------------------------------------

# Perl trim function to remove whitespace from the start and end of the string
sub trim($) {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

# Left trim function to remove leading whitespace
sub ltrim($) {
    my $string = shift;
    $string =~ s/^\s+//;
    return $string;
}

# Right trim function to remove trailing whitespace
sub rtrim($) {
    my $string = shift;
    $string =~ s/\s+$//;
    return $string;
}
