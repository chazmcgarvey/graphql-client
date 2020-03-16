package MockUA;
# ABSTRACT: HTTP::AnyUA backend for testing GraphQL::Client::http

use warnings;
use strict;

use Scalar::Util qw(blessed);
use namespace::clean;

use parent 'HTTP::AnyUA::Backend';

=method response

    $response = $backend->response;
    $response = $backend->response($response);

Get and set the response hashref or L<Future> that this backend will always respond with.

=cut

sub response { @_ == 2 ? $_[0]->{response} = pop : $_[0]->{response} }

=method requests

    @requests = $backend->requests;

Get the requests the backend has handled so far.

=cut

sub requests { @{$_[0]->{requests} || []} }

sub response_is_future { blessed($_[0]->{response}) && $_[0]->{response}->isa('Future') }

sub request {
    my $self = shift;

    push @{$self->{requests} ||= []}, [@_];

    return $self->response || {
        success => '',
        status  => 599,
        reason  => 'Internal Exception',
        content => "No response mocked.\n",
    };
}

1;
