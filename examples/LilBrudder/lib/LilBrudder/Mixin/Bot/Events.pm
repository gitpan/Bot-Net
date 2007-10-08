use strict;
use warnings;

package LilBrudder::Mixin::Bot::Events;
use base qw/ Bot::Net::Mixin /;

use Data::Remember POE => 'Memory';
use DateTime;
use DateTime::Format::ISO8601;
use Lingua::EN::Inflect qw/ PL /;
use POE;
use POE::Declarative;

sub register_triggers {
    my $self = shift;

    $self->add_trigger( on_start => sub { yield 'check_events' } );
}

on check_events => {
    my $now = DateTime->now( time_zone => recall [ config => 'time_zone' ] );
    my $df  = DateTime::Format::ISO8601->new( base_datetime => $now );

    my %default_alarms = (
        topic => DateTime::Duration->new(
            %{ recall [ config => defaults => alarms => 'topic' ] }
        ),
        public => DateTime::Duration->new(
            %{ recall [ config => defaults => alarms => 'public' ] }
        ),
    );

    for my $event (@{ 

1;
