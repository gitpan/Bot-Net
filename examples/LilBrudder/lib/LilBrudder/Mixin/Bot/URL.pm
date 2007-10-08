use strict;
use warnings;

package LilBrudder::Mixin::Bot::URL;

use Bot::Net::Mixin;

use HTML::Entities;
use HTML::Scrubber;
use Lingua::EN::Summarize;
use LWP::UserAgent;
use Regexp::Common qw/ URI /;
use Text::Original;

use constant MAX_THROTTLE => 10;

sub filter_url {
    my $url  = shift;

    return if $url =~ m{^https?://localhost};
    return if $url =~ m{^https?://\d+};
    return if $url =~ m{^https?://[^\.]+/};

    my $url_filters = recall [ config => 'url_filters' ];
    for my $url_filter (@{ $url_filters || [] }) {
        return if $url =~ m{$_};
    }

    return $url;
}

on _start => run {
    yield 'mixin_bot_url_dethrottle';
};

on mixin_bot_url_dethrottle => run {
    my $throttle = recall([ mixin => bot => url => 'throttle' ]) || 0;
    remember [ mixin => bot => url => 'throttle' ] => $throttle - 1
        if $throttle > 0;

    my $log = recall 'log';
    $log->debug("Throttle decreased to @{[$throttle - 1]}") if $throttle;

    delay mixin_bot_url_dethrottle => 60;
};

sub user_agent {
    return LWP::UserAgent->new;
}

on [ qw/ bot_message_to_me bot_message_to_group / ] => run {
    my $event  = get ARG0;

    my $url_re = $RE{URI}{HTTP}{-scheme=>qr/https?/};

    my $log   = recall 'log';
    $log->info($event->message);
    $log->info(join ' ', ($event->message =~ m[\b($url_re)]i));

    my $url;
    if (($url) = $event->message =~ m[^summarize ($url_re)]i) {
        return unless filter_url($url);

        yield mixin_bot_url_summarize => $event, $url;
    }

    elsif (($url) = $event->message =~ m[\b($url_re)]i) {
        return unless filter_url($url);

        yield mixin_bot_url_title => $event, $url;
    }
};

on mixin_bot_url_title => run {
    my $event = get ARG0;
    my $url   = get ARG1;

    my $ua    = user_agent();
    my $log   = recall 'log';

    my $throttle = recall [ mixin => bot => rul => 'throttle' ] || 0;
    return if $throttle > MAX_THROTTLE;

    $log->info("### Identifying $url for @{[$event->sender_nick]}");

    my $response = $ua->get($url);
    if ($response->is_success) {
        if ($response->header('Content-type') =~ m[\btext/html\b]) {
            if ($response->content =~ m{<title>([^\<]+)</title>}) {
                my $title = $1;
                $title = first_sentence(decode_entities($title));

                my %title_words = map { lc $_ => 1 } split /\W+/, $title;
                my $word_total = scalar keys %title_words;
                my $words_removed = 0;
                for my $url_word (map { lc $_ } split /\W+/, $url) {
                    $words_removed += delete $title_words{$url_word} || 0;
                }
                my $word_score = $words_removed / $word_total;

                $log->info("$url / $title word score = $word_score");
                unless ($word_score >= 0.4) {
                    remember [ mixin => bot => url => 'throttle' ] => $throttle + 1;

                    yield reply_to_general => $event => "$url is $title";
                }
            }
        }
    }
    else {
#            yield reply_to_general => $event => "Uh, that URL, $url, is slow or no worky.";
    }
};

on mixin_bot_url_summarize => run {
    my $event = get ARG0;
    my $url   = get ARG1;

    my $ua    = user_agent();
    my $log   = recall 'log';

    my $throttle = recall [ mixin => bot => rul => 'throttle' ];
    return if $throttle > MAX_THROTTLE;
    remember [ mixin => bot => url => 'throttle' ] => $throttle + 8;

    $log->info("### Summarizing $url for @{[$event->sender_nick]}");

    my $response = $ua->get($url);
    if ($response->is_success) {
        if ($response->header('Content-type') =~ m[\btext/html\b]) {
            my $title = '<no title>';
            if (($title) = $response->content =~ m{<title>([^\<]+)</title>}) {

                $title = first_sentence(decode_entities($title));
            }

            my $scrub = HTML::Scrubber->new( deny => '*' );
            my $summary = summarize( $scrub->scrub( 
                    decode_entities( $response->content ) ) );

            yield reply_to_general => $event => "$url is $title : $summary";
        }

        else {
            yield reply_to_general => $event => "I don't know what $url is.";
        }
    }

    else {
        yield reply_to_general => $event => "Uh, that URL, $url, is too slow or no worky.";
    }
};

1;
