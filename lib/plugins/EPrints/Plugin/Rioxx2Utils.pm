package EPrints::Plugin::Rioxx2Utils;

@ISA = ( 'EPrints::Plugin' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	return $class->SUPER::new(%params);
}

sub get_related_objects
{
	my( $plugin, $dataobj ) = @_;

	my @documents = $dataobj->get_all_documents;

	return {
		eprint => $dataobj,
		document => $documents[0], # TODO delegate to config
	};
}

sub value
{
	my( $plugin, $dataobj, $field ) = @_;

	my $repo = $plugin->{repository};

	my $source = $repo->config( "rioxx2", "field_lookup", $field, "source" );
	return unless defined $source;

	my $objects = $plugin->get_related_objects( $dataobj );

	if( ref( $source ) eq 'CODE' )
	{
		my $value = eval {
			&$source( $plugin, $objects );
		};
		if( $@ )
		{
			$repo->log( "value() runtime error: $@" );
			return;
		}
		return $value;
	}

	my( $ds, $f ) = split( ".", $source );
	unless( defined $objects->{$ds} )
	{
		$repo->log( "value() invalid dataset $ds\n" );
		return;
	}
	unless( $objects->{$ds}->get_dataset->has_field( $f ) )
	{
		$repo->log( "value() $ds has no field $f\n" );
		return;
	}
	return $objects->{$ds}->value( $f );
}

sub validate
{
	my( $plugin, $dataobj, $field ) = @_;

	my $repo = $plugin->{repository};

	my $validate = $repo->config( "rioxx2". "field_lookup", $field, "source" );
	return unless defined $validate;

	my $objects = $plugin->get_related_objects( $dataobj );

	my @problems;

	if( ref( $validate ) eq 'CODE' )
	{
		eval {
			&$validate( $plugin, $objects, \@problems );
		};
		if( $@ )
		{
			$repo->log( "validate() runtime error: $@" );
			return;
		}
		return @problems;
	}

	my $value = $plugin->value( $dataobj, $field );
	if( !EPrints::Utils::is_set( $value ) )
	{
		push @problems, "Missing required field $field";
	}

	return @problems;
}
