##
# name:      Pegex::Pegex::Emitter::Perl6Regex
# abstract:  Compile Pegex Grammar to Perl 6 Regex
# author:    Ingy döt Net <ingy@ingy.net>
# license:   perl
# copyright: 2011

use 5.010;
use strict;
use warnings;

use Pegex 0.18 ();

package Pegex::Pegex::Emitter::Perl6Regex;
use Pegex::Mo;
extends 'Pegex::Receiver';

my %prefixes = (
    '!' => ['+asr', -1],
    '=' => ['+asr', 1],
    '.' => '-skip',
    '-' => '-pass',
    '+' => '-wrap',
);

sub got_grammar {
    my ($self, $rules) = @_;
    my $grammar = {
        '+top' => $self->top,
        %{$self->extra_rules},
    };
    for (@$rules) {
        my ($key, $value) = %$_;
        $grammar->{$key} = $value;
    }
    return $grammar;
}

sub got_rule_definition {
    my ($self, $match) = @_;
    my $name = $match->[0];
    $self->{top} = $name if $name eq 'TOP';
    $self->{top} ||= $name;
    my $value = $match->[1];
    return +{ $name => $value };
}

sub got_bracketed_group {
    my ($self, $match) = @_;
    my $group = $match->[1];
    if (my $prefix = $match->[0]) {
        $group->{$prefixes{$prefix}} = 1;
    }
    if (my $suffix = $match->[-1]) {
        $self->set_quantity($group, $suffix);
    }
    return $group;
}

sub got_all_group {
    my ($self, $match) = @_;
    my $list = $self->get_group($match);
    die unless @$list;
    return $list->[0] if @$list == 1;
    return { '.all' => $list };
}

sub got_any_group {
    my ($self, $match) = @_;
    my $list = $self->get_group($match);
    die unless @$list;
    return $list->[0] if @$list == 1;
    return { '.any' => $list };
}

sub get_group {
    my ($self, $group) = @_;
    sub get {
        my $it = shift;
        my $ref = ref($it) or return;
        if ($ref eq 'HASH') {
            return($it || ());
        }
        elsif ($ref eq 'ARRAY') {
            return map get($_), @$it;
        }
        else {
            die;
        }
    };
    return [ get($group) ];
}

sub got_rule_part {
    my ($self, $part) = @_;
    my ($rule, $sep_op, $sep_rule) = @$part;
    if ($sep_rule) {
        $sep_rule->{'+eok'} = 1
            if $sep_op eq '%%';
        $rule->{'.sep'} = $sep_rule;
    }
    return $rule;
}

sub got_rule_reference {
    my ($self, $match) = @_;
    my ($prefix, $ref, $suffix) = @$match;
    my $node = +{ '.ref' => $ref };
    if (my $regex = Pegex::Grammar::Atoms->atoms->{$ref}) {
        $self->extra_rules->{$ref} = +{ '.rgx' => $regex };
    }
    if ($suffix) {
        $self->set_quantity($node, $suffix);
    }
    if ($prefix) {
        my ($key, $val) = ($prefixes{$prefix}, 1);
        ($key, $val) = @$key if ref $key;
        $node->{$key} = $val;
    }
    return $node;
}

sub got_regular_expression {
    my ($self, $match) = @_;
    return +{ '.rgx' => $match };
}

sub got_error_message {
    my ($self, $match) = @_;
    return +{ '.err' => $match };
}

sub set_quantity {
    my ($self, $object, $quantifier) = @_;
    if ($quantifier eq '*') {
        $object->{'+min'} = 0;
    }
    elsif ($quantifier eq '+') {
        $object->{'+min'} = 1;
    }
    elsif ($quantifier eq '?') {
        $object->{'+max'} = 1;
    }
    elsif ($quantifier =~ /^(\d+)\+$/) {
        $object->{'+min'} = $1;
    }
    elsif ($quantifier =~ /^(\d+)\-(\d+)+$/) {
        $object->{'+min'} = $1;
        $object->{'+max'} = $2;
    }
    elsif ($quantifier =~ /^(\d+)$/) {
        $object->{'+min'} = $1;
        $object->{'+max'} = $1;
    }
    else { die "Invalid quantifier: '$quantifier'" }
}

1;

=head1 SYNOPSIS

    Pegex::Pegex::Grammar->new(
        receiver => 'Pegex::Pegex::Emitter::Perl6Regex',
    )->parse("your_grammar.pgx");

=head1 DESCRIPTION

This module is a receiver for L<Pegex::Pegex::Grammar>. It produces a Perl 6
Regex from a Pegex grammar.

This is very useful when porting Pegex application to Perl 6.
