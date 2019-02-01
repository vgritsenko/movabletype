#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";    # t/lib
use Test::More;
use MT::Test::Env;
our $test_env;

BEGIN {
    $test_env = MT::Test::Env->new(
        DeleteFilesAtRebuild => 1,
        RebuildAtDelete      => 1,
    );
    $ENV{MT_CONFIG} = $test_env->config_file;
}

use MT;
use MT::Test;
use MT::Test::Permission;
my $app = MT->instance;

my $blog_id = 1;

$test_env->prepare_fixture('db');

my $author = MT::Test::Permission->make_author(
    name     => 'author',
    nickname => 'author',
);

my $page1 = MT::Test::Permission->make_page(
    blog_id     => $blog_id,
    author_id   => $author->id,
    authored_on => '20180831000000',
    title       => 'page1',
);

my $folder1 = MT::Test::Permission->make_folder(
    blog_id => $blog_id,
    label   => 'folder1',
);

my $folder2 = MT::Test::Permission->make_folder(
    blog_id => $blog_id,
    label   => 'folder2',
);

my $placement1 = MT::Test::Permission->make_placement(
    blog_id     => $blog_id,
    entry_id    => $page1->id,
    category_id => $folder1->id,
    is_primary  => 1,
);

# Mapping
my $template = MT::Test::Permission->make_template(
    blog_id => $blog_id,
    name    => 'Folder Test',
    type    => 'page',
    text    => 'test',
);
my $template_map = MT::Test::Permission->make_templatemap(
    template_id   => $template->id,
    blog_id       => $blog_id,
    archive_type  => 'Page',
    file_template => '%c/%f',
    is_preferred  => 1,
);

my $blog = MT::Blog->load($blog_id);
$blog->site_path( join "/", $test_env->root, "site/archive" );
$blog->save;

require MT::WeblogPublisher;
my $publisher = MT::WeblogPublisher->new;
$publisher->rebuild(
    BlogID      => $blog_id,
    ArchiveType => 'Page',
    TemplateMap => $template_map,
);

my $filename1 = $page1->title;
my $archive   = File::Spec->catfile( $test_env->root,
    "site/archive/folder1/$filename1.html" );
ok -e $archive;

my @finfos = MT::FileInfo->load( { blog_id => $blog_id } );
is @finfos => 1, "only one FileInfo";

require File::Find;
File::Find::find(
    {   wanted => sub {
            note $File::Find::name;
        },
        no_chdir => 1,
    },
    $test_env->root
);

$placement1->category_id( $folder2->id );
$placement1->save or die $placement1->error;

$app->request->reset;
$publisher->rebuild(
    BlogID      => $blog_id,
    ArchiveType => 'Page',
    TemplateMap => $template_map,
);

ok !-e $archive;

my $updated_archive = File::Spec->catfile( $test_env->root,
    "site/archive/folder2/$filename1.html" );
ok -e $updated_archive;

my @updated_finfos = MT::FileInfo->load( { blog_id => $blog_id } );
is @updated_finfos => 1, "only one FileInfo";

require File::Find;
File::Find::find(
    {   wanted => sub {
            note $File::Find::name;
        },
        no_chdir => 1,
    },
    $test_env->root
);

my $page2 = MT::Test::Permission->make_page(
    blog_id     => $blog_id,
    author_id   => $author->id,
    authored_on => '20181031000000',
    title       => 'page2',
);

my $placement2 = MT::Test::Permission->make_placement(
    blog_id     => $blog_id,
    entry_id    => $page2->id,
    category_id => $folder2->id,
    is_primary  => 1,
);

$app->request->reset;
$publisher->rebuild(
    BlogID      => $blog_id,
    ArchiveType => 'Page',
    TemplateMap => $template_map,
);

ok !-e $archive;
ok -e $updated_archive;

my $filename2   = $page2->title;
my $new_archive = File::Spec->catfile( $test_env->root,
    "site/archive/folder2/$filename2.html" );
ok -e $new_archive;

my @new_finfos = MT::FileInfo->load( { blog_id => $blog_id } );
is @new_finfos => 2, "two FileInfo";

File::Find::find(
    {   wanted => sub {
            note $File::Find::name;
        },
        no_chdir => 1,
    },
    $test_env->root
);

done_testing;
