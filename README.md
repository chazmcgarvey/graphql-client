# NAME

GraphQL::Client - A GraphQL client

# VERSION

version 0.601

# SYNOPSIS

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

# DESCRIPTION

`GraphQL::Client` provides a simple way to execute [GraphQL](https://graphql.org/) queries and
mutations on a server.

This module is the programmatic interface. There is also a ["CLI program"](https://metacpan.org/pod/graphql).

GraphQL servers are usually served over HTTP. The provided transport, [GraphQL::Client::http](https://metacpan.org/pod/GraphQL%3A%3AClient%3A%3Ahttp), lets
you plug in your own user agent, so this client works naturally with [HTTP::Tiny](https://metacpan.org/pod/HTTP%3A%3ATiny),
[Mojo::UserAgent](https://metacpan.org/pod/Mojo%3A%3AUserAgent), and more. You can also use [HTTP::AnyUA](https://metacpan.org/pod/HTTP%3A%3AAnyUA) middleware.

# ATTRIBUTES

## url

The URL of a GraphQL endpoint, e.g. `"http://myapiserver/graphql"`.

## unpack

Whether or not to "unpack" the response, which enables a different style for error-handling.

Default is 0.

See ["ERROR HANDLING"](#error-handling).

## transport\_class

The package name of a transport.

This is optional if the correct transport can be correctly determined from the ["url"](#url).

## transport

The transport object.

By default this is automatically constructed based on ["transport\_class"](#transport_class) or ["url"](#url).

# METHODS

## new

    $graphql = GraphQL::Client->new(%attributes);

Construct a new client.

## execute

    $response = $graphql->execute($query);
    $response = $graphql->execute($query, \%variables);
    $response = $graphql->execute($query, \%variables, $operation_name);
    $response = $graphql->execute($query, \%variables, $operation_name, \%transport_options);
    $response = $graphql->execute($query, \%variables, \%transport_options);

Execute a request on a GraphQL server, and get a response.

By default, the response will either be a hashref with the following structure or a [Future](https://metacpan.org/pod/Future) that
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

Note: Setting the ["unpack"](#unpack) attribute affects the response shape.

# ERROR HANDLING

There are two different styles for handling errors.

If ["unpack"](#unpack) is 0 (off, the default), every response -- whether success or failure -- is enveloped
like this:

    {
        data   => {...},
        errors => [...],
    }

where `data` might be missing or undef if errors occurred (though not necessarily) and `errors`
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

If `unpack` is 1 (on), then ["execute"](#execute) will return just the data if there were no errors,
otherwise it will throw an exception. So your code would instead look like this:

    my $data = eval { $graphql->execute(...) };
    if (my $error = $@) {
        my $resp = $error->{response};
        # handle errors
    }
    else {
        # do something with $data
    }

Or if you want to handle errors in a different stack frame, your code is simply this:

    my $data = $graphql->execute(...);
    # do something with $data

Both styles map to [Future](https://metacpan.org/pod/Future) responses intuitively. If `unpack` is 0, the response always resolves
to the envelope structure. If `unpack` is 1, successful responses will resolve to just the data and
errors will fail/reject.

# SEE ALSO

- [graphql](https://metacpan.org/pod/graphql) - CLI program
- [GraphQL](https://metacpan.org/pod/GraphQL) - Perl implementation of a GraphQL server
- [https://graphql.org/](https://graphql.org/) - GraphQL project website

# BUGS

Please report any bugs or feature requests on the bugtracker website
[https://github.com/chazmcgarvey/graphql-client/issues](https://github.com/chazmcgarvey/graphql-client/issues)

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

# AUTHOR

Charles McGarvey <chazmcgarvey@brokenzipper.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by Charles McGarvey.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.