package GraphQL::Client;
# ABSTRACT: A GraphQL client

use warnings;
use strict;

use Module::Load qw(load);
use Scalar::Util qw(reftype);
use Throw;

our $VERSION = '999.999'; # VERSION

sub _croak { use Carp; goto &Carp::croak }

sub new {
    my $class = shift;
    bless {@_}, $class;
}

sub request {
    my $self = shift;
    my ($query, $variables, $operation_name, $options) = @_;

    if ((reftype($operation_name) || '') eq 'HASH') {
        $options = $operation_name;
        $operation_name = undef;
    }

    my $request = {
        query => $query,
        ($variables && %$variables) ? (variables => $variables) : (),
        $operation_name ? (operationName => $operation_name) : (),
    };

    my $resp = $self->transport->request($request, $options);
    return $self->_handle_response($resp);
}

my $ERROR_MESSAGE = 'The GraphQL server returned errors';
sub _handle_response {
    my $self = shift;
    my ($resp) = @_;

    if (eval { $resp->isa('Future') }) {
        return $resp->followed_by(sub {
            my $f = shift;
            if (my ($exception, $category, @details) = $f->failure) {
                if (!$exception->{errors}) {
                    return Future->fail($exception, $category, @details);
                }
                if ($self->unpack) {
                    return Future->fail($ERROR_MESSAGE, 'graphql', $exception, @details);
                }
                return Future->done($exception);
            }
            else {
                my ($resp, @other) = $f->get;
                if ($self->unpack) {
                    if ($resp->{errors}) {
                        return Future->fail($ERROR_MESSAGE, 'graphql', $resp, @other);
                    }
                    return Future->done($resp->{data});
                }
                return Future->done($resp);
            }
        });
    }
    else {
        if ($self->unpack) {
            if ($resp->{errors}) {
                throw $ERROR_MESSAGE, {
                    type        => 'graphql',
                    response    => $resp,
                };
            }
            return $resp->{data};
        }
        return $resp;
    }
}

sub url {
    my $self = shift;
    $self->{url};
}

sub class {
    my $self = shift;
    $self->{class};
}

sub transport {
    my $self = shift;
    $self->{transport} //= do {
        my $class = $self->_transport_class;
        eval { load $class };
        if ((my $err = $@) || !$class->can('request')) {
            $err ||= "Loaded $class, but it doesn't look like a proper transport.\n";
            warn $err if $ENV{GRAPHQL_CLIENT_DEBUG};
            _croak "Failed to load transport for \"${class}\"";
        }
        $class->new(%$self);
    };
}

sub unpack {
    my $self = shift;
    $self->{unpack} //= 0;
}

sub _url_protocol {
    my $self = shift;

    my $url = $self->url;
    my ($protocol) = $url =~ /^([^+:]+)/;

    return $protocol;
}

sub _transport_class {
    my $self = shift;

    return _expand_class($self->{class}) if $self->{class};

    my $protocol = $self->_url_protocol;
    _croak 'Failed to determine transport from URL' if !$protocol;

    my $class = lc($protocol);
    $class =~ s/[^a-z]/_/g;

    return _expand_class($class);
}

sub _expand_class {
    my $class = shift;
    $class = "GraphQL::Client::$class" unless $class =~ s/^\+//;
    $class;
}

1;
__END__

=head1 SYNOPSIS

    my $client = GraphQL::Client->new();

    my $data = $client->request(q[
        query GetHuman {
            human(id: $human_id) {
                name
                height
            }
        }
    ], {
        human_id => 1000,
    });

=head1 DESCRIPTION

=method new

    $client = GraphQL::Client->new(%attributes);

Construct a new client.

=method request

    $response = $client->request($query);
    $response = $client->request($query, \%variables);
    $response = $client->request($query, \%variables, $operation_name);
    $response = $client->request($query, \%variables, $operation_name, \%transport_options);
    $response = $client->request($query, \%variables, \%transport_options);

Get a response from the GraphQL server.

By default, the response will either be a hashref with the following structure or a L<Future> that
resolves to such a hashref, depending on the transport and how it is configured.

    {
        data   => {
            field1  => {...}, # or [...]
            ...
        },
        errors => [
            { message => 'some error message blah blah blah' },
            ...
        ],
    }

Note: Setting the L</unpack> attribute affects the response shape.

=attr url

The URL of a GraphQL endpoint, e.g. C<"http://myapiserver/graphql">.

This is required.

=attr class

The package name of a transport.

By default this is automatically determined from the protocol portion of the L</url>.

=attr transport

The transport object.

By default this is automatically constructed based on the L</class>.

=attr unpack

Whether or not to "unpack" the response, which enables a different style for error-handling.

Default is 0.

See L</ERROR HANDLING>.

=head1 ERROR HANDLING

There are two different styles for handling errors.

If L</unpack> is 0 (off), every response -- whether success or failure -- is enveloped like this:

    {
        data   => {...},
        errors => [...],
    }

where C<data> might be missing or undef if errors occurred (though not necessarily) and C<errors>
will be missing if the response completed without error.

It is up to you to check for errors in the response, so your code might look like this:

    my $response = $client->request(...);
    if (my $errors = $response->{errors}) {
        # handle errors
    }
    my $data = $response->{data};
    # do something with $data

If C<unpack> is 1 (on), then L</request> will return just the data if there were no errors,
otherwise it will throw an exception. So your code would look like this:

    my $data = eval { $client->request(...) };
    if (my $error = $@) {
        # handle errors
    }
    # do something with $data

Or if you want to handle errors in a different stack frame, your code is simply this:

    my $data = $client->request(...);
    # do something with $data

Both styles map to L<Future> responses intuitively. If C<unpack> is 0, the response always resolves
to the envelope structure. If C<unpack> is 1, successful responses will resolve to just the data and
errors will fail/reject.

