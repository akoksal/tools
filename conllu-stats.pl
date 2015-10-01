#!/usr/bin/perl
# Reads CoNLL(-U) data from STDIN, collects all features (FEAT column, delimited by vertical bars) and prints them sorted to STDOUT.
# Copyright © 2013-2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

# Argument "2009" toggles the CoNLL 2009 data format.
my $format = shift;
my $i_feat_column = $format eq '2009' ? 6 : 5;

my $ntok = 0;
my $nsent = 0;
while(<>)
{
    # Skip comment lines (new in CoNLL-U).
    next if(m/^\#/);
    # Skip lines with fused tokens (they do not contain features; this is new in CoNLL-U).
    next if(m/^(\d+)-(\d+)\t/);
    if(m/^\s*$/)
    {
        $nsent++;
    }
    else
    {
        $ntok++;
        # Get rid of the line break.
        s/\r?\n$//;
        # Split line into columns.
        my @columns = split(/\s+/, $_);
        # Remember the occurrence of the universal POS tag.
        $tagset{$columns[3]}++;
        # We can also print example lemmas that had the tag.
        $examples{$columns[3]}{$columns[2]}++;
        # Remember the occurrence of each feature-value pair.
        my $features = $columns[$i_feat_column];
        # Skip if there are no features.
        unless($features eq '_')
        {
            my @features = split(/\|/, $features);
            my $form = $columns[1];
            my $upos = $columns[3];
            foreach my $feature (@features)
            {
                $featureset{$feature}++;
                # We can also list tags with which the feature occurred.
                $upos{$feature}{$upos}++;
                # We can also print example words that had the feature.
                $examples{$feature}{$form}++;
            }
        }
        # Remember the occurrence of each dependency relation.
        my $deprel = $columns[7];
        $deprelset{$deprel}++;
    }
}
# Sort the features alphabetically before printing them.
@tagset = sort(keys(%tagset));
@featureset = sort {lc($a) cmp lc($b)} (keys(%featureset));
@deprelset = sort(keys(%deprelset));
# Examples may contain uppercase letters only if all-lowercase version does not exist.
foreach my $key (@tagset, @featureset)
{
    my @examples = keys(%{$examples{$key}});
    foreach my $example (@examples)
    {
        if(lc($example) ne $example && exists($examples{$key}{lc($example)}))
        {
            $examples{$key}{lc($example)} += $examples{$key}{$example};
            delete($examples{$key}{$example});
        }
    }
}
# Print the list of universal tags as an XML structure that can be used in the treebank description XML file.
print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
print("<treebank>\n");
print << EOF
  <!-- tokens means "surface tokens", e.g. Spanish "vámonos" counts as one token
       words means "syntactic words", e.g. Spanish "vámonos" is split to two words, "vamos" and "nos"
       fused is the number of tokens that are split to two or more syntactic words
       The words and fused elements can be omitted if no token is split to smaller syntactic words. -->
EOF
;
print("  <size>\n");
print("    <total><sentences>$nsent</sentences><tokens>$ntok</tokens></total>\n");
###!!! We do not know what part of the data is for training, development or testing. We would have to change the calling syntax.
#print("    <train></train>\n");
#print("    <dev></dev>\n");
#print("    <test></test>\n");
print("  </size>\n");
print("  <!-- Statistics of universal POS tags. The comments with the most frequent lemmas are optional (but easy to obtain). -->\n");
print("  <tags unique=\"".scalar(@tagset)."\">\n");
foreach my $tag (@tagset)
{
    my @examples = sort
    {
        my $result = $examples{$tag}{$b} <=> $examples{$tag}{$a};
        unless($result)
        {
            $result = $a cmp $b;
        }
        $result
    }
    (keys(%{$examples{$tag}}));
    splice(@examples, 10);
    print('    <tag name="'.$tag.'">'.$tagset{$tag}.'</tag><!-- ', join(', ', @examples), " -->\n");
}
print("  </tags>\n");
# Print the list of features as an XML structure that can be used in the treebank description XML file.
print("  <!-- Statistics of features and values. The comments with the most frequent word forms are optional (but easy to obtain). -->\n");
print("  <feats unique=\"".scalar(@featureset)."\">\n");
foreach my $feature (@featureset)
{
    my @examples = sort
    {
        my $result = $examples{$feature}{$b} <=> $examples{$feature}{$a};
        unless($result)
        {
            $result = $a cmp $b;
        }
        $result
    }
    (keys(%{$examples{$feature}}));
    splice(@examples, 10);
    my $upostags = join(',', sort(keys(%{$upos{$feature}})));
    my ($name, $value) = split(/=/, $feature);
    print('    <feat name="'.$name.'" value="'.$value.'" upos="'.$upostags.'">'.$featureset{$feature}.'</feat><!-- ', join(', ', @examples), " -->\n");
}
print("  </feats>\n");
# Print the list of dependency relations as an XML structure that can be used in the treebank description XML file.
print("  <!-- Statistics of universal dependency relations. -->\n");
print("  <deps unique=\"".scalar(@deprelset)."\">\n");
foreach my $deprel (@deprelset)
{
    print('    <dep name="'.$deprel.'">'.$deprelset{$deprel}."</dep>\n");
}
print("  </deps>\n");
print("</treebank>\n");
