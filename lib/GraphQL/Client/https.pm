package GraphQL::Client::https;
# ABSTRACT: GraphQL over HTTPS

use warnings;
use strict;

use parent 'GraphQL::Client::http';

our $VERSION = '999.999'; # VERSION

sub new {
    my $class = shift;
    GraphQL::Client::http->new(@_);
}

1;
__END__

=head1 SEE ALSO

L<GraphQL::Client::http>
