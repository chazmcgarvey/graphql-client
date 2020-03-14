package GraphQL::Client::http;
# ABSTRACT: GraphQL over HTTP

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

    my $url     = $options->{url} || $self->url;
    my $method  = $options->{method} || $self->method;

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

    return $self->_handle_response($self->_any_ua->request($method, $url, $options));
}

sub _handle_response {
    my $self = shift;
    my ($resp) = @_;

    my $handle_error = sub {
        my $resp = shift;

        return {
            errors => [
                {
                    message => "HTTP transport returned $resp->{status}: $resp->{content}",
                    x_transport_response => $resp,
                },
            ],
        };
    };
    my $handle_response = sub {
        my $resp = shift;

        return $handle_error->($resp) if !$resp->{success};
        return $self->json->decode($resp->{content});
    };

    if ($self->_any_ua->response_is_future) {
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

sub _any_ua {
    my $self = shift;
    $self->{_any_ua} //= HTTP::AnyUA->new(ua => $self->ua);
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

