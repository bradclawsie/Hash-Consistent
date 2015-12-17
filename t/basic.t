use v6;
use Test;
use Hash::Consistent;

lives-ok {
    my $ch = Hash::Consistent.new(mult=>2);
}, 'basic instantiation';

dies-ok {
    my $ch = Hash::Consistent.new();
}, 'catch failure to include mult param';

dies-ok {
    my $ch = Hash::Consistent.new(mult=>'hello');
}, 'catch failure to include mult param as PosInt (1)';

dies-ok {
    my $ch = Hash::Consistent.new(mult=>0);
}, 'catch failure to include mult param as PosInt (2)';

lives-ok {
    my $ch = Hash::Consistent.new(mult=>2);
    isa-ok($ch,Hash::Consistent,'isa Hash::Consistent');
    my $ch_clone = $ch.clone;
    isa-ok($ch_clone,Hash::Consistent,'clone isa Hash::Consistent');
    is $ch_clone.mult, 2, 'empty clone has right mult';
}, 'clone';

lives-ok {
    my $ch = Hash::Consistent.new(mult=>2);
    $ch.insert('hello');
    $ch.insert('there');
    is $ch.sum_list.elems(), 4, 'correct hash cardinality';
}, 'cardinality';

done-testing;
