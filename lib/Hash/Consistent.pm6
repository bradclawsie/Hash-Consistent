#!/usr/bin/env perl6

use v6;
use String::CRC32;
use Subsets::Common;

unit module Hash::Consistent:auth<bradclawsie>:ver<0.0.1>;

class X::Hash::Consistent::Collision is Exception is export {
    has $.input;
    has $.hashed;
    method message() { "With $.input, collision on $.hashed in consistent hash" }
}

class X::Hash::Consistent::Corrupt is Exception is export {
    has $.input;
    method message() { "With token $.input, consistent hash is corrupt" }
}

class X::Hash::Consistent::InsertFailure is Exception is export {}
class X::Hash::Consistent::RemoveFailure is Exception is export {}
class X::Hash::Consistent::IsEmpty is Exception is export {}

class Hash::Consistent is export {
    
    has PosInt $.mult is required;  # The number of times to multiply each entry in the consistent hash.
    has PosInt @.sum_list;          # The list of crc32 hashes, maintained in sorted order.
    has NonEmptyStr %!mult_source;  # The mapping of crc32 hash values to the corresponding "mult" string.
    has NonEmptyStr %!source;       # The mapping of the mult_source string to the original input string.
    has Lock $!lock;                # Lock operations that examine or change the state of the consistent hash.
    has PosInt %!hashed;            # A cache of previously computed crc32 hashes.

    submethod BUILD(PosInt:D :$mult) {
        $!mult := $mult;
        $!lock = Lock.new;
    }

    multi method print() returns Bool:D {
        $!lock.protect(
            {
                my $j = 0;
                for self!sorted_hashes() -> $i {
                    say "$j: $i [crc32 of %!mult_source{$i} derived from %!source{%!mult_source{$i}}]";
                    $j++;
                }
            }
        );            
    }

    my sub mult_elt(NonEmptyStr:D $s,Cool:D $i) {
        return $s ~ '.' ~ Str($i);
    }

    method !sorted_hashes() {
        return %!mult_source.keys.map( { Int($_) } ).sort;    
    }

    # Cache CRC32 hashes.
    method !getCRC32(NonEmptyStr:D $s) {
        return %!hashed{$s} if %!hashed{$s}:exists;
        my PosInt $crc32 = String::CRC32::crc32($s);
        %!hashed{$s} = $crc32;
        return $crc32;
    }
    
    method find(NonEmptyStr:D $s) returns NonEmptyStr:D {
        $!lock.protect(
            {
                my Int $mult_source_crc32 = 0; 
                my $n = %!mult_source.keys.elems;
                if (@!sum_list.elems != $n) {
                    X::Hash::Consistent::Corrupt.new(input => $s).throw;
                }
                if $n == 0 {
                    X::Hash::Consistent::IsEmpty.new(payload => 'Cannot find in empty consistent hash').throw;
                }
                my PosInt $crc32 = self!getCRC32($s);
                if ($n == 1) || ($crc32 >= @!sum_list[$n-1]) {
                    # If there is only one element in sum_list, or, if given crc32 is greater than the last
                    # element in the list, then return the 0th element. 
                    $mult_source_crc32 = @!sum_list[0];
                } else {
                    for @!sum_list -> $i {
                        if $i > $crc32 {
                            $mult_source_crc32 = $i;
                            last;
                        }
                    }
                }

                unless %!source{%!mult_source{$mult_source_crc32}}:exists {  
                    X::Hash::Consistent::Corrupt.new(input => $mult_source_crc32).throw;
                }
                return %!source{%!mult_source{$mult_source_crc32}};
            }
        );
    }

   method !remove_one(NonEmptyStr:D $s) {
       my PosInt $crc32 = self!getCRC32($s);
       my $in_list = ($crc32 == @!sum_list.any);
       my $in_mult_source = %!mult_source{$crc32}:exists;
       return if (!$in_list && !$in_mult_source); # Not in the consistent hash.
       if ($in_list && $in_mult_source) {
           %!mult_source{$crc32}:delete;
           @!sum_list = self!sorted_hashes();
           return;
       } else {
           # The instance is corrupt, the string is in only one of the structures.
           X::Hash::Consistent::Corrupt.new(input => $s).throw;
       }
   }
   
   method remove(NonEmptyStr:D $s) {
       $!lock.protect(
           {
               for ^$!mult -> $i {
                   try {
                       self!remove_one(mult_elt($s,$i));
                       CATCH {
                           default {
                               X::Hash::Consistent::RemoveFailure.new(payload => $!.message()).throw;
                           }
                       }
                   }
               }
           }
       );
    }

    method !insert_one(NonEmptyStr:D $mult_s,$s) {
        my PosInt $crc32 = self!getCRC32($mult_s);
        if $crc32 == @!sum_list.any {
            if %!mult_source{$crc32}:exists {
                # Just return, the string is already in the consistent hash.
                return; 
            } else {
                # The string is not in the consistent hash yet produces a crc32
                # that collides with an existing entry.
                X::Hash::Consistent::Collision.new(input => $mult_s,hashed => $crc32).throw;
            }
        }
        %!mult_source{$crc32} = $mult_s;
        @!sum_list = self!sorted_hashes();
        %!source{$mult_s} = $s;
        return;
    }
    
    method insert(NonEmptyStr:D $s) {
       $!lock.protect(
           {
               for ^$!mult -> $i {
                   try {
                       self!insert_one(mult_elt($s,$i),$s);
                       CATCH {
                           default {
                               # If any insert failed, we must remove any insertions made for $s.
                               self.remove($s);
                               X::Hash::Consistent::InsertFailure.new(payload => $!.message()).throw;
                           }
                       }
                   }
               }
           }
       );
    }
}

