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

lives-ok {
    my $ch = Hash::Consistent.new(mult=>2);
    $ch.insert('example.org');
    $ch.insert('example.com');
    is $ch.sum_list.elems(), 4, 'correct hash cardinality';
    # > $ch.print();
    # 0: 2725249910 [crc32 of example.org.0 derived from example.org]
    # 1: 3210990709 [crc32 of example.com.1 derived from example.com]
    # 2: 3362055395 [crc32 of example.com.0 derived from example.com]
    # 3: 3581359072 [crc32 of example.org.1 derived from example.org]

    # > String::CRC32::crc32('blah');
    # 3458818396
    # (should find next at 3581359072 -> example.org)
    is $ch.find('blah'), 'example.org', 'found blah -> example.org';

    # > String::CRC32::crc32('whee');
    # 3023755156
    # (should find next at 3210990709 -> example.com)
    is $ch.find('whee'), 'example.com', 'found whee -> example.com';
}, 'find';

done-testing;
