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
    has NonEmptyStr %.source;       # The mapping of crc32 hash values -> their original source string
    has Lock $!lock;                # Lock operations that examine or change the state of the consistent hash.
    has PosInt %!hashed;            # A cache of previously computed crc32 hashes.

    submethod BUILD(PosInt:D :$mult) {
        warn "warning: coercing True to 1" if $mult ~~ Bool; # PosInt includes perl6 says Int(True) => 1
        $!mult := $mult;
        $!lock = Lock.new;
    }

    multi method print() returns Bool:D {
        $!lock.protect(
            {
                my $j = 0;
                for self!sorted_hashes() -> $i {
                    say "$j: $i [crc32 of %!source{$i}]";
                    $j++;
                }
            }
        );            
    }

    method !mult_elt(NonEmptyStr:D $s,Cool:D $i) {
        return $s ~ '.' ~ Str($i);
    }

    method !sorted_hashes() {
        return %!source.keys.map( { Int($_) } ).sort;    
    }

    # Cache CRC32 hashes.
    method !getCRC32(NonEmptyStr:D $s) {
        return %!hashed{$s} if %!hashed{$s}:exists;
        my PosInt $crc32 = String::CRC32::crc32($s);
        %!hashed{$s} = $crc32;
        return $crc32;
    }
    
    method find(NonEmptyStr:D $s) returns NonEmptyStr:D {
        # $v will be our return value, the token that hashed into the value that was
        # immediately > the hash value for $s. If it is '', that will be an error given
        # that our source map hashes only to non empty strings.
        my $v = '';
        
        $!lock.protect(
            {
                my $source_crc32 = 0; # A key of 0 is an error in a hash of NonEmptyStr(PosInt) -> NonemptyStr
                my $n = %!source.keys.elems;
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
                    $source_crc32 = @!sum_list[0];
                } else {
                    for @!sum_list -> $i {
                        if $i > $crc32 {
                            $source_crc32 = $i;
                            last;
                        }
                    }
                }

                # We did not locate a source_crc32, or the source_crc32 is not in the source map.
                if ($source_crc32 == 0) || (!(%!source{$crc32}:exists)) {
                    X::Hash::Consistent::Corrupt.new(input => $source_crc32).throw;
                }

                $v = %!source{$crc32};
            }
        );
        if ($v == '') {
            X::Hash::Consistent::Corrupt.new(input => $s).throw;
        }
        return $v;
    }

   method !remove_one(NonEmptyStr:D $s) {
       my PosInt $crc32 = self!getCRC32($s);
       my $in_list = ($crc32 == @!sum_list.any);
       my $in_source = %!source{$crc32}:exists;
       return if (!$in_list && !$in_source); # Not in the consistent hash.
       if ($in_list && $in_source) {
           %!source{$crc32}:delete;
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
                       self!remove_one(self!mult_elt($s,$i));
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

    method !insert_one(NonEmptyStr:D $s) {
        my PosInt $crc32 = self!getCRC32($s);
        say "$s gives $crc32";
        if $crc32 == @!sum_list.any {
            if %!source{$crc32}:exists {
                # Just return, the string is already in the consistent hash.
                return; 
            } else {
                # The string is not in the consistent hash yet produces a crc32
                # that collides with an existing entry.
                X::Hash::Consistent::Collision.new(input => $s,hashed => $crc32).throw;
            }
        }
        %!source{$crc32} = $s;
        @!sum_list = self!sorted_hashes();
        return;
    }
    
    method insert(NonEmptyStr:D $s) {
       $!lock.protect(
           {
               for ^$!mult -> $i {
                   try {
                       self!insert_one(self!mult_elt($s,$i));
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

