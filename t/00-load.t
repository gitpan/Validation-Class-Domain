use utf8;
use strict;
use warnings;
use Test::More;

{

    use_ok 'Validation::Class::Domain';

}

{

    package TestClass;

    use Validation::Class::Domain;

    field  'title';
    field  'rating';
    field  'name';

    field  'id' => { filters => ['numeric'] };

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

    my $class;

    eval { $class = TestClass->new; };

    ok "TestClass" eq ref $class, "TestClass instantiated";

    my $domains = $class->prototype->settings->get('domains');

    ok "Validation::Class::Mapping" eq ref $domains, "TestClass domains registered as setting";

    ok 1 == $domains->count, "TestClass has 1 registered domain";

    my $person = $domains->get('person');

    ok 8 == keys %{$person}, "TestClass person domain has 6 mappings";

    can_ok $class, 'validate_domain';

    my $person = {
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

    ok $class->validate_domain(person => $person), "TestClass domain (person) validated";
    ok $person->{id} !~ /\D/, "person document has been filtered";

}

done_testing;
