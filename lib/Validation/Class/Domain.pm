# ABSTRACT: Data Validation for Hierarchical Data

package Validation::Class::Domain;

use utf8;
use strict;
use warnings;

use Validation::Class ();
use Validation::Class::Exporter;
use Validation::Class::Mapping;

use Hash::Flatten 'flatten', 'unflatten';
use Carp 'croak';

Validation::Class::Exporter->apply_spec(
    routines => ['dom', 'domain', 'validate_domain', 'domain_validates'],
);

sub dom { goto &domain } sub domain {

    my $package = shift if @_ == 3;

    my ($name, $data) = @_;

    $data ||= {};

    return unless ($name && $data);

    return Validation::Class::configure_class_proto( $package => sub {

        my ($proto) = @_;

        my $settings = $proto->configuration->settings;

        my $domains  = $settings->{domains} ||= Validation::Class::Mapping->new;

        $domains->add($name => $data);

        return $proto;

    })

};

sub domain_validates { goto &validate_domain } sub validate_domain {

    my ($self, $name, $data) = @_;

    my $proto  = $self->prototype;
    my $fields = { map {$_ => 1} ($proto->fields->keys) };

    croak "Please supply a registered domain name to validate against"
        unless $name
    ;

    my $domains = $proto->settings->get('domains');

    croak "The ($name) domain is not registered and cannot be validated against"
        unless $name && $domains->has($name)
    ;

    my $domain = $domains->get($name);

    croak "The ($name) domain does not contain any mappings and cannot ".
          "be validated against" unless keys %{$domains}
    ;

    for my  $key (keys %{$domain}) {

        my  $value = delete $domain->{$key};
            $key   = quotemeta($key);

        my  $token;
        my  $regex;

            $token  = '\\\.\\\@';
            $regex  = '\:\d+';
            $key    =~ s/$token/$regex/g;

            $token  = '\\\\\\*';
            $regex  = '\w+';
            $key    =~ s/$token/$regex/g;

        $domain->{$key} = $value;

    }

    my $_dmap = {};
    my $_pmap = {};

    my $_data = flatten $data;

    for my $key (keys %{$_data}) {

        for my $regex (keys %{$domain}) {

            if (defined $_data->{$key}) {

                if ($key =~ /^$regex$/) {

                    my  $field = $domain->{$regex};
                    my  $point = $key;
                        $point =~ s/\W/_/g;
                    my  $label = $key;
                        $label =~ s/\:/./g;

                    $proto->params->add($point => $_data->{$key});
                    $proto->clone_field($field => $point, {label => $label});
                    $proto->queue("+$point"); # queue and force requirement

                    $_dmap->{$key}   = 1;
                    $_pmap->{$point} = $key;

                }

            }

        }

    }

    $_dmap = unflatten $_dmap;

    my $result = $proto->validate($self);
    my @errors = $proto->get_errors;

    while (my($point, $key) = each(%{$_pmap})) {
        $_data->{$key} = $proto->params->get($point); # prepare data
        $proto->fields->delete($point) unless $fields->{$point}; # reap clones
    }

    $proto->reset_fields;

    $proto->set_errors(@errors) if @errors; # report errors

    $_[2] = unflatten $_data if defined $_[2]; # restore data

    return $result;

}


1;

__END__

=pod

=head1 NAME

Validation::Class::Domain - Data Validation for Hierarchical Data

=head1 VERSION

version 0.000002

=head1 SYNOPSIS

    package MyApp::Person;

    use Validation::Class::Domain;

    field  'id';
    field  'title';
    field  'rating';

    field  'name' => {
        mixin     => ':str',
        pattern   => qr/^(?!evil)/
    };

    domain 'person' => {
        'id'                                   => 'id',
        'name'                                 => 'name',
        'title'                                => 'title',
        'company.name'                         => 'name',
        'company.supervisor.name'              => 'name',
        'company.supervisor.rating.@.support'  => 'rating',
        'company.supervisor.rating.@.guidance' => 'rating',
        'company.tags.@'                       => 'name'
    };

    package main;

    my $data = {
        "id"      => "1234-ABC",
        "name"    => "Anita Campbell-Green",
        "title"   => "Designer",
        "company" => {
            "name"       => "House of de Vil",
            "supervisor" => {
                "name"   => "Cruella de Vil",
                "rating" => [
                    {   "support"  => -9,
                        "guidance" => -9
                    }
                ]
            },
            "tags" => [
                "evil",
                "cruelty",
                "dogs"
            ]
        },
    };

    my $person = MyApp::Person->new;

    unless ($person->validate_domain(person => $data)) {
        warn $person->errors_to_string if $person->error_count;
    }

=head1 DESCRIPTION

This module allows you to validate hierarchical structures using the
L<Validation::Class> framework. This is an experimental yet highly promising
approach toward the consistent processing of nested structures. This module was
inspired by L<MooseX::Validation::Doctypes>.

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
