package Mojolicious::Command::serve_contenteditable;
use Mojo::Base 'Mojolicious::Command';

# Short description
has file => 'The file to edit';

# Usage message from SYNOPSIS
has usage => sub { shift->extract_usage };

sub run {
    my ($self, @args) = @_;

    # Magic here! :)
}

1;

=head1 SYNOPSIS

    Usage: APPLICATION serve_contenteditable /path/to/htmlfile

    Options:
      -s, --something   Does something

=cut
