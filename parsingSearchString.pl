#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  parsingSearchString
#
#        USAGE:  ./parsingSearchString
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
#      CREATED:  02/13/2007 02:45:30 PM PST
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use SOAP::Lite;
use Text::Balanced qw/extract_bracketed/;
use Text::Balanced qw/extract_delimited/;
use Tie::Hash::Regex;
use Data::Dumper qw(Dumper);

#---------------------------------------------------------------------------
#  Following are some test Priority Constraint Expressions ( PCE ) used
#  to test the code.
#---------------------------------------------------------------------------
#my $theSearchString = " (\"A0ACA011 CBCBCB\" W[B76687DE]) BBB CCC U[C9B136AF] (U2[D69CF678] W[E7A31779])";
#---------------------------------------------------------------------------
# Primary Precedence Group Test String.
#---------------------------------------------------------------------------
#my $theSearchString = " ( A0ACA011 W[B76687DE] ) U[D69CF678]";

my $theSearchString = " ( A0ACA011 W[B76687DE] ) U[C9B136AF]  U2[D69CF678]";
#my $theSearchString = " ( A0ACA011 W[B76687DE] ) U[C9B136AF] U2[D69CF678] W[E7A31779]";

#my $theSearchString = " ( A0ACA011 W[B76687DE] ) U[C9B136AF] W[D69CF678]";
#my $theSearchString = " ( A0ACA011 W[B76687DE] ) W[C9B136AF]";
#my $theSearchString = " (A0ACA011 U[C9B136AF]) U2[D69CF678] W[E7A31779])";
#
#---------------------------------------------------------------------------
# Secondary Precedence Group Test String.
#---------------------------------------------------------------------------
#my $theSearchString = " A0ACA011 U[C9B136AF] (U2[D69CF678] W[E7A31779])";
#
#---------------------------------------------------------------------------
# Preference Term Test Strings
#---------------------------------------------------------------------------
#my $theSearchString = " A0ACA011 U[B76687DE]";
#my $theSearchString = " A0ACA011 U[B76687DE] U2[C9B136AF]";

#my $theSearchString = " A0ACA011 U1[B76687DE] U2[C9B136AF]";
#
#---------------------------------------------------------------------------
# Backup Term Test Strings
#---------------------------------------------------------------------------
#my $theSearchString = " A0ACA011 U[B76687DE] U2[D69CF678] W[E7A31779]";
#my $theSearchString = " A0ACA011 U[B76687DE] W[C9B136AF]";
#my $theSearchString = " A0ACA011 W[C9B136AF]";

#---------------------------------------------------------------------------
#  Declare variables and arrays
#---------------------------------------------------------------------------

my %pceSearchStringHashofArrays;
my %googleSearchStringHashofArrays;
my %googleSearchStringHashofArraysTemp;
my $extracted;
my $iterator = 1;
my $count    = 0;
my $key;
my $pos                           = 0;
my $preferentialTokenLimitCounter = 0;
my $preferentialTokenLimit        = 2;
my $doSubstitutionNow             = 0;
my $degree                        = 0;
my $numberOfIterationsNeeded      = 0;
my $pceTokens                     = 0;
my $pceTokensNumber               = 0;
my $pceGoogleTokensNumber         = 0;
my $pcePrefTokensNumber           = 0;
my $pceBackupTokensNumber         = 0;
my $googleTokens                  = 0;
my $precedenceGroupArrayCounter   = 1;
my $precedenceGroupArrayTerm;
my @precedenceGroupArray;
my @googleArray;
my @backupTerm1Array;
my @backupTerm2Array;

my $siteRestriction = "site:pce.bitbox.ca ";
my $query;
my @googleResultsAoH;
my $google_key  = 'FuOuQPlQFHKWV8N4jkn7G9zuCCtvCxV+';
my $google_wsdl = "GoogleSearch.wsdl";

tie %pceSearchStringHashofArrays, 'Tie::Hash::Regex';

#---------------------------------------------------------------------------
#  Declare the subroutines
#---------------------------------------------------------------------------
sub trim($);
sub ltrim($);
sub rtrim($);

#---------------------------------------------------------------------------
#  This is the parsing section which checks the sanity of the PCE and
#  enforces some conditions of the number of pcePrefTerms and pceBackupTerms.
#---------------------------------------------------------------------------

$theSearchString = trim($theSearchString);
print "This is theSearchString (trimmed):$theSearchString\n";

while ( $theSearchString =~ /(U\d*\[\w+\])/g ) {

    # Count the number of preferential constraints.
    # Exit if there are more than two.
    if ( ++$preferentialTokenLimitCounter > $preferentialTokenLimit ) {
        print "There can only be 2 preferential tokens\n";
        print "Exiting ...\n";
        exit;
    }
}

#---------------------------------------------------------------------------
#  The following tests for a parenthesized terms or for quoted text and then
#  parses those two possibilities.
#---------------------------------------------------------------------------
if ( $theSearchString =~ /[("]/ ) {

   # We get here because there are quoted strings or parenthesises to deal with.
   #print "This search string has tricky bits\n";
    while ( defined $theSearchString && $theSearchString ne '' ) {
        $theSearchString = trim($theSearchString);

    #---------------------------------------------------------------------------
    #  Tests for parenthesized terms.
    #---------------------------------------------------------------------------
        if ( $theSearchString =~ /^\(/ ) {    # Parenthesized Term.
            ( $extracted, $theSearchString ) =
              extract_bracketed( $theSearchString, "(" );
            $extracted =~ s/^\(//;
            $extracted =~ s/\)$//;
            @precedenceGroupArray = split ' ', $extracted;
            for ( my $i = 0 ; $i <= scalar @precedenceGroupArray - 1 ; $i++ ) {

#foreach my $precedenceGroupArray ( @precedenceGroupArray ) { print " $i $precedenceGroupArray\n"; }
#
#---------------------------------------------------------------------------
# There should be one or more google tokens with one and
# only one PCE backup constraint. i.e. W[BBB] in any precendence group.
# Test for this and fail if not true.
#---------------------------------------------------------------------------
                if ( $precedenceGroupArray[$i] =~ /W\d*\[/ ) {
                    $count++;
                }
            }
            if ( $count > 1 ) {
                print
"Only 1 Backup constraint allowed which must be the last term in any precedence group.\n";
                print "Exiting ...\n";
                $count = 0;
                exit;    # Bail out with error.
            }
            foreach my $precedenceGroupArray (@precedenceGroupArray) {

                #print "$precedenceGroupArray\n";
                #print "This is it\n";
                if ( $precedenceGroupArray =~ /^(W\d*\[)(\w+)(\])/ ) {
                    $precedenceGroupArray = $2;
                }
            }

#foreach my $precedenceGroupArray ( @precedenceGroupArray ) { print " $i $precedenceGroupArray\n"; }
            $pceSearchStringHashofArrays{ $iterator . 'precedenceGroupArray' } =
              [@precedenceGroupArray];
        }

    #---------------------------------------------------------------------------
    #  Test for quoted text/terms.
    #---------------------------------------------------------------------------
        elsif ( $theSearchString =~ /^\"/ ) {    #Quoted Terms.

            # Deal with quoted strings which should be preserved for google.
            # print "The head of the search string contains double quotes\n";
            ( $extracted, $theSearchString ) =
              extract_delimited( $theSearchString, q{"} );

            # Quoted terms should NOT contain PCE tokens.  Test for this.
            if ( $extracted =~ /U\d*\[|W\d*\[/ ) {
                print
"Quoted terms should only contain regular search words, not PCE tokens\n";
                print "Exiting...\n";
                exit;
            }
            $pceSearchStringHashofArrays{ $iterator . 'quotedTerm' } =
              [$extracted];
        }
        else {

#---------------------------------------------------------------------------
# The head of the search string contains either a PCE token or a regular google term.
#---------------------------------------------------------------------------
            if ( $theSearchString =~ /^(U)(\d*)(\[)/ ) {
                if ( $2 eq '' ) { $degree = "1"; }
                else { $degree = $2; }
                ( $extracted, $theSearchString ) =
                  split( ' ', $theSearchString, 2 );
                if ( $extracted =~ /^(U\d*\[)(\w+)(\])/ ) {
                    $extracted = $2;
                }
                $pceSearchStringHashofArrays{ $iterator
                      . 'pcePrefTerm'
                      . $degree } = [$extracted];
            }
            elsif ( $theSearchString =~ /^(W)(\d*)(\[)/ ) {
                if ( $2 eq '' ) { $degree = "1"; }
                else { $degree = $2; }
                ( $extracted, $theSearchString ) =
                  split( ' ', $theSearchString, 2 );
                if ( $extracted =~ /^(W\d*\[)(\w+)(\])/ ) {
                    $extracted = $2;
                }
                $pceSearchStringHashofArrays{ $iterator
                      . 'pceBackupTerm'
                      . $degree } = [$extracted];
            }
            else {
                ( $extracted, $theSearchString ) =
                  split( ' ', $theSearchString, 2 );
                $pceSearchStringHashofArrays{ $iterator . 'googleTerm' } =
                  [$extracted];
            }
        }
        $iterator++;
    }
}
else {

    #---------------------------------------------------------------------------
    # Nothing but PCE or Google tokens in the search string.
    #---------------------------------------------------------------------------
    while ( defined $theSearchString && $theSearchString ne '' ) {
        $theSearchString = trim($theSearchString);
        if ( $theSearchString =~ /^(U)(\d*)(\[)/ ) {
            if ( $2 eq '' ) { $degree = "1"; }
            else { $degree = $2; }
            ( $extracted, $theSearchString ) =
              split( ' ', $theSearchString, 2 );
            if ( $extracted =~ /^(U\d*\[)(\w+)(\])/ ) {
                $extracted = $2;
            }
            $pceSearchStringHashofArrays{ $iterator
                  . 'pcePrefTerm'
                  . $degree } = [$extracted];
        }
        elsif ( $theSearchString =~ /^(W)(\d*)(\[)/ ) {
            if ( $2 eq '' ) { $degree = "1"; }
            else { $degree = $2; }
            ( $extracted, $theSearchString ) =
              split( ' ', $theSearchString, 2 );
            if ( $extracted =~ /^(W\d*\[)(\w+)(\])/ ) {
                $extracted = $2;
            }
            $pceSearchStringHashofArrays{ $iterator
                  . 'pceBackupTerm'
                  . $degree } = [$extracted];
        }
        else {
            ( $extracted, $theSearchString ) =
              split( ' ', $theSearchString, 2 );
            $pceSearchStringHashofArrays{ $iterator . 'googleTerm' } =
              [$extracted];
        }
        $iterator++;
    }
}

#---------------------------------------------------------------------------
# The following section creates Google Seach queries and stores them in an array.
#---------------------------------------------------------------------------
##
##
# Count the number of each type of term.
for $pceTokens ( sort keys %pceSearchStringHashofArrays ) {
    $pceTokensNumber++;
    if ( $pceTokens =~ /1precedenceGroupArray/ ) {

        #$pceTokensNumber++;
    }
    if ( $pceTokens =~ /googleTerm/ ) {
        $pceGoogleTokensNumber++;
    }
    elsif ( $pceTokens =~ /pcePrefTerm/ ) {
        $pcePrefTokensNumber++;
    }
    elsif ( $pceTokens =~ /pceBackupTerm/ ) {
        $pceBackupTokensNumber++;
    }
}
print "Number of Tokens: $pceTokensNumber\n" if ( defined $pceTokensNumber );
print "Number of PrefTokens: $pcePrefTokensNumber\n"
  if ( defined $pceBackupTokensNumber );
print "Number of BackupTokens: $pceBackupTokensNumber\n"
  if ( defined $pceBackupTokensNumber );
##
##---------------------------------------------------------------------------
# The following section creates Google Seach queries if the PCE has a primary
# precedence group.
#---------------------------------------------------------------------------
#print Dumper ( sort keys %pceSearchStringHashofArrays );
if ( exists $pceSearchStringHashofArrays{'1precedenceGroupArray'} ) {

    #---------------------------------------------------------------------------
    #  Set the number of iterations required for the 1precedenceGroupArray PCE.
    #---------------------------------------------------------------------------
    # :TODO:02/26/2007:: This is not correct.
    if ( $pcePrefTokensNumber + $pceBackupTokensNumber == 3 ) {
        $numberOfIterationsNeeded = 6;
    }
    else {
        $numberOfIterationsNeeded = $pceTokensNumber;
    }

#---------------------------------------------------------------------------
# Will need to split the two terms in 1precedenceGroupArray and create two sets of google queries.
#---------------------------------------------------------------------------
    for $precedenceGroupArrayCounter (
        0 .. $#{ $pceSearchStringHashofArrays{'1precedenceGroupArray'} } )
    {

#print " $precedenceGroupArrayCounter = $pceSearchStringHashofArrays{'1precedenceGroupArray'}[$precedenceGroupArrayCounter]\n";
        $precedenceGroupArrayTerm =
          $pceSearchStringHashofArrays{'1precedenceGroupArray'}
          [$precedenceGroupArrayCounter];

        #print Dumper ($precedenceGroupArrayTerm);
        #print Dumper (%pceSearchStringHashofArrays);
        if ( exists $pceSearchStringHashofArrays{'BackupTerm'} ) {

            #print "do we get here?\n";
            if ( $pceBackupTokensNumber == 1 ) {
                foreach my $key ( sort keys %pceSearchStringHashofArrays )
                {    # Find out where the BackupTerm is.
                    if ( $key =~ /BackupTerm/ ) {
                        $pos = substr( $key, 0, 1 );
                    }
                }

                #print "BackupTerm Position is: $pos\n";

     #If there are a mix of PrefTerms and BackupTerms we need to deal with that.
     #print Dumper ( sort keys %pceSearchStringHashofArrays );
                if ( $pcePrefTokensNumber + $pceBackupTokensNumber == 3 ) {
                    $numberOfIterationsNeeded = 6;
                }
                else {
                    $numberOfIterationsNeeded = $pceTokensNumber;
                }

               #print "the num of iters needed is :$numberOfIterationsNeeded\n";
                for ( my $i = 1 ; $i <= $numberOfIterationsNeeded ; $i++ ) {
                    if ( $i == 1 ) {

                        # First iteration we want all googleTerms and PrefTerms.
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /1precedenceGroupArray/ ) {
                                push @googleArray, $precedenceGroupArrayTerm;
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                            elsif ( $pceTokens =~ /pceBackupTerm1/ ) {

                                # Grab the value of the backupTerm
                                @backupTerm1Array = ();
                                push @backupTerm1Array,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                        }
                    }

                    elsif ( $i == 2 ) {    # The second iteration.
                        if ( $pceTokensNumber == 2 ) {

    #---------------------------------------------------------------------------
    # Test to see if there is only one GoogleTerm and one Backup Term.
    # This is a special case.
    #---------------------------------------------------------------------------
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /1precedenceGroupArray/ ) {

                                  #push @googleArray, $precedenceGroupArrayTerm;

                                    # Do nothing here.
                                }
                                elsif ( $pceTokens =~ /pceBackupTerm/ ) {
                                    push @googleArray,
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                }
                            }
                        }
                        else {    # Not a special case.
                            if ( $i == $numberOfIterationsNeeded ) {

#---------------------------------------------------------------------------
# Test to see if this is the last time through.
# Special case where we create query with Google terms and negated Pref and Backup Terms.
#---------------------------------------------------------------------------
#print "This is the last time through on $i\n";
                                for $pceTokens (
                                    sort keys %pceSearchStringHashofArrays )
                                {
                                    if ( $pceTokens =~ /1precedenceGroupArray/ )
                                    {
                                        push @googleArray,
                                          $precedenceGroupArrayTerm;
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                    elsif ( $pceTokens =~ /pceBackupTerm/ ) {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                            }
                            else {    # No this is NOT the last time through.
                                if ( $i == $pos - 1 )
                                { # Testing for when to do substitution of BackupTerm.
                                     #print "We have to do the Backup substitution here. $i\n";
                                    for $pceTokens (
                                        sort keys %pceSearchStringHashofArrays )
                                    {

               # :TODO:02/26/2007:: May need to deal with following if statment.
                                        if (   $pceTokens =~ /1googleTerm/
                                            && $pos == 2 )
                                        {

                                # Special case of 1googleTerm and 2pceBackupTerm
                                            push @googleArray,
                                              @backupTerm1Array,;
                                        }
                                        elsif ( $pceTokens =~
                                            /1precedenceGroupArray/ )
                                        {
                                            push @googleArray,
                                              $precedenceGroupArrayTerm;

          #  elsif ( $pceTokens =~ /googleTerm/ ) {
          #    push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                        }
                                        elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                            if (
                                                exists
                                                $pceSearchStringHashofArrays{
                                                    'pcePrefTerm2'} )
                                            {
                                                if ( 1 == $pos - 1 )
                                                { # Substitute the backup term for pcePrefTerm1
                                                    push @googleArray,
                                                      @backupTerm1Array,;
                                                }
                                                else
                                                { # Just push pcePrefTerm1 onto the googleArray
                                                    push @googleArray,
                                                      @{
                                                        $pceSearchStringHashofArrays{
                                                            $pceTokens} };
                                                }
                                            }
                                            else {
                                                if ( $i == $pos - 1 )
                                                { # Need pceBackupTerm to occur in the list of
                                                     # google queries before the negated pcePrefTerm2.
                                                    push @googleArray,
                                                      @backupTerm1Array;
                                                }
                                                else {
                                                    my @tempArray =
                                                      @{
                                                        $pceSearchStringHashofArrays{
                                                            $pceTokens} };
                                                    $tempArray[0] =~
                                                      s/(\w)/-$1/;
                                                    push @googleArray,
                                                      @tempArray;
                                                }
                                            }
                                        }
                                        elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                            if ( $i == $pos - 2 ) {

           #--------------------------------------------------------------------
           # Need the negated backup term to occur in the list of
           # google queries before the negated pcePrefTerm2.
           #--------------------------------------------------------------------
                                                push @googleArray,
                                                  @backupTerm1Array;
                                            }
                                            else {
                                                my @tempArray =
                                                  @{
                                                    $pceSearchStringHashofArrays{
                                                        $pceTokens} };
                                                $tempArray[0] =~ s/(\w)/-$1/;
                                                push @googleArray, @tempArray;
                                            }

                                            if ( 2 == $pos - 1 )
                                            { # The backup term is meant for pcePrefTerm2.
                                                push @googleArray,
                                                  @backupTerm1Array,;
                                            }
                                            else {
                                                my @tempArray =
                                                  @{
                                                    $pceSearchStringHashofArrays{
                                                        $pceTokens} };
                                                $tempArray[0] =~ s/(\w)/-$1/;
                                                push @googleArray, @tempArray;
                                            }
                                        }
                                    }
                                }
                                else {

    #---------------------------------------------------------------------------
    # No substitution of BackupTerm on this iteration.
    # Second iteration we want all googleTerms and the most preferred PrefTerm.
    #---------------------------------------------------------------------------
                                    for $pceTokens (
                                        sort keys %pceSearchStringHashofArrays )
                                    {
                                        if ( $pceTokens =~
                                            /1precedenceGroupArray/ )
                                        {
                                            push @googleArray,
                                              $precedenceGroupArrayTerm;

          #    if ( $pceTokens =~ /googleTerm/ ) {
          #    push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                        }
                                        elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                            if (
                                                exists
                                                $pceSearchStringHashofArrays{
                                                    'pcePrefTerm2'} )
                                            {
                                                push @googleArray,
                                                  @{
                                                    $pceSearchStringHashofArrays{
                                                        $pceTokens} };
                                            }
                                            else {
                                                my @tempArray =
                                                  @{
                                                    $pceSearchStringHashofArrays{
                                                        $pceTokens} };
                                                $tempArray[0] =~ s/(\w)/-$1/;
                                                push @googleArray, @tempArray;
                                            }
                                        }
                                        elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                            if ( $i == $pos - 2 ) {

          #---------------------------------------------------------------------
          # Need the negated backup term to occur in the list of
          # google queries before the negated pcePrefTerm2.
          #---------------------------------------------------------------------
                                                push @googleArray,
                                                  @backupTerm1Array;
                                            }
                                            else {
                                                my @tempArray =
                                                  @{
                                                    $pceSearchStringHashofArrays{
                                                        $pceTokens} };
                                                $tempArray[0] =~ s/(\w)/-$1/;
                                                push @googleArray, @tempArray;
                                            }
                                        }
                                    }
                                }

                            }   # End of test whether this is last time through.

                        } # End of if with condition $pceTokensNumber is something greater than 2

                    }    # End of if with condition $i == 2

                    elsif ( $i == 3 ) {    # The third iteration.
                        if ( $i == $pceTokensNumber ) {

    #---------------------------------------------------------------------------
    # Test to see if this is the last time through.
    # Special case where we create query with Google
    # terms and negated Pref and Backup Terms.
    #---------------------------------------------------------------------------
    #print "This is the last time through on $i\n";
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /1precedenceGroupArray/ ) {
                                    push @googleArray,
                                      $precedenceGroupArrayTerm;

              #if ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                                elsif ( $pceTokens =~ /pceBackupTerm/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                            }
                        }
                        else
                        {    # This is not the last time through the loop so....
                            if ( $i == $pos - 1 )
                            { # Testing for when to do substitution of BackupTerm.
                                 #print "This is where We should do the Backup substitution. $i\n";
                                for $pceTokens (
                                    sort keys %pceSearchStringHashofArrays )
                                {

            # :WARNING:02/25/2007:: I may need to do this twice if there are one
            # versus two prefTerms
                                    if (   $pceTokens =~ /1googleTerm/
                                        && $pos == 2 )
                                    {

                                # Special case of 1googleTerm and 2pceBackupTerm
                                        push @googleArray, @backupTerm1Array;
                                    }
                                    elsif (
                                        $pceTokens =~ /1precedenceGroupArray/ )
                                    {
                                        push @googleArray,
                                          $precedenceGroupArrayTerm;

              #elsif ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                        if (
                                            exists $pceSearchStringHashofArrays{
                                                'pcePrefTerm2'} )
                                        {
                                            push @googleArray,
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                        @tempArray = ();
                                        @tempArray = @backupTerm1Array;
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                            }
                            else {

    #---------------------------------------------------------------------------
    # No substitution this time so ...
    # Third iteration we want all googleTerms and the most preferred PrefTerm.
    #---------------------------------------------------------------------------
                                for $pceTokens (
                                    sort keys %pceSearchStringHashofArrays )
                                {
                                    if ( $pceTokens =~ /1precedenceGroupArray/ )
                                    {
                                        push @googleArray,
                                          $precedenceGroupArrayTerm;

              #if ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                        if (
                                            exists $pceSearchStringHashofArrays{
                                                'pcePrefTerm2'} )
                                        {
                                            push @googleArray,
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                        if ( $i == $pos - 2 )
                                        { # Need the negated backup term to occur in the list of
                                             # google queries before the negated pcePrefTerm2.
                                            push @googleArray,
                                              @backupTerm1Array;
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }
                                    }
                                }    # End of for loop.
                            }    # End of test if we are doing substitutions.
                        } # End of if ($i == $pceTokensNumber) i.e Last time through test
                    }    # End of if condition $i == 3
                    elsif ( $i == 4 ) {    # The fourth iteration.
                        if ( $i == $numberOfIterationsNeeded ) {

    #---------------------------------------------------------------------------
    # Test to see if this is the last time through.
    # Special case where we create query with Google
    # terms and negated Pref and Backup Terms.
    #---------------------------------------------------------------------------
    #print "This is the last time through on $i\n";
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /1precedenceGroupArray/ ) {
                                    push @googleArray,
                                      $precedenceGroupArrayTerm;

              #if ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                                elsif ( $pceTokens =~ /pceBackupTerm/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                            }
                        }
                        else
                        {    # This is not the last time through the loop so....
                            if ( $i == $pos - 1 )
                            { # Testing for when to do substitution of BackupTerm.
                                 #print "This is where We should do the Backup substitution. $i\n";
                                for $pceTokens (
                                    sort keys %pceSearchStringHashofArrays )
                                {
                                    if (   $pceTokens =~ /1googleTerm/
                                        && $pos == 2 )
                                    {

                                # Special case of 1googleTerm and 2pceBackupTerm
                                        push @googleArray, @backupTerm1Array;
                                    }
                                    elsif (
                                        $pceTokens =~ /1precedenceGroupArray/ )
                                    {
                                        push @googleArray,
                                          $precedenceGroupArrayTerm;

              #elsif ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                        if (
                                            exists $pceSearchStringHashofArrays{
                                                'pcePrefTerm2'} )
                                        {
                                            push @googleArray,
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                            }
                            else {

    #---------------------------------------------------------------------------
    # No substitution this time so ...
    # Fourth iteration we want all googleTerms and the most preferred PrefTerm
    # and a negated least preferred PrefTerm.
    #---------------------------------------------------------------------------
                                for $pceTokens (
                                    sort keys %pceSearchStringHashofArrays )
                                {
                                    if ( $pceTokens =~ /1precedenceGroupArray/ )
                                    {
                                        push @googleArray,
                                          $precedenceGroupArrayTerm;

              #if ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                        if (
                                            exists $pceSearchStringHashofArrays{
                                                'pcePrefTerm2'} )
                                        {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                        if ( $i == $pos - 2 )
                                        { # Need the negated backup term to occur in the list of
                                             # google queries before the negated pcePrefTerm2.
                                            push @googleArray,
                                              @backupTerm1Array;
                                        }
                                        else {
                                            push @googleArray,
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };

                 #push @googleArray, @backupTerm1Array;
                 #my @tempArray = @{ $pceSearchStringHashofArrays{$pceTokens} };
                 #$tempArray[0] =~ s/(\w)/-$1/;
                 #push @googleArray, @tempArray;
                                        }
                                    }
                                }    # End of for loop.
                            }    # End of test if we are doing substitutions.
                        } # End of if ($i == $pceTokensNumber) i.e Last time through test
                    }    # End of if condition $i == 4
                    elsif ( $i == 5 ) {    # The fifth iteration.
                        if ( $i == $numberOfIterationsNeeded ) {

    #---------------------------------------------------------------------------
    # Test to see if this is the last time through.
    # Special case where we create query with Google
    # terms and negated Pref and Backup Terms.
    #---------------------------------------------------------------------------
    #print "This is the last time through on $i\n";
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /1precedenceGroupArray/ ) {
                                    push @googleArray,
                                      $precedenceGroupArrayTerm;

              #if ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                                elsif ( $pceTokens =~ /pceBackupTerm/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                            }
                        }
                        else
                        {    # This is not the last time through the loop so....
                            if ( $i == $pos - 1 )
                            { # Testing for when to do substitution of BackupTerm.
                                 #print "This is where We should do the Backup substitution. $i\n";
                                for $pceTokens (
                                    sort keys %pceSearchStringHashofArrays )
                                {
                                    if (   $pceTokens =~ /1googleTerm/
                                        && $pos == 2 )
                                    {

                                # Special case of 1googleTerm and 2pceBackupTerm
                                        push @googleArray, @backupTerm1Array;
                                    }
                                    elsif (
                                        $pceTokens =~ /1precedenceGroupArray/ )
                                    {
                                        push @googleArray,
                                          $precedenceGroupArrayTerm;

              #elsif ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                        if (
                                            exists $pceSearchStringHashofArrays{
                                                'pcePrefTerm2'} )
                                        {
                                            push @googleArray,
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                            }
                            else {

    #---------------------------------------------------------------------------
    # No substitution this time so ...
    # Fifth iteration we want all googleTerms and the most preferred PrefTerm.
    #---------------------------------------------------------------------------
                                for $pceTokens (
                                    sort keys %pceSearchStringHashofArrays )
                                {
                                    if ( $pceTokens =~ /1precedenceGroupArray/ )
                                    {
                                        push @googleArray,
                                          $precedenceGroupArrayTerm;

              #if ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                        if (
                                            exists $pceSearchStringHashofArrays{
                                                'pcePrefTerm2'} )
                                        {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                        if ( $i == $pos - 2 )
                                        { # Need the negated backup term to occur in the list of
                                             # google queries before the negated pcePrefTerm2.
                                            push @googleArray,
                                              @backupTerm1Array;
                                        }
                                        else {
                                            push @googleArray,
                                              @backupTerm1Array;

                 #my @tempArray = @{ $pceSearchStringHashofArrays{$pceTokens} };
                 #$tempArray[0] =~ s/(\w)/-$1/;
                 #push @googleArray, @tempArray;
                                        }
                                    }
                                }    # End of for loop.
                            }    # End of test if we are doing substitutions.
                        } # End of if ($i == $pceTokensNumber) i.e Last time through test
                    }    # End of if condition $i == 5
                    elsif ( $i == 6 ) {    # The sixth iteration.
                        if ( $i == $numberOfIterationsNeeded ) {

    #---------------------------------------------------------------------------
    # Test to see if this is the last time through.
    # Special case where we create query with Google
    # terms and negated Pref and Backup Terms.
    #---------------------------------------------------------------------------
    #print "This is the last time through on $i\n";
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /1precedenceGroupArray/ ) {
                                    push @googleArray,
                                      $precedenceGroupArrayTerm;

              #if ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                                elsif ( $pceTokens =~ /pceBackupTerm/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                            }
                        }
                        else
                        {    # This is not the last time through the loop so....
                            if ( $i == $pos - 1 )
                            { # Testing for when to do substitution of BackupTerm.
                                 #print "This is where We should do the Backup substitution. $i\n";
                                for $pceTokens (
                                    sort keys %pceSearchStringHashofArrays )
                                {
                                    if (   $pceTokens =~ /1googleTerm/
                                        && $pos == 2 )
                                    {

                                # Special case of 1googleTerm and 2pceBackupTerm
                                        push @googleArray, @backupTerm1Array;
                                    }
                                    elsif (
                                        $pceTokens =~ /1precedenceGroupArray/ )
                                    {
                                        push @googleArray,
                                          $precedenceGroupArrayTerm;

              #elsif ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                        if (
                                            exists $pceSearchStringHashofArrays{
                                                'pcePrefTerm2'} )
                                        {
                                            push @googleArray,
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                            }
                            else {

    #---------------------------------------------------------------------------
    # No substitution this time so ...
    # Sixth iteration we want all googleTerms and the most preferred PrefTerm.
    #---------------------------------------------------------------------------
                                for $pceTokens (
                                    sort keys %pceSearchStringHashofArrays )
                                {
                                    if ( $pceTokens =~ /1precedenceGroupArray/ )
                                    {
                                        push @googleArray,
                                          $precedenceGroupArrayTerm;

              #if ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                        if (
                                            exists $pceSearchStringHashofArrays{
                                                'pcePrefTerm2'} )
                                        {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                        if ( $i == $pos - 2 )
                                        { # Need the negated backup term to occur in the list of
                                             # google queries before the negated pcePrefTerm2.
                                            push @googleArray,
                                              @backupTerm1Array;
                                        }
                                        else {
                                            push @googleArray,
                                              @backupTerm1Array;

                 #my @tempArray = @{ $pceSearchStringHashofArrays{$pceTokens} };
                 #$tempArray[0] =~ s/(\w)/-$1/;
                 #push @googleArray, @tempArray;
                                        }
                                    }
                                }    # End of for loop.
                            }    # End of test if we are doing substitutions.
                        } # End of if ($i == $pceTokensNumber) i.e Last time through test
                    }    # End of if condition $i == 6

                    else {

    #---------------------------------------------------------------------------
    # The last next iteration.  I have yet to deal with this.
    #---------------------------------------------------------------------------
                        if (
                            exists $pceSearchStringHashofArrays{'pcePrefTerm2'}
                          )
                        {
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /1precedenceGroupArray/ ) {
                                    push @googleArray,
                                      $precedenceGroupArrayTerm;

              #if ( $pceTokens =~ /googleTerm/ ) {
              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {

                            #need to use tempArray for some string manipulation.
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    push @googleArray,
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                }
                            }
                        }
                    }
                    if ( $precedenceGroupArrayCounter == 0 ) {
                        $googleSearchStringHashofArrays{$i} = [@googleArray];
                    }
                    else {
                        $googleSearchStringHashofArrays{ $i + 6 } =
                          [@googleArray];
                    }

                   #print "Yep were here\n";
                   #print Dumper (@{ $googleSearchStringHashofArrays{$count} });
                   #print Dumper ( sort keys %googleSearchStringHashofArrays );
                    @googleArray = ();
                    $count++;
                }    # End of for loop!!
            }    #  End of if condition on $pceBackupTokensNumber == 1
            elsif ( $pceBackupTokensNumber == 2 ) {
                print "Two BackupTerms are not supported right now!\n";
                print "Exiting ...\n";
                exit;
            }

#foreach $googleTokens (
#	sort { $googleSearchStringHashofArrays{$a} <=> $googleSearchStringHashofArrays{$b} }
#	keys %googleSearchStringHashofArrays ) {
            ##	#print "The key $googleTokens\n";
#	print "My set of DGGGoogle queries: $googleTokens @{ $googleSearchStringHashofArrays{$googleTokens} }\n";
#}
        }    # End of if condition on exists /BackupTerm/.
        else {

   #---------------------------------------------------------------------------
   #  This section deals with PCE that have a Primary Precedence group and no
   #  subsequent Backup Terms.  i.e. Only Google and PrefTerms after the Primary
   #  Precedence group.
   #---------------------------------------------------------------------------
            if ( $pcePrefTokensNumber == 1 ) {

            #print "This is the number of pceTokensNumbers: $pceTokensNumber\n";
                for ( my $i = 1 ; $i <= $pceTokensNumber ; $i++ ) {
                    if ( $i == 1 ) {
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /1precedenceGroupArray/ ) {
                                push @googleArray, $precedenceGroupArrayTerm;
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                        }
                    }
                    elsif ( $i == 2 ) {
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /1precedenceGroupArray/ ) {
                                push @googleArray, $precedenceGroupArrayTerm;
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                        }
                    }
                    if ( $precedenceGroupArrayCounter == 0 ) {
                        $googleSearchStringHashofArrays{$i} = [@googleArray];
                    }
                    elsif ( $precedenceGroupArrayCounter == 1 ) {
                        $googleSearchStringHashofArrays{ $i + 2 } =
                          [@googleArray];
                    }

                    #print Dumper (%googleSearchStringHashofArrays);
                    #print Dumper (@googleArray);
                    @googleArray = ();
                }

            }
            elsif ( $pcePrefTokensNumber == 2 ) {    # There are two PrefTerms.
                for ( my $i = 1 ; $i <= $pceTokensNumber + 1 ; $i++ ) {
                    if ( $i == 1 ) {
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /1precedenceGroupArray/ ) {
                                push @googleArray, $precedenceGroupArrayTerm;
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                        }
                    }
                    elsif ( $i == 2 ) {
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /1precedenceGroupArray/ ) {
                                push @googleArray, $precedenceGroupArrayTerm;
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm2/ ) {

                            #need to use tempArray for some string manipulation.
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                        }
                    }
                    elsif ( $i == 3 ) {
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /1precedenceGroupArray/ ) {
                                push @googleArray, $precedenceGroupArrayTerm;
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm1/ ) {

                            #need to use tempArray for some string manipulation.
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                        }
                    }
                    elsif ( $i == 4 ) {
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /1precedenceGroupArray/ ) {
                                push @googleArray, $precedenceGroupArrayTerm;
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm1/ ) {

                            #need to use tempArray for some string manipulation.
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm2/ ) {

                            #need to use tempArray for some string manipulation.
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                        }
                    }
                    if ( $precedenceGroupArrayCounter == 0 ) {
                        $googleSearchStringHashofArrays{$i} = [@googleArray];
                    }
                    elsif ( $precedenceGroupArrayCounter == 1 ) {
                        $googleSearchStringHashofArrays{ $i + 4 } =
                          [@googleArray];
                    }
                    #$googleSearchStringHashofArrays{$i} = [@googleArray];
                    @googleArray = ();
                }    # End of for loop.
            }

#for $googleTokens ( sort keys %googleSearchStringHashofArrays ) {
#    print "My set of Google queries: $googleTokens @{ $googleSearchStringHashofArrays{$googleTokens} }\n";
#}
        }    # End of Just Google and Pref terms control structure.
    }    # End of Precedence loop for its two terms.

#for $googleTokens ( sort keys %googleSearchStringHashofArrays ) {
#    print "My set of Google queries: $googleTokens @{ $googleSearchStringHashofArrays{$googleTokens} }\n";
#}
#foreach $googleTokens (
#			sort { $a <=> $b }
#			#sort { $googleSearchStringHashofArrays{$a} <=> $googleSearchStringHashofArrays{$b} }
#			keys %googleSearchStringHashofArrays ) {
#			print "My set of GGGoogle queries: $googleTokens @{ $googleSearchStringHashofArrays{$googleTokens} }\n";
#		}
#for $googleTokens ( sort (keys %googleSearchStringHashofArrays) ) {
#		    print "My set of Google queries: $googleTokens @{ $googleSearchStringHashofArrays{$googleTokens} }\n";
#		}
}    # End of if exists 1precedenceGroupArray

=begin  BlockComment  # Do I really need a second precedence group
						since the backup terms a left accociative.
elsif ( exists $pceSearchStringHashofArrays{'2precedenceGroupArray'} ||
		exists $pceSearchStringHashofArrays{'3precedenceGroupArray'}
) {

    # There will be only one set of google queries.
	print "Are we here?\n";
    print Dumper ( sort keys %pceSearchStringHashofArrays );
    for $pceTokens ( sort keys %pceSearchStringHashofArrays ) {
        print "My HoA: $pceTokens @{ $pceSearchStringHashofArrays{$pceTokens} }\n";
    }
}
=end    BlockComment  # BlockCommentNo_1

=cut

else {

    #---------------------------------------------------------------------------
    # This else statement handles PCEs which contain a only googleTerms,
    # pcePrefTerms ( U[AAA] ), or pceBackupTerms ( W[AAA] ).
    #---------------------------------------------------------------------------

#---------------------------------------------------------------------------
# The following if statement handles PCEs which contain a Backup Term ( W[AAA] )
#---------------------------------------------------------------------------
    if ( exists $pceSearchStringHashofArrays{'pceBackupTerm'} ) {
        if ( $pceBackupTokensNumber == 1 ) {
            foreach my $key ( sort keys %pceSearchStringHashofArrays )
            {    # Find out where the BackupTerm is.
                if ( $key =~ /BackupTerm/ ) {
                    $pos = substr( $key, 0, 1 );
                }
            }

            #print "BackupTerm Position is: $pos\n";

     #If there are a mix of PrefTerms and BackupTerms we need to deal with that.
     #print Dumper ( sort keys %pceSearchStringHashofArrays );
            if ( $pcePrefTokensNumber + $pceBackupTokensNumber == 3 ) {
                $numberOfIterationsNeeded = 6;
            }
            else {
                $numberOfIterationsNeeded = $pceTokensNumber;
            }
            for ( my $i = 1 ; $i <= $numberOfIterationsNeeded ; $i++ ) {
                if ( $i == 1 ) {

                    # First iteration we want all googleTerms and PrefTerms.
                    for $pceTokens ( sort keys %pceSearchStringHashofArrays ) {
                        if ( $pceTokens =~ /googleTerm/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pceBackupTerm1/ ) {

                            # Grab the value of the backupTerm
                            push @backupTerm1Array,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                    }
                }

                elsif ( $i == 2 ) {    # The second iteration.
                    if ( $pceTokensNumber == 2 ) {

    #---------------------------------------------------------------------------
    # Test to see if there is only one GoogleTerm and one Backup Term.
    # This is a special case.
    #---------------------------------------------------------------------------
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /googleTerm/ ) {

                                # Do nothing here.
                            }
                            elsif ( $pceTokens =~ /pceBackupTerm/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                        }
                    }
                    else {    # Not a special case.
                        if ( $i == $numberOfIterationsNeeded ) {

#---------------------------------------------------------------------------
# Test to see if this is the last time through.
# Special case where we create query with Google terms and negated Pref and Backup Terms.
#---------------------------------------------------------------------------
#print "This is the last time through on $i\n";
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /googleTerm/ ) {
                                    push @googleArray,
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                                elsif ( $pceTokens =~ /pceBackupTerm/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                            }
                        }
                        else {    # No this is NOT the last time through.
                            if ( $i == $pos - 1 )
                            { # Testing for when to do substitution of BackupTerm.
                                 #print "We have to do the Backup substitution here. $i\n";
                                for $pceTokens (
                                    sort keys %pceSearchStringHashofArrays )
                                {

                                    if (   $pceTokens =~ /1googleTerm/
                                        && $pos == 2 )
                                    {

                                # Special case of 1googleTerm and 2pceBackupTerm
                                        push @googleArray, @backupTerm1Array,;
                                    }
                                    elsif ( $pceTokens =~ /googleTerm/ ) {
                                        push @googleArray,
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                        if (
                                            exists $pceSearchStringHashofArrays{
                                                'pcePrefTerm2'} )
                                        {
                                            if ( 1 == $pos - 1 )
                                            { # Substitute the backup term for pcePrefTerm1
                                                push @googleArray,
                                                  @backupTerm1Array,;
                                            }
                                            else
                                            { # Just push pcePrefTerm1 onto the googleArray
                                                push @googleArray,
                                                  @{
                                                    $pceSearchStringHashofArrays{
                                                        $pceTokens} };
                                            }
                                        }
                                        else {
                                            if ( $i == $pos - 1 )
                                            { # Need pceBackupTerm to occur in the list of
                                                 # google queries before the negated pcePrefTerm2.
                                                push @googleArray,
                                                  @backupTerm1Array;
                                            }
                                            else {
                                                my @tempArray =
                                                  @{
                                                    $pceSearchStringHashofArrays{
                                                        $pceTokens} };
                                                $tempArray[0] =~ s/(\w)/-$1/;
                                                push @googleArray, @tempArray;
                                            }
                                        }
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                        if ( $i == $pos - 2 ) {

    #---------------------------------------------------------------------------
    # Need the negated backup term to occur in the list of
    # google queries before the negated pcePrefTerm2.
    #---------------------------------------------------------------------------
                                            push @googleArray,
                                              @backupTerm1Array;
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }

                                        if ( 2 == $pos - 1 )
                                        { # The backup term is meant for pcePrefTerm2.
                                            push @googleArray,
                                              @backupTerm1Array,;
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }
                                    }
                                }
                            }
                            else {

    #---------------------------------------------------------------------------
    # No substitution of BackupTerm on this iteration.
    # Second iteration we want all googleTerms and the most preferred PrefTerm.
    #---------------------------------------------------------------------------
                                for $pceTokens (
                                    sort keys %pceSearchStringHashofArrays )
                                {
                                    if ( $pceTokens =~ /googleTerm/ ) {
                                        push @googleArray,
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                        if (
                                            exists $pceSearchStringHashofArrays{
                                                'pcePrefTerm2'} )
                                        {
                                            push @googleArray,
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }
                                    }
                                    elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                        if ( $i == $pos - 2 ) {

    #---------------------------------------------------------------------------
    # Need the negated backup term to occur in the list of
    # google queries before the negated pcePrefTerm2.
    #---------------------------------------------------------------------------
                                            push @googleArray,
                                              @backupTerm1Array;
                                        }
                                        else {
                                            my @tempArray =
                                              @{
                                                $pceSearchStringHashofArrays{
                                                    $pceTokens} };
                                            $tempArray[0] =~ s/(\w)/-$1/;
                                            push @googleArray, @tempArray;
                                        }
                                    }
                                }
                            }

                        }    # End of test whether this is last time through.

                    } # End of if with condition $pceTokensNumber is something greater than 2

                }    # End of if with condition $i == 2

                elsif ( $i == 3 ) {    # The third iteration.
                    if ( $i == $pceTokensNumber ) {

    #---------------------------------------------------------------------------
    # Test to see if this is the last time through.
    # Special case where we create query with Google
    # terms and negated Pref and Backup Terms.
    #---------------------------------------------------------------------------
    #print "This is the last time through on $i\n";
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /googleTerm/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                            elsif ( $pceTokens =~ /pceBackupTerm/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                        }
                    }
                    else {   # This is not the last time through the loop so....
                        if ( $i == $pos - 1 )
                        {   # Testing for when to do substitution of BackupTerm.
                             #print "This is where We should do the Backup substitution. $i\n";
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {

            # :WARNING:02/25/2007:: I may need to do this twice if there are one
            # versus two prefTerms
                                if ( $pceTokens =~ /1googleTerm/ && $pos == 2 )
                                {

                                # Special case of 1googleTerm and 2pceBackupTerm
                                    push @googleArray, @backupTerm1Array;
                                }
                                elsif ( $pceTokens =~ /googleTerm/ ) {
                                    push @googleArray,
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    if (
                                        exists $pceSearchStringHashofArrays{
                                            'pcePrefTerm2'} )
                                    {
                                        push @googleArray,
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                    }
                                    else {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                    @tempArray = ();
                                    @tempArray = @backupTerm1Array;
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                            }
                        }
                        else {

    #---------------------------------------------------------------------------
    # No substitution this time so ...
    # Third iteration we want all googleTerms and the most preferred PrefTerm.
    #---------------------------------------------------------------------------
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /googleTerm/ ) {
                                    push @googleArray,
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    if (
                                        exists $pceSearchStringHashofArrays{
                                            'pcePrefTerm2'} )
                                    {
                                        push @googleArray,
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                    }
                                    else {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    if ( $i == $pos - 2 )
                                    { # Need the negated backup term to occur in the list of
                                         # google queries before the negated pcePrefTerm2.
                                        push @googleArray, @backupTerm1Array;
                                    }
                                    else {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                            }    # End of for loop.
                        }    # End of test if we are doing substitutions.
                    } # End of if ($i == $pceTokensNumber) i.e Last time through test
                }    # End of if condition $i == 3
                elsif ( $i == 4 ) {    # The fourth iteration.
                    if ( $i == $numberOfIterationsNeeded ) {

    #---------------------------------------------------------------------------
    # Test to see if this is the last time through.
    # Special case where we create query with Google
    # terms and negated Pref and Backup Terms.
    #---------------------------------------------------------------------------
    #print "This is the last time through on $i\n";
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /googleTerm/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                            elsif ( $pceTokens =~ /pceBackupTerm/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                        }
                    }
                    else {   # This is not the last time through the loop so....
                        if ( $i == $pos - 1 )
                        {   # Testing for when to do substitution of BackupTerm.
                             #print "This is where We should do the Backup substitution. $i\n";
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /1googleTerm/ && $pos == 2 )
                                {

                                # Special case of 1googleTerm and 2pceBackupTerm
                                    push @googleArray, @backupTerm1Array;
                                }
                                elsif ( $pceTokens =~ /googleTerm/ ) {
                                    push @googleArray,
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    if (
                                        exists $pceSearchStringHashofArrays{
                                            'pcePrefTerm2'} )
                                    {
                                        push @googleArray,
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                    }
                                    else {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                            }
                        }
                        else {

    #---------------------------------------------------------------------------
    # No substitution this time so ...
    # Fourth iteration we want all googleTerms and the most preferred PrefTerm
    # and a negated least preferred PrefTerm.
    #---------------------------------------------------------------------------
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /googleTerm/ ) {
                                    push @googleArray,
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    if (
                                        exists $pceSearchStringHashofArrays{
                                            'pcePrefTerm2'} )
                                    {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                    }
                                    else {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    if ( $i == $pos - 2 )
                                    { # Need the negated backup term to occur in the list of
                                         # google queries before the negated pcePrefTerm2.
                                        push @googleArray, @backupTerm1Array;
                                    }
                                    else {
                                        push @googleArray,
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };

                 #push @googleArray, @backupTerm1Array;
                 #my @tempArray = @{ $pceSearchStringHashofArrays{$pceTokens} };
                 #$tempArray[0] =~ s/(\w)/-$1/;
                 #push @googleArray, @tempArray;
                                    }
                                }
                            }    # End of for loop.
                        }    # End of test if we are doing substitutions.
                    } # End of if ($i == $pceTokensNumber) i.e Last time through test
                }    # End of if condition $i == 4
                elsif ( $i == 5 ) {    # The fifth iteration.
                    if ( $i == $numberOfIterationsNeeded ) {

    #---------------------------------------------------------------------------
    # Test to see if this is the last time through.
    # Special case where we create query with Google
    # terms and negated Pref and Backup Terms.
    #---------------------------------------------------------------------------
    #print "This is the last time through on $i\n";
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /googleTerm/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                            elsif ( $pceTokens =~ /pceBackupTerm/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                        }
                    }
                    else {   # This is not the last time through the loop so....
                        if ( $i == $pos - 1 )
                        {   # Testing for when to do substitution of BackupTerm.
                             #print "This is where We should do the Backup substitution. $i\n";
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /1googleTerm/ && $pos == 2 )
                                {

                                # Special case of 1googleTerm and 2pceBackupTerm
                                    push @googleArray, @backupTerm1Array;
                                }
                                elsif ( $pceTokens =~ /googleTerm/ ) {
                                    push @googleArray,
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    if (
                                        exists $pceSearchStringHashofArrays{
                                            'pcePrefTerm2'} )
                                    {
                                        push @googleArray,
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                    }
                                    else {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                            }
                        }
                        else {

    #---------------------------------------------------------------------------
    # No substitution this time so ...
    # Fifth iteration we want all googleTerms and the most preferred PrefTerm.
    #---------------------------------------------------------------------------
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /googleTerm/ ) {
                                    push @googleArray,
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    if (
                                        exists $pceSearchStringHashofArrays{
                                            'pcePrefTerm2'} )
                                    {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                    }
                                    else {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    if ( $i == $pos - 2 )
                                    { # Need the negated backup term to occur in the list of
                                         # google queries before the negated pcePrefTerm2.
                                        push @googleArray, @backupTerm1Array;
                                    }
                                    else {
                                        push @googleArray, @backupTerm1Array;

                 #my @tempArray = @{ $pceSearchStringHashofArrays{$pceTokens} };
                 #$tempArray[0] =~ s/(\w)/-$1/;
                 #push @googleArray, @tempArray;
                                    }
                                }
                            }    # End of for loop.
                        }    # End of test if we are doing substitutions.
                    } # End of if ($i == $pceTokensNumber) i.e Last time through test
                }    # End of if condition $i == 5
                elsif ( $i == 6 ) {    # The sixth iteration.
                    if ( $i == $numberOfIterationsNeeded ) {

    #---------------------------------------------------------------------------
    # Test to see if this is the last time through.
    # Special case where we create query with Google
    # terms and negated Pref and Backup Terms.
    #---------------------------------------------------------------------------
    #print "This is the last time through on $i\n";
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /googleTerm/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                            elsif ( $pceTokens =~ /pceBackupTerm/ ) {
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;
                            }
                        }
                    }
                    else {   # This is not the last time through the loop so....
                        if ( $i == $pos - 1 )
                        {   # Testing for when to do substitution of BackupTerm.
                             #print "This is where We should do the Backup substitution. $i\n";
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /1googleTerm/ && $pos == 2 )
                                {

                                # Special case of 1googleTerm and 2pceBackupTerm
                                    push @googleArray, @backupTerm1Array;
                                }
                                elsif ( $pceTokens =~ /googleTerm/ ) {
                                    push @googleArray,
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    if (
                                        exists $pceSearchStringHashofArrays{
                                            'pcePrefTerm2'} )
                                    {
                                        push @googleArray,
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                    }
                                    else {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    my @tempArray =
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                    $tempArray[0] =~ s/(\w)/-$1/;
                                    push @googleArray, @tempArray;
                                }
                            }
                        }
                        else {

    #---------------------------------------------------------------------------
    # No substitution this time so ...
    # Sixth iteration we want all googleTerms and the most preferred PrefTerm.
    #---------------------------------------------------------------------------
                            for $pceTokens (
                                sort keys %pceSearchStringHashofArrays )
                            {
                                if ( $pceTokens =~ /googleTerm/ ) {
                                    push @googleArray,
                                      @{
                                        $pceSearchStringHashofArrays{$pceTokens}
                                      };
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                                    if (
                                        exists $pceSearchStringHashofArrays{
                                            'pcePrefTerm2'} )
                                    {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                                    }
                                    else {
                                        my @tempArray =
                                          @{
                                            $pceSearchStringHashofArrays{
                                                $pceTokens} };
                                        $tempArray[0] =~ s/(\w)/-$1/;
                                        push @googleArray, @tempArray;
                                    }
                                }
                                elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                    if ( $i == $pos - 2 )
                                    { # Need the negated backup term to occur in the list of
                                         # google queries before the negated pcePrefTerm2.
                                        push @googleArray, @backupTerm1Array;
                                    }
                                    else {
                                        push @googleArray, @backupTerm1Array;

                 #my @tempArray = @{ $pceSearchStringHashofArrays{$pceTokens} };
                 #$tempArray[0] =~ s/(\w)/-$1/;
                 #push @googleArray, @tempArray;
                                    }
                                }
                            }    # End of for loop.
                        }    # End of test if we are doing substitutions.
                    } # End of if ($i == $pceTokensNumber) i.e Last time through test
                }    # End of if condition $i == 6

                else {

    #---------------------------------------------------------------------------
    # The last next iteration.  I have yet to deal with this.
    #---------------------------------------------------------------------------
                    if ( exists $pceSearchStringHashofArrays{'pcePrefTerm2'} ) {
                        for $pceTokens (
                            sort keys %pceSearchStringHashofArrays )
                        {
                            if ( $pceTokens =~ /googleTerm/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm1/ ) {

                            #need to use tempArray for some string manipulation.
                                my @tempArray =
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                                $tempArray[0] =~ s/(\w)/-$1/;
                                push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                            elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                                push @googleArray,
                                  @{ $pceSearchStringHashofArrays{$pceTokens} };
                            }
                        }
                    }
                }
                $googleSearchStringHashofArrays{$i} = [@googleArray];
                @googleArray = ();
                $count++;
            }    # End of for loop!!
        }    #  End of if condition on $pceBackupTokensNumber == 1
        elsif ( $pceBackupTokensNumber == 2 ) {
            print "Two BackupTerms are not supported right now!\n";
            print "Exiting ...\n";
            exit;
        }
    }    # End of if condition on exists /BackupTerm/.

 #---------------------------------------------------------------------------
 #  The following deals with PCEs which contain just google terms and PrefTerms.
 #  It expects only 1 or 2 PrefTerms, which is enforced above.
 #---------------------------------------------------------------------------
    else {
        if ( $pcePrefTokensNumber == 1 ) {

            #print "There is number of pceTokensNumbers: $pceTokensNumber\n";
            for ( my $i = 1 ; $i <= $pceTokensNumber ; $i++ ) {
                if ( $i == 1 ) {
                    for $pceTokens ( sort keys %pceSearchStringHashofArrays ) {
                        if ( $pceTokens =~ /googleTerm/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                    }
                }
                elsif ( $i == 2 ) {
                    for $pceTokens ( sort keys %pceSearchStringHashofArrays ) {
                        if ( $pceTokens =~ /googleTerm/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                            my @tempArray =
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                            $tempArray[0] =~ s/(\w)/-$1/;
                            push @googleArray, @tempArray;
                        }
                    }
                }
                $googleSearchStringHashofArrays{$i} = [@googleArray];
                @googleArray = ();
            }

        }
        elsif ( $pcePrefTokensNumber == 2 ) {    # There are two PrefTerms.
            for ( my $i = 1 ; $i <= $pceTokensNumber + 1 ; $i++ ) {
                if ( $i == 1 ) {
                    for $pceTokens ( sort keys %pceSearchStringHashofArrays ) {
                        if ( $pceTokens =~ /googleTerm/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                    }
                }
                elsif ( $i == 2 ) {
                    for $pceTokens ( sort keys %pceSearchStringHashofArrays ) {
                        if ( $pceTokens =~ /googleTerm/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pcePrefTerm1/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pcePrefTerm2/ ) {

                            #need to use tempArray for some string manipulation.
                            my @tempArray =
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                            $tempArray[0] =~ s/(\w)/-$1/;
                            push @googleArray, @tempArray;
                        }
                    }
                }
                elsif ( $i == 3 ) {
                    for $pceTokens ( sort keys %pceSearchStringHashofArrays ) {
                        if ( $pceTokens =~ /googleTerm/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pcePrefTerm1/ ) {

                            #need to use tempArray for some string manipulation.
                            my @tempArray =
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                            $tempArray[0] =~ s/(\w)/-$1/;
                            push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pcePrefTerm2/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                    }
                }
                elsif ( $i == 4 ) {
                    for $pceTokens ( sort keys %pceSearchStringHashofArrays ) {
                        if ( $pceTokens =~ /googleTerm/ ) {
                            push @googleArray,
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pcePrefTerm1/ ) {

                            #need to use tempArray for some string manipulation.
                            my @tempArray =
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                            $tempArray[0] =~ s/(\w)/-$1/;
                            push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                        elsif ( $pceTokens =~ /pcePrefTerm2/ ) {

                            #need to use tempArray for some string manipulation.
                            my @tempArray =
                              @{ $pceSearchStringHashofArrays{$pceTokens} };
                            $tempArray[0] =~ s/(\w)/-$1/;
                            push @googleArray, @tempArray;

              #push @googleArray, @{ $pceSearchStringHashofArrays{$pceTokens} };
                        }
                    }
                }
                $googleSearchStringHashofArrays{$i} = [@googleArray];
                @googleArray = ();
            }
        }
    }

#for $googleTokens ( sort keys %googleSearchStringHashofArrays ) {
#    print "My set of Google queries: $googleTokens @{ $googleSearchStringHashofArrays{$googleTokens} }\n";
#}
} # End of:  There are only googleTerms, pcePrefTerms or pceBackupTerms to deal with.

#
#
#
#
#
#
#

#---------------------------------------------------------------------------
#  This is the end of the processing.  We should have our hash called
#  %googleSearchStringHashofArrays full of real google queries.  Now we
#  need to send them to Google via the Google SOAP API.
#---------------------------------------------------------------------------
#foreach my $key ( sort keys %googleSearchStringHashofArrays ) {
for $googleTokens ( sort keys %googleSearchStringHashofArrays ) {

#print "$googleTokens:  $googleSearchStringHashofArrays{$googleTokens}\n";
#print "A new set of Google queries: $googleTokens @{ $googleSearchStringHashofArrays{$googleTokens} }\n";
#print "A new set of Google queries: $googleTokens\n";
#print "A new set of Google queries: @{ $googleSearchStringHashofArrays{$googleTokens} }\n";
#print "***TOP!***\n";
#print "@{ $googleSearchStringHashofArrays{$googleTokens} }\n";
#print Dumper (@{ $googleSearchStringHashofArrays{$googleTokens} });
#print "***BOT!***\n";

#my $query         = $siteRestriction . $googleSearchStringHashofArrays{$key};
#my $query         = $siteRestriction . @{ $googleSearchStringHashofArrays{$googleTokens} };
#my $gString        = join ( " ", @{ $googleSearchStringHashofArrays{$googleTokens} });
#print "My gString: $gString\n";
#my $query         = $siteRestriction . @{ $googleSearchStringHashofArrays{$googleTokens} };
    $query =
      $siteRestriction
      . join( " ", @{ $googleSearchStringHashofArrays{$googleTokens} } );
    print "Level $googleTokens query:  $query\n";
    my $google_search = SOAP::Lite->service("file:$google_wsdl");
    my $results       = $google_search->doGoogleSearch(
        $google_key, $query, 0,        10, "false", "",
        "false",     "",     "latin1", "latin1"
    );
    $googleResultsAoH[$googleTokens] = $results;
}

#print Dumper ( @googleResultsAoH );
#=begin  BlockComment  # BlockCommentNo_2

for my $i ( 1 .. $#googleResultsAoH ) {
    my $googleResults = $googleResultsAoH[$i]->{resultElements};
    print "\n";

    #print "The query:  $query\n";
    print "################# Start of Level $i Query Results ########\n";
    foreach my $result ( @{$googleResults} ) {
        my $url = $result->{URL};
        if ( $url =~ /index/ ) {

            # Don't print it.
        }
        else {
            print "$url\n";
        }
    }
    print "################# End of Level $i Query Results ##########\n\n";
}

#=end    BlockComment  # BlockCommentNo_2
#
#=cut

#

#
#foreach $googleTokens ( sort { $googleSearchStringHashofArrays{$b} <=> $googleSearchStringHashofArrays{$a} } keys %googleSearchStringHashofArrays)
#foreach $googleTokens ( sort { $googleSearchStringHashofArrays{$a} <=> $googleSearchStringHashofArrays{$b} } (keys %googleSearchStringHashofArrays))
#{
#print "MyGoogleToken: $googleTokens\n";
#    print "My set of GGGoogle queries: $googleTokens @{ $googleSearchStringHashofArrays{$googleTokens} }\n";
#}

#for $googleTokens ( sort keys %googleSearchStringHashofArrays ) {
#        print "My set of Google queries: $googleTokens @{ $googleSearchStringHashofArrays{$googleTokens} }\n";
#    }
#---------------------------------------------------------------------------
#  Debug stuff follows.
#---------------------------------------------------------------------------
#print "My HoA: $pceTokens @{ $pceSearchStringHashofArrays{$pceTokens} }\n";

#    if ( $pceTokens =~ /0precedenceGroupArray/ ) {
#		# If there is a 0precedenceGroupArray it means we are going to have to create two sets of google queries,
#		# one set for the google tokens and on for the backup constraint.
#        print "Precedence group:  $pceTokens: @{ $pceSearchStringHashofArrays{$pceTokens} }\n";
#
#}
#elsif ( $pceTokens =~ /pceTerm/ ) {
#    print "PCE Term:  $pceTokens: @{ $pceSearchStringHashofArrays{$pceTokens} }\n";
#
#    # Start making google queries and adding to an array of google
#    # search strings
#}

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
