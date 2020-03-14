package GraphQL::Client::http;
# ABSTRACT: GraphQL over HTTP

use 5.010;
use warnings;
use strict;

use HTTP::AnyUA::Util qw(www_form_urlencode);
use HTTP::AnyUA;

our $VERSION = '999.999'; # VERSION

sub new {
    my $class = shift;
    bless {@_}, $class;
}

sub request {
    my $self = shift;
    my ($request, $options) = @_;

    my $url     = delete $options->{url}    || $self->url;
    my $method  = delete $options->{method} || $self->method;

    my $data = {%$request};

    if ($method eq 'GET' || $method eq 'HEAD') {
        $data->{variables} = $self->json->encode($data->{variables}) if $data->{variables};
        my $params  = www_form_urlencode($data);
        my $sep     = $url =~ /\?/ ? '&' : '?';
        $url .= "${sep}${params}";
    }
    else {
        my $encoded_data = $self->json->encode($data);
        $options->{content} = $encoded_data;
        $options->{headers}{'content-length'} = length $encoded_data;
        $options->{headers}{'content-type'}   = 'application/json';
    }

    return $self->_handle_response($self->any_ua->request($method, $url, $options));
}

sub _handle_response {
    my $self = shift;
    my ($resp) = @_;

    my $handle_error = sub {
        my $resp = shift;

        my $data = eval { $self->json->decode($resp->{content}) };
        if ($@) {
            my $content = $resp->{content} // 'No content';
            my $reason  = $resp->{reason}  // '';
            $data = {
                errors => [
                    {
                        message => "HTTP transport returned $resp->{status} ($reason): $content",
                    },
                ],
            };
        }

        return ($data, 'graphql', $resp);
    };
    my $handle_response = sub {
        my $resp = shift;

        return $handle_error->($resp) if !$resp->{success};
        my $data = eval { $self->json->decode($resp->{content}) };
        if (my $err = $@) {
            warn $err if $ENV{GRAPHQL_CLIENT_DEBUG};
            $data = {
                errors => [
                    {
                        message => 'HTTP transport failed to decode response from GraphQL server.',
                    },
                ],
            };
        }
        return $data;
    };

    if ($self->any_ua->response_is_future) {
        return $resp->transform(
            done => $handle_response,
            fail => $handle_error,
        );
    }
    else {
        return $handle_response->($resp);
    }
}

sub ua {
    my $self = shift;
    $self->{ua} //= do {
        require HTTP::Tiny;
        HTTP::Tiny->new(
            agent   => "perl-graphql-client/$VERSION",
        );
    };
}

sub any_ua {
    my $self = shift;
    $self->{any_ua} //= HTTP::AnyUA->new(ua => $self->ua);
}

sub url {
    my $self = shift;
    $self->{url};
}

sub method {
    my $self = shift;
    $self->{method} // 'POST';
}

sub json {
    my $self = shift;
    $self->{json} //= do {
        require JSON::MaybeXS;
        JSON::MaybeXS->new(utf8 => 1);
    };
}

1;
__END__

=head1 SYNOPSIS

    my $transport = GraphQL::Client::http->new(
        url     => 'http://localhost:5000/graphql',
        method  => 'POST',
    );

    my $data = $client->request($query, $variables, $operation_name, $options);

=head1 DESCRIPTION

You probably shouldn't use this directly. Instead use L<GraphQL::Client>.

C<GraphQL::Client::http> is a GraphQL transport for HTTP. GraphQL is not required to be transported
via HTTP, but this is definitely the most common way.

This also serves as a reference implementation for future GraphQL transports.

=method new

    $transport = GraphQL::Client::http->new(%attributes);

Construct a new GraphQL HTTP transport.

=method request

    $response = $client->request(\%data, \%options);

Get a response from the GraphQL server.

The C<%data> structure must have a C<query> key whose value is the query or mutation string. It may
optionally have a C<variables> hashref an an C<operationName> string.

The C<%options> structure contains options passed through to the user agent.

The response will either be a hashref with the following structure or a L<Future> that resolves to
such a hashref:

    {
        data   => {...},
        errors => [...],
    }

=attr ua

A user agent, such as:

=for :list
* instance of a L<HTTP::Tiny> (this is the default if no user agent is provided)
* instance of a L<Mojo::UserAgent>
* the string C<"AnyEvent::HTTP">
* and more...

See L<HTTP::AnyUA/"SUPPORTED USER AGENTS">.

=attr any_ua

The L<HTTP::AnyUA> instance. Can be used to apply middleware if desired.

=attr method

The HTTP method to use when querying the GraphQL server. Can be one of:

=for :list
* C<GET>
* C<POST> (default)

=attr json

The L<JSON::XS> (or compatible) object used for encoding and decoding data structures to and from
the GraphQL server.

Defaults to a L<JSON::MaybeXS>.

=head1 SEE ALSO

L<https://graphql.org/learn/serving-over-http/>

