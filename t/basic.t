use v6;
use Test;
use Hash::Consistent;

lives-ok {
    my $ch = Hash::Consistent.new(mult=>2);
}, "basic instantiation";

dies-ok {
    my $ch = Hash::Consistent.new();
}, "catch failure to include mult param";

done-testing;
