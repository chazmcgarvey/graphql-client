# NAME

graphql - Command-line GraphQL client

# VERSION

version 0.602

# SYNOPSIS

    graphql <URL> <QUERY> [ [--variables JSON] | [--variable KEY=VALUE]... ]
            [--operation-name NAME] [--transport KEY=VALUE]...
            [--[no-]unpack] [--format json|json:pretty|yaml|perl|csv|tsv|table]
            [--output FILE]

    graphql --version|--help|--manual

# DESCRIPTION

`graphql` is a command-line program for executing queries and mutations on
a [GraphQL](https://graphql.org/) server.

# INSTALL

There are several ways to install `graphql` to your system.

## from CPAN

You can install `graphql` using [cpanm](https://metacpan.org/pod/cpanm):

    cpanm GraphQL::Client

## from GitHub

You can also choose to download `graphql` as a self-contained executable:

    curl -OL https://raw.githubusercontent.com/chazmcgarvey/graphql-client/solo/graphql
    chmod +x graphql

To hack on the code, clone the repo instead:

    git clone https://github.com/chazmcgarvey/graphql-client.git
    cd graphql-client
    make bootstrap      # installs dependencies; requires cpanm

# OPTIONS

## `--url URL`

The URL of the GraphQL server endpoint.

If no `--url` option is given, the first argument is assumed to be the URL.

This option is required.

Alias: `-u`

## `--query STR`

The query or mutation to execute.

If no `--query` option is given, the next argument (after URL) is assumed to be the query.

If the value is "-" (which is the default), the query will be read from `STDIN`.

See: [https://graphql.org/learn/queries/](https://graphql.org/learn/queries/)

Alias: `--mutation`

## `--variables JSON`

Provide the variables as a JSON object.

Aliases: `--vars`, `-V`

## `--variable KEY=VALUE`

An alternative way to provide variables one at a time. This option can be repeated to provide
multiple variables.

If used in combination with ["--variables JSON"](#variables-json), this option is silently ignored.

See: [https://graphql.org/learn/queries/#variables](https://graphql.org/learn/queries/#variables)

Aliases: `--var`, `-d`

## `--operation-name NAME`

Inform the server which query/mutation to execute.

Alias: `-n`

## `--output FILE`

Write the response to a file instead of STDOUT.

Alias: `-o`

## `--transport KEY=VALUE`

Key-value pairs for configuring the transport (usually HTTP).

Alias: `-t`

## `--format STR`

Specify the output format to use. See ["FORMAT"](#format).

Alias: `-f`

## `--unpack`

Enables unpack mode.

By default, the response structure is printed as-is from the server, and the program exits 0.

When unpack mode is enabled, if the response completes with no errors, only the data section of
the response is printed and the program exits 0. If the response has errors, the whole response
structure is printed as-is and the program exits 1.

See ["EXAMPLES"](#examples).

# FORMAT

The argument for ["--format STR"](#format-str) can be one of:

- `csv` - Comma-separated values (requires [Text::CSV](https://metacpan.org/pod/Text%3A%3ACSV))
- `json:pretty` - Human-readable JSON (default)
- `json` - JSON
- `perl` - Perl code (requires [Data::Dumper](https://metacpan.org/pod/Data%3A%3ADumper))
- `table` - Table (requires [Text::Table::Any](https://metacpan.org/pod/Text%3A%3ATable%3A%3AAny))
- `tsv` - Tab-separated values (requires [Text::CSV](https://metacpan.org/pod/Text%3A%3ACSV))
- `yaml` - YAML (requires [YAML](https://metacpan.org/pod/YAML))

The `csv`, `tsv`, and `table` formats will only work if the response has a particular shape:

    {
        "data" : {
            "onefield" : [
                {
                    "key" : "value",
                    ...
                },
                ...
            ]
        }
    }

or

    {
        "data" : {
            "onefield" : [
                "value",
                ...
            ]
        }
    }

If the response cannot be formatted, the default format will be used instead, an error message will
be printed to STDERR, and the program will exit 3.

Table formatting can be done by one of several different modules, each with its own features and
bugs. The default module is [Text::Table::Tiny](https://metacpan.org/pod/Text%3A%3ATable%3A%3ATiny), but this can be overridden using the
`PERL_TEXT_TABLE` environment variable if desired, like this:

    PERL_TEXT_TABLE=Text::Table::HTML graphql ... -f table

The list of supported modules is at ["@BACKENDS" in Text::Table::Any](https://metacpan.org/pod/Text%3A%3ATable%3A%3AAny#BACKENDS).

# EXAMPLES

Different ways to provide the query/mutation to execute:

    graphql http://myserver/graphql {hello}

    echo {hello} | graphql http://myserver/graphql

    graphql http://myserver/graphql <<END
    > {hello}
    > END

    graphql http://myserver/graphql
    Interactive mode engaged! Waiting for a query on <STDIN>...
    {hello}
    ^D

Execute a query with variables:

    graphql http://myserver/graphql <<END --var episode=JEDI
    > query HeroNameAndFriends($episode: Episode) {
    >   hero(episode: $episode) {
    >     name
    >     friends {
    >       name
    >     }
    >   }
    > }
    > END

    graphql http://myserver/graphql --vars '{"episode":"JEDI"}'

Configure the transport:

    graphql http://myserver/graphql {hello} -t headers.authorization='Basic s3cr3t'

This example shows the effect of ["--unpack"](#unpack):

    graphql http://myserver/graphql {hello}

    # Output:
    {
        "data" : {
            "hello" : "Hello world!"
        }
    }

    graphql http://myserver/graphql {hello} --unpack

    # Output:
    {
        "hello" : "Hello world!"
    }

# ENVIRONMENT

Some environment variables affect the way `graphql` behaves:

- `GRAPHQL_CLIENT_DEBUG` - Set to 1 to print diagnostic messages to STDERR.
- `GRAPHQL_CLIENT_HTTP_USER_AGENT` - Set the HTTP user agent string.
- `GRAPHQL_CLIENT_OPTIONS` - Set the default set of options.
- `PERL_TEXT_TABLE` - Set table format backend; see ["FORMAT"](#format).

# EXIT STATUS

Here is a consolidated summary of what exit statuses mean:

- `0` - Success
- `1` - Client or server errors
- `2` - Option usage is wrong
- `3` - Could not format the response as requested

# SEE ALSO

- [GraphQL::Client](https://metacpan.org/pod/GraphQL%3A%3AClient) - Programmatic interface

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
