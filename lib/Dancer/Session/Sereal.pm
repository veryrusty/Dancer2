# ABSTRACT: YAML-file-based session backend for Dancer

package Dancer::Session::Sereal;
use Moo;
use Dancer::Core::Types;
use Carp;
use Dancer::FileUtils qw(path set_file_mode);

use File::Flock::Tiny;
use Path::Class qw/ file dir /;

use Sereal::Encoder qw/ encode_sereal /;
use Sereal::Decoder qw/ decode_sereal /;

with 'Dancer::Core::Role::Session';

# needed for new session when they get created
# FIXME this won't be needed anymore when we split the design in two:
# a Session class for session objects
# a SessionFactory for handling session (the session_dir belongs here)
my $_last_session_dir_used;

my %_session_dir_initialized;
has session_dir => (
    is => 'ro',
    isa => Str,
    default => sub { $_last_session_dir_used },
    trigger => sub {
        my ($self, $session_dir) = @_;

        if (! exists $_session_dir_initialized{$session_dir}) {
            $_session_dir_initialized{$session_dir} = 1;
            if (!-d $session_dir) {
                mkdir $session_dir
                  or croak "session_dir $session_dir cannot be created";
            }
        }

        $_last_session_dir_used = $session_dir;
    },
);

sub create { goto &new }

sub reset {
    my ($class) = @_;
    %_session_dir_initialized = ();
}

sub retrieve {
    my ($self, $id) = @_;

    my $file = $self->session_file($id);

    return unless -f $file;

    my $lock = File::Flock::Tiny->lock($file);

    return decode_sereal( scalar $file->slurp );
}

# instance

sub session_file {
    my ($self, $id) = @_;
    return file($self->session_dir, $id);
}

=method destroy
=cut
sub destroy {
    my ($self) = @_;

    my $file = $self->session_file($self->id);
    
    $file->remove if -f $file;
}

sub flush {
    my $self         = shift;
    my $session_file = $self->session_file( $self->id );

    my $lock = File::Flock::Tiny->lock($session_file);

    $session_file->spew(encode_sereal($self));

    return $self;
}

1;
