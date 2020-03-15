package GraphQL::Client::http;
# ABSTRACT: GraphQL over HTTP

use 5.010;
use warnings;
use strict;

use HTTP::AnyUA::Util qw(www_form_urlencode);
use HTTP::AnyUA;
use namespace::clean;

our $VERSION = '999.999'; # VERSION

sub _croak { require Carp; goto &Carp::croak }

sub new {
    my $class = shift;
    my $self  = @_ % 2 == 0 ? {@_} : $_[0];
    bless $self, $class;
}

sub execute {
    my $self = shift;
    my ($request, $options) = @_;

    my $url     = delete $options->{url}    || $self->url;
    my $method  = delete $options->{method} || $self->method;

    $request && ref($request) eq 'HASH' or _croak q{Usage: $http->execute(\%request)};
    $request->{query} or _croak q{Request must have a query};
    $url or _croak q{URL must be provided};

    my $data = {%$request};

    if ($method eq 'GET' || $method eq 'HEAD') {
        $data->{variables} = $self->json->encode($data->{variables}) if $data->{variables};
        my $params  = www_form_urlencode($data);
        my $sep     = $url =~ /^[^#]+\?/ ? '&' : '?';
        $url =~ s/#/${sep}${params}#/ or $url .= "${sep}${params}";
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

    if (eval { $resp->isa('Future') }) {
        return $resp->followed_by(sub {
            my $f = shift;

            if (my ($exception, $category, @other) = $f->failure) {
                if (ref $exception eq 'HASH') {
                    my $resp = $exception;
                    return Future->done($self->_handle_error($resp));
                }

                return Future->done({
                    error       => $exception,
                    response    => undef,
                    details     => {
                        exception_details => [$category, @other],
                    },
                });
            }

            my $resp = $f->get;
            return Future->done($self->_handle_success($resp));
        });
    }
    else {
        return $self->_handle_error($resp) if !$resp->{success};
        return $self->_handle_success($resp);
    }
}

sub _handle_error {
    my $self = shift;
    my ($resp) = @_;

    my $data    = eval { $self->json->decode($resp->{content}) };
    my $content = $resp->{content} // 'No content';
    my $reason  = $resp->{reason}  // '';
    my $message = "HTTP transport returned $resp->{status} ($reason): $content";

    return {
        error       => $message,
        response    => $data,
        details     => {
            http_response   => $resp,
        },
    };
}

sub _handle_success {
    my $self = shift;
    my ($resp) = @_;

    my $data = eval { $self->json->decode($resp->{content}) };
    if (my $exception = $@) {
        return {
            error       => "HTTP transport failed to decode response: $exception",
            response    => undef,
            details     => {
                http_response   => $resp,
            },
        };
    }

    return {
        response    => $data,
        details     => {
            http_response   => $resp,
        },
    };
}

sub ua {
    my $self = shift;
    $self->{ua} //= do {
        require HTTP::Tiny;
        HTTP::Tiny->new(
            agent => $ENV{GRAPHQL_CLIENT_HTTP_USER_AGENT} // "perl-graphql-client/$VERSION",
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

    my $request = {
        query           => 'query Greet($name: String) { hello(name: $name) }',
        operationName   => 'Greet',
        variables       => { name => 'Bob' },
    };
    my $options = {
        headers => {
            authorization => 'Bearer s3cr3t',
        },
    };
    my $response = $client->execute($request, $options);

=head1 DESCRIPTION

You probably shouldn't use this directly. Instead use L<GraphQL::Client>.

C<GraphQL::Client::http> is a GraphQL transport for HTTP. GraphQL is not required to be transported
via HTTP, but this is definitely the most common way.

This also serves as a reference implementation for C<GraphQL::Client> transports.

=method new

    $transport = GraphQL::Client::http->new(%attributes);

Construct a new GraphQL HTTP transport.

See L</ATTRIBUTES>.

=method execute

    $response = $client->execute(\%request);
    $response = $client->execute(\%request, \%options);

Get a response from the GraphQL server.

The C<%data> structure must have a C<query> key whose value is the query or mutation string. It may
optionally have a C<variables> hashref and an C<operationName> string.

The C<%options> structure is optional and may contain options passed through to the user agent. The
only useful options are C<headers> (which should have a hashref value) and C<method> and C<url> to
override the attributes of the same names.

The response will either be a hashref with the following structure or a L<Future> that resolves to
such a hashref:

    {
        response    => {    # decoded response (may be undef if an error occurred)
            data   => {...},
            errors => [...],
        },
        error       => 'Something happened',    # may be ommitted if no error occurred
        details     => {    # optional information which may aide troubleshooting
        },
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

=attr url

The http URL of a GraphQL endpoint, e.g. C<"http://myapiserver/graphql">.

=attr method

The HTTP method to use when querying the GraphQL server. Can be one of:

=for :list
* C<GET>
* C<POST> (default)

GraphQL servers should be able to handle both, but you can set this explicitly to one or the other
if you're dealing with a server that is opinionated. You can also provide a different HTTP method,
but anything other than C<GET> and C<POST> are less likely to work.

=attr json

The L<JSON::XS> (or compatible) object used for encoding and decoding data structures to and from
the GraphQL server.

Defaults to a L<JSON::MaybeXS>.

=head1 SEE ALSO

L<https://graphql.org/learn/serving-over-http/>

