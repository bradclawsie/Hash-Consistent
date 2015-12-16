use v6;
use Test;
use Hash::Consistent;

lives-ok {
    my $ch = Hash::Consistent.new(mult=>2);
}, "basic instantiation";

dies-ok {
    my $ch = Hash::Consistent.new();
}, "catch failure to include mult param";

lives-ok {
    my $ch = Hash::Consistent.new(mult=>True);
}, "catch failure to include mult param as PosInt (1)";

dies-ok {
    my $ch = Hash::Consistent.new(mult=>0);
}, "catch failure to include mult param as PosInt (2)";

lives-ok {
    my $ch = Hash::Consistent.new(mult=>2);
    my $ch_clone = $ch.clone;
    is $ch_clone.mult, 2;
}, "empty clone";

done-testing;
