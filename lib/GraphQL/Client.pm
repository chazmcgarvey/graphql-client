package GraphQL::Client;
# ABSTRACT: A GraphQL client

use warnings;
use strict;

use Module::Load qw(load);
use Scalar::Util qw(reftype);
use namespace::clean;

our $VERSION = '999.999'; # VERSION

sub _croak { require Carp; goto &Carp::croak }
sub _throw { GraphQL::Client::Error->throw(@_) }

sub new {
    my $class = shift;
    bless {@_}, $class;
}

sub execute {
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

    return $self->_handle_result($self->transport->execute($request, $options));
}

sub _handle_result {
    my $self = shift;
    my ($result) = @_;

    my $handle_result = sub {
        my $result = shift;
        my $resp = $result->{response};
        if (my $exception = $result->{error}) {
            unshift @{$resp->{errors}}, {
                message => "$exception",
            };
        }
        if ($self->unpack) {
            if ($resp->{errors}) {
                _throw $resp->{errors}[0]{message}, {
                    type        => 'graphql',
                    response    => $resp,
                    details     => $result->{details},
                };
            }
            return $resp->{data};
        }
        return $resp;
    };

    if (eval { $result->isa('Future') }) {
        return $result->transform(
            done => sub {
                my $result = shift;
                my $resp = eval { $handle_result->($result) };
                if (my $err = $@) {
                    Future::Exception->throw("$err", $err->{type}, $err->{response}, $err->{details});
                }
                return $resp;
            },
        );
    }
    else {
        return $handle_result->($result);
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
        if ((my $err = $@) || !$class->can('execute')) {
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

{
    package GraphQL::Client::Error;

    use warnings;
    use strict;

    use overload '""' => \&error, fallback => 1;

    sub new { bless {%{$_[2] || {}}, error => $_[1] || 'Something happened'}, $_[0] }

    sub error { "$_[0]->{error}" }
    sub type  { "$_[0]->{type}"  }

    sub throw {
        my $self = shift;
        die $self if ref $self;
        die $self->new(@_);
    }
}

1;
__END__

=head1 SYNOPSIS

    my $graphql = GraphQL::Client->new(url => 'http://localhost:4000/graphql');

    # Example: Hello world!

    my $response = $graphql->execute('{hello}');

    # Example: Kitchen sink

    my $query = q[
        query GetHuman {
            human(id: $human_id) {
                name
                height
            }
        }
    ];
    my $variables = {
        human_id => 1000,
    };
    my $operation_name = 'GetHuman';
    my $transport_options = {
        headers => {
            authorization => 'Bearer s3cr3t',
        },
    };
    my $response = $graphql->execute($query, $variables, $operation_name, $transport_options);

    # Example: Asynchronous with Mojo::UserAgent (promisify requires Future::Mojo)

    my $ua = Mojo::UserAgent->new;
    my $graphql = GraphQL::Client->new(ua => $ua, url => 'http://localhost:4000/graphql');

    my $future = $graphql->execute('{hello}');

    $future->promisify->then(sub {
        my $response = shift;
        ...
    });

=head1 DESCRIPTION

C<GraphQL::Client> provides a simple way to execute L<GraphQL|https://graphql.org/> queries and
mutations on a server.

This module is the programmatic interface. There is also a L<"CLI program"|graphql>.

GraphQL servers are usually served over HTTP. The provided transport, L<GraphQL::Client::http>, lets
you plug in your own user agent, so this client works naturally with L<HTTP::Tiny>,
L<Mojo::UserAgent>, and more. You can also use L<HTTP::AnyUA> middleware.

=method new

    $graphql = GraphQL::Client->new(%attributes);

Construct a new client.

=method execute

    $response = $graphql->execute($query);
    $response = $graphql->execute($query, \%variables);
    $response = $graphql->execute($query, \%variables, $operation_name);
    $response = $graphql->execute($query, \%variables, $operation_name, \%transport_options);
    $response = $graphql->execute($query, \%variables, \%transport_options);

Execute a request on a GraphQL server, and get a response.

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

    my $response = $graphql->execute(...);
    if (my $errors = $response->{errors}) {
        # handle $errors
    }
    else {
        my $data = $response->{data};
        # do something with $data
    }

If C<unpack> is 1 (on), then L</execute> will return just the data if there were no errors,
otherwise it will throw an exception. So your code would instead look like this:

    my $data = eval { $graphql->execute(...) };
    if (my $error = $@) {
        # handle errors
    }
    else {
        # do something with $data
    }

Or if you want to handle errors in a different stack frame, your code is simply this:

    my $data = $graphql->execute(...);
    # do something with $data

Both styles map to L<Future> responses intuitively. If C<unpack> is 0, the response always resolves
to the envelope structure. If C<unpack> is 1, successful responses will resolve to just the data and
errors will fail/reject.

=head1 SEE ALSO

=for :list
* L<graphql> - CLI program
* L<GraphQL> - Perl implementation of a GraphQL server
* L<https://graphql.org/> - GraphQL project website

