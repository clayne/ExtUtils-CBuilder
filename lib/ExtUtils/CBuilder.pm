package ExtUtils::CBuilder;

use strict;
use File::Spec;
use File::Basename;
use IO::File;
use Config;

use vars qw($VERSION);
$VERSION = '0.00_01';

sub new {
  my $class = shift;
  my $self = bless {@_}, $class;

  while (my ($k,$v) = each %Config) {
    $self->{config}{$k} = $v unless exists $self->{config}{$k};
  }
  return $self;
}

sub object_file {
  my ($self, $filename) = @_;

  # File name, minus the suffix
  (my $file_base = $filename) =~ s/\.[^.]+$//;
  return "$file_base$self->{config}{obj_ext}";
}

sub compile_library {
  my ($self, %args) = @_;
  
  my $cf = $self->{config}; # For convenience

  $args{object_file} ||= $self->object_file($args{source});
  
  my @include_dirs = map {"-I$_"} (@{$args{include_dirs} || []},
				   File::Spec->catdir($cf->{installarchlib}, 'CORE'));
  
  my @extra_compiler_flags = $self->split_like_shell($args{extra_compiler_flags});
  my @cccdlflags = $self->split_like_shell($cf->{cccdlflags});
  my @ccflags = $self->split_like_shell($cf->{ccflags});
  my @optimize = $self->split_like_shell($cf->{optimize});
  my @flags = (@include_dirs, @cccdlflags, @extra_compiler_flags, '-c', @ccflags, @optimize);
  
  my @cc = $self->split_like_shell($cf->{cc});
  
  $self->do_system(@cc, @flags, '-o', $args{object_file}, $args{source})
    or die "error building $cf->{dlext} file from '$args{source}'";

  return $args{object_file};
}

sub compile_executable {
  die "Not implemented yet";
}

sub have_c_compiler {
  my ($self) = @_;
  return $self->{have_compiler} if defined $self->{have_compiler};
  
  my $tmpfile = File::Spec->catfile(File::Spec->tmpdir, 'compilet.c');
  {
    my $fh = IO::File->new("> $tmpfile") or die "Can't create $tmpfile: $!";
    print $fh "int boot_compilet() { return 1; }\n";
  }

  my ($obj_file, @lib_files);
  eval {
    $obj_file = $self->compile_library(source => $tmpfile);
    @lib_files = $self->link_objects(objects => $obj_file, module_name => 'compilet');
  };
  warn $@ if $@;
  my $result = $self->{have_compiler} = $@ ? 0 : 1;
  
  foreach (grep defined, $tmpfile, $obj_file, @lib_files) {
    1 while unlink;
  }
  return $result;
}

sub lib_file {
  my ($self, $dl_file) = @_;
  $dl_file =~ s/\.[^.]+$//;
  $dl_file =~ tr/"//d;
  return "$dl_file.$self->{config}{dlext}";
}

sub need_prelink_objects { 0 }

sub prelink_objects {
  my ($self, %args) = @_;
  
  ($args{dl_file} = $args{dl_name}) =~ s/.*::// unless $args{dl_file};
  
  require ExtUtils::Mksymlists;
  ExtUtils::Mksymlists::Mksymlists( # dl. abbrev for dynamic library
    DL_VARS  => $args{dl_vars}      || [],
    DL_FUNCS => $args{dl_funcs}     || {},
    FUNCLIST => $args{dl_func_list} || [],
    IMPORTS  => $args{dl_imports}   || {},
    NAME     => $args{dl_name},
    DLBASE   => $args{dl_base},
    FILE     => $args{dl_file},
  );
  
  return grep -e, map "$args{dl_file}.$_", qw(ext def opt);
}

sub link_objects {
  my ($self, %args) = @_;
  my $cf = $self->{config}; # For convenience
  
  my $objects = delete($args{objects}) || [];
  $objects = [$objects] unless ref $objects;
  $args{lib_file} ||= $self->lib_file($objects->[0]);
  
  my @temp_files = 
    $self->prelink_objects(%args,
			   dl_name => $args{module_name}) if $self->need_prelink_objects;
  
  my @linker_flags = $self->split_like_shell($args{extra_linker_flags});
  my @lddlflags = $self->split_like_shell($cf->{lddlflags});
  my @shrp = $self->split_like_shell($cf->{shrpenv});
  my @ld = $self->split_like_shell($cf->{ld});
  $self->do_system(@shrp, @ld, @lddlflags, '-o', $args{lib_file}, @$objects, @linker_flags)
    or die "error building $args{lib_file} from @$objects";
  
  return wantarray ? ($args{lib_file}, @temp_files) : $args{lib_file};
}

sub do_system {
  my ($self, @cmd) = @_;
  print "@cmd\n";
  return !system(@cmd);
}

sub split_like_shell {
  my ($self, $string) = @_;
  
  return () unless defined($string) && length($string);
  return @$string if UNIVERSAL::isa($string, 'ARRAY');
  
  return $self->shell_split($string);
}

sub shell_split {
  return split ' ', $_[1];  # XXX This is naive - needs a fix
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

ExtUtils::CBuilder - Perl extension for blah blah blah

=head1 SYNOPSIS

  use ExtUtils::CBuilder;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for ExtUtils::CBuilder, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
