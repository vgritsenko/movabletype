#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    $ENV{MT_CONFIG} = 'mysql-test.cfg';
}

BEGIN {
    use Test::More;
    eval { require Test::MockModule }
        or plan skip_all => 'Test::MockModule is not installed';
}

use lib qw(lib extlib t/lib);

eval(
    $ENV{SKIP_REINITIALIZE_DATABASE}
    ? "use MT::Test qw(:app);"
    : "use MT::Test qw(:app :db :data);"
);

use MT::Util;
use MT::App::DataAPI;
my $app    = MT::App::DataAPI->new;
my $author = MT->model('author')->load(1);
$author->email('melody@example.com');
$author->save;

my $mock_author = Test::MockModule->new('MT::Author');
$mock_author->mock( 'is_superuser', sub {0} );
my $mock_app_api = Test::MockModule->new('MT::App::DataAPI');
$mock_app_api->mock( 'authenticate', $author );
my $mock_filemgr_local = Test::MockModule->new('MT::FileMgr::Local');
$mock_filemgr_local->mock( 'delete', sub {1} );

my $temp_data = undef;
my @suite     = (
    {   path   => '/v1/sites/1/assets/upload',
        method => 'POST',
        setup  => sub {
            my ($data) = @_;
            $data->{count} = $app->model('asset')->count;
        },
        upload => [
            'file',
            File::Spec->catfile( $ENV{MT_HOME}, "t", 'images', 'test.jpg' ),
        ],
        result => sub {
            $app->model('asset')->load( { class => '*' },
                { sort => [ { column => 'id', desc => 'DESC' }, ] } );
        },
    },
    {   path   => '/v1/sites/1/assets/upload',
        method => 'POST',
        code   => '409',
        upload => [
            'file',
            File::Spec->catfile( $ENV{MT_HOME}, "t", 'images', 'test.jpg' ),
        ],
        complete => sub {
            my ( $data, $body ) = @_;
            my $result = MT::Util::from_json($body);
            $temp_data = $result->{error}{data};
            }
    },
    {   path   => '/v1/sites/1/assets/upload',
        method => 'POST',
        params => sub {
            +{  overwrite => 1,
                %$temp_data,
            };
        },
        upload => [
            'file',
            File::Spec->catfile( $ENV{MT_HOME}, "t", 'images', 'test.jpg' ),
        ],
    },
    {   path      => '/v2/sites/0/assets',
        method    => 'GET',
        callbacks => [
            {   name  => 'data_api_pre_load_filtered_list.asset',
                count => 2,
            },
        ],
        complete => sub {
            my ( $data, $body ) = @_;
            my $result = MT::Util::from_json($body);
            is( $result->{totalResults},
                1, 'The number of asset (blog_id=0) is 1.' );
        },
    },
    {   path      => '/v2/sites/1/assets',
        method    => 'GET',
        callbacks => [
            {   name  => 'data_api_pre_load_filtered_list.asset',
                count => 2,
            },
        ],
        complete => sub {
            my ( $data, $body ) = @_;
            my $result = MT::Util::from_json($body);
            is( $result->{totalResults},
                3, 'The number of asset (blog_id=1) is 3.' );
        },
    },
    {   path      => '/v2/sites/2/assets',
        method    => 'GET',
        callbacks => [
            {   name  => 'data_api_pre_load_filtered_list.asset',
                count => 1,
            },
        ],
        complete => sub {
            my ( $data, $body ) = @_;
            my $result = MT::Util::from_json($body);
            is( $result->{totalResults},
                0, 'The number of asset (blog_id=2) is 0.' );
        },
    },
    {   path   => '/v2/sites/3/assets',
        method => 'GET',
        code   => 404,
    },
    {   path      => '/v2/sites/1/assets',
        method    => 'GET',
        params    => { search => 'template', },
        callbacks => [
            {   name  => 'data_api_pre_load_filtered_list.asset',
                count => 2,
            },
        ],
        complete => sub {
            my ( $data, $body ) = @_;
            my $result = MT::Util::from_json($body);
            is( $result->{totalResults},
                1,
                'The number of asset whose label contains "template" is 1.' );
            like( lc $result->{items}[0]{label},
                qr/template/, 'The label of asset has "template".' );
        },
    },
    {   path      => '/v2/sites/1/assets',
        method    => 'GET',
        params    => { class => 'image', },
        callbacks => [
            {   name  => 'data_api_pre_load_filtered_list.asset',
                count => 2,
            },
        ],
        complete => sub {
            my ( $data, $body ) = @_;
            my $result = MT::Util::from_json($body);
            is( $result->{totalResults},
                2, 'The number of image asset is 2.' );
        },
    },
    {   path      => '/v2/sites/1/assets/1',
        method    => 'GET',
        callbacks => [
            {   name =>
                    'MT::App::DataAPI::data_api_view_permission_filter.asset',
                count => 1,
            },
        ],
        result => sub {
            MT->model('asset')->load(1);
        },
    },
    {   path   => '/v2/sites/2/assets/1',
        method => 'GET',
        code   => 404,
    },
    {   path   => '/v2/sites/1/assets/5',
        method => 'GET',
        code   => 404,
    },
    {   path   => '/v2/sites/3/assets/1',
        method => 'GET',
        code   => 404,
    },
    {   path   => '/v2/sites/3/assets/5',
        method => 'GET',
        code   => 404,
    },
    {   path   => '/v2/sites/0/assets/3',
        method => 'GET',
        result => sub {
            MT->model('asset')->load(3);
        },
    },
    {   path   => '/v2/sites/1/assets/3',
        method => 'GET',
        code   => 404,
    },
    {   path   => '/v2/sites/0/assets/1',
        method => 'GET',
        code   => 404,
    },
    {   path     => '/v2/sites/1/assets/1',
        method   => 'PUT',
        code     => 400,
        complete => sub {
            my ( $data, $body ) = @_;
            my $result        = MT::Util::from_json($body);
            my $error_message = "A resource \"asset\" is required.";
            is( $result->{error}{message},
                $error_message, 'Error message: ' . $error_message );
        },
    },
    {   path      => '/v2/sites/1/assets/1',
        method    => 'PUT',
        params    => { asset => {} },
        callbacks => [
            {   name =>
                    'MT::App::DataAPI::data_api_save_permission_filter.asset',
                count => 1,
            },
            {   name  => 'MT::App::DataAPI::data_api_save_filter.asset',
                count => 1,
            },
            {   name  => 'MT::App::DataAPI::data_api_pre_save.asset',
                count => 1,
            },
            {   name  => 'MT::App::DataAPI::data_api_post_save.asset',
                count => 1,
            },
        ],
        result => sub {
            MT->model('asset')->load(1);
        },
    },
    {   path   => '/v2/sites/2/assets/1',
        method => 'PUT',
        params =>
            { asset => { label => 'update_asset in different scope', }, },
        code => 404,
    },
    {   path   => '/v2/sites/0/assets/1',
        method => 'PUT',
        params => {
            asset => { label => 'update_asset in different scope (system)', },
        },
        code => 404,
    },
    {   path   => '/v2/sites/10/assets/1',
        method => 'PUT',
        params =>
            { asset => { label => 'update_asset in non-existent blog', }, },
        code => 404,
    },
    {   path   => '/v2/sites/1/assets/10',
        method => 'PUT',
        params =>
            { asset => { label => 'update_asset in non-existent asset', }, },
        code => 404,
    },
    {   path   => '/v2/sites/1/assets/1',
        method => 'PUT',
        params => {
            asset => {
                label       => 'updated label',
                description => 'updated description',
                tags        => ['updated tag'],

                filename => 'updated filename',
                url      => 'updated url',
                mimeType => 'updated mimeType',
                id       => '10',
            },
        },
        callbacks => [
            {   name =>
                    'MT::App::DataAPI::data_api_save_permission_filter.asset',
                count => 1,
            },
            {   name  => 'MT::App::DataAPI::data_api_save_filter.asset',
                count => 1,
            },
            {   name  => 'MT::App::DataAPI::data_api_pre_save.asset',
                count => 1,
            },
            {   name  => 'MT::App::DataAPI::data_api_post_save.asset',
                count => 1,
            },
        ],
        complete => sub {
            my ( $data, $body ) = @_;
            my $result = MT::Util::from_json($body);

            is( $result->{label},
                'updated label',
                'Asset\'s label has been updated.'
            );
            is( $result->{description},
                'updated description',
                'Asset\'s description has been updated.'
            );
            is( scalar @{ $result->{tags} }, 1, 'Asset\'s tag count is 1.' );
            is( $result->{tags}[0],
                'updated tag', 'Asset\'s tags has been updated.' );

            isnt(
                $result->{filename},
                'updated filename',
                'Asset\'s filename has not been updated.'
            );
            isnt( $result->{url}, 'updated url',
                'Asset\'s url has not been updated.' );
            isnt(
                $result->{mimeType},
                'updated mimeType',
                'Asset\'s mimeType has not been updated.'
            );
            isnt( $result->{id}, 10, 'Asset\'s id has not been updated.' );
        },
    },
    {   path   => '/v2/sites/2/assets/1',
        method => 'DELETE',
        code   => 404,
    },
    {   path   => '/v2/sites/0/assets/1',
        method => 'DELETE',
        code   => 404,
    },
    {   path   => '/v2/sites/10/assets/1',
        method => 'DELETE',
        code   => 404,
    },
    {   path   => '/v2/sites/10/assets/10',
        method => 'DELETE',
        code   => 404,
    },
    {   path      => '/v2/sites/1/assets/1',
        method    => 'DELETE',
        callbacks => [
            {   name =>
                    'MT::App::DataAPI::data_api_delete_permission_filter.asset',
                count => 1,
            },
            {   name  => 'MT::App::DataAPI::data_api_post_delete.asset',
                count => 1,
            },
        ],
        complete => sub {
            my $deleted = MT->model('asset')->load(1);
            is( $deleted, undef, 'deleted' );
        },
    },
    {   path   => '/v2/sites/1/assets/3',
        method => 'DELETE',
        code   => 404,
    },
    {   path   => '/v2/sites/10/assets/3',
        method => 'DELETE',
        code   => 404,
    },
    {   path      => '/v2/sites/0/assets/3',
        method    => 'DELETE',
        callbacks => [
            {   name =>
                    'MT::App::DataAPI::data_api_delete_permission_filter.asset',
                count => 1,
            },
            {   name  => 'MT::App::DataAPI::data_api_post_delete.asset',
                count => 1,
            },
        ],
        complete => sub {
            my $deleted = MT->model('asset')->load(3);
            is( $deleted, undef, 'deleted' );
        },
    },
);

my %callbacks = ();
my $mock_mt   = Test::MockModule->new('MT');
$mock_mt->mock(
    'run_callbacks',
    sub {
        my ( $app, $meth, @param ) = @_;
        $callbacks{$meth} ||= [];
        push @{ $callbacks{$meth} }, \@param;
        $mock_mt->original('run_callbacks')->(@_);
    }
);

my $format = MT::DataAPI::Format->find_format('json');

for my $data (@suite) {
    $data->{setup}->($data) if $data->{setup};

    my $path = $data->{path};
    $path
        =~ s/:(?:(\w+)_id)|:(\w+)/ref $data->{$1} ? $data->{$1}->id : $data->{$2}/ge;

    my $params
        = ref $data->{params} eq 'CODE'
        ? $data->{params}->($data)
        : $data->{params};

    my $note = $path;
    if ( lc $data->{method} eq 'get' && $data->{params} ) {
        $note .= '?'
            . join( '&',
            map { $_ . '=' . $data->{params}{$_} }
                keys %{ $data->{params} } );
    }
    $note .= ' ' . $data->{method};
    $note .= ' ' . $data->{note} if $data->{note};
    note($note);

    %callbacks = ();
    _run_app(
        'MT::App::DataAPI',
        {   __path_info      => $path,
            __request_method => $data->{method},
            ( $data->{upload} ? ( __test_upload => $data->{upload} ) : () ),
            (   $params
                ? map {
                    $_ => ref $params->{$_}
                        ? MT::Util::to_json( $params->{$_} )
                        : $params->{$_};
                    }
                    keys %{$params}
                : ()
            ),
        }
    );
    my $out = delete $app->{__test_output};
    my ( $headers, $body ) = split /^\s*$/m, $out, 2;
    my %headers = map {
        my ( $k, $v ) = split /\s*:\s*/, $_, 2;
        $v =~ s/(\r\n|\r|\n)\z//;
        lc $k => $v
        }
        split /\n/, $headers;
    my $expected_status = $data->{code} || 200;
    is( $headers{status}, $expected_status, 'Status ' . $expected_status );
    if ( $data->{next_phase_url} ) {
        like(
            $headers{'x-mt-next-phase-url'},
            $data->{next_phase_url},
            'X-MT-Next-Phase-URL'
        );
    }

    foreach my $cb ( @{ $data->{callbacks} } ) {
        my $params_list = $callbacks{ $cb->{name} } || [];
        if ( my $params = $cb->{params} ) {
            for ( my $i = 0; $i < scalar(@$params); $i++ ) {
                is_deeply( $params_list->[$i], $cb->{params}[$i] );
            }
        }

        if ( my $c = $cb->{count} ) {
            is( @$params_list, $c,
                $cb->{name} . ' was called ' . $c . ' time(s)' );
        }
    }

    if ( my $expected_result = $data->{result} ) {
        $expected_result = $expected_result->( $data, $body )
            if ref $expected_result eq 'CODE';
        if ( UNIVERSAL::isa( $expected_result, 'MT::Object' ) ) {
            MT->instance->user($author);
            $expected_result = $format->{unserialize}->(
                $format->{serialize}->(
                    MT::DataAPI::Resource->from_object($expected_result)
                )
            );
        }

        my $result = $format->{unserialize}->($body);
        is_deeply( $result, $expected_result, 'result' );
    }

    if ( my $complete = $data->{complete} ) {
        $complete->( $data, $body );
    }
}

done_testing();
