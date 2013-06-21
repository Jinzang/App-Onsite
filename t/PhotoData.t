#!/usr/local/bin/perl
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 12;

use Cwd qw(abs_path getcwd);
use App::Onsite::Support::WebFile;
use App::Onsite::Support::RegistryFile;

#----------------------------------------------------------------------
# Initialize test directory

my @path = split('/', abs_path($0));
pop(@path);
my $bin = join('/', @path);

$ENV{PATH} = '/bin';
my $data_dir = 'test';
system("/bin/rm -rf $data_dir");

mkdir $data_dir;
$data_dir = abs_path($data_dir);
my $template_dir = "$data_dir/templates";
my $data_registry = 'data.reg';

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("App::Onsite::PhotoData");} # test 1

my $params = {
              base_dir => $data_dir,
              data_dir => $data_dir,
              template_dir => "$template_dir",
              script_url => 'test.cgi',
              base_url => 'http://www.onsite.org',
              valid_write => [$data_dir, $template_dir],
              data_registry => $data_registry,
              photo_width => 600,
              photo_height => 600,
              thumb_width => 125,
              thumb_height => 125,
             };


#----------------------------------------------------------------------
# Create test files

my $wf = App::Onsite::Support::WebFile->new(%$params);

my $registry = <<'EOQ';
        [file]
SEPARATOR = :
INDEX_NAME = index
ID_FIELD = title
SORT_FIELD = id
SUMMARY_FIELD = body
ID_LENGTH = 63
INDEX_LENGTH = 4
HAS_SUBFOLDERS = 0
DEFAULT_COMMAND = edit
PARENT_COMMANDS = browse
PARENT_COMMANDS = search
COMMANDS = browse
COMMANDS = add
COMMANDS = edit
COMMANDS = remove
COMMANDS = search
		[page]
EXTENSION = html
CLASS = App::Onsite::PageData
SUPER = dir
SORT_FIELD = id
SUBTEMPLATE = page.htm
RSSTEMPLATE = rss.xml
COMMANDS = browse
COMMANDS = add
COMMANDS = edit
COMMANDS = remove
COMMANDS = search
COMMANDS = view
        [dir]
CLASS = App::Onsite::DirData
SUPER = dir
HAS_SUBFOLDERS = 1
SUBTEMPLATE = dir.htm
		[gallery]
EXTENSION = html
CLASS = App::Onsite::GalleryData
SUPER = dir
SORT_FIELD = id
SUBTEMPLATE = gallery.htm
        [list]
CLASS = App::Onsite::ListData
SUBTEMPLATE = add_subpage.htm
COMMANDS = edit
COMMANDS = remove
COMMANDS = view
        [photo]
CLASS = App::Onsite::PhotoData
SUBTEMPLATE = photo.htm
SUPER = gallery
PLURAL = photos
INDEX_LENGTH = 4
COMMANDS = edit
COMMANDS = remove
COMMANDS = view
EOQ

$wf->writer("$template_dir/$data_registry", $registry);

my $pagefile = <<'EOQ';
<html>
<head>
<!-- begin meta -->
<title><!-- begin title -->A title
<!-- end title --></title>
<!-- end meta -->
</head>
<body>
<div id = "container">
<div  id="content">
<!-- begin primary type="gallery" -->
<h1><!-- begin title -->
Photo Gallery
<!-- end title --></h1>
<p><!-- begin body -->
Some pictures.
<!-- end body --></p>
<!-- end primary -->
<!-- begin secondary type="photo" sort="id" -->
<ul id="photo-gallery">
<!-- begin data -->
<!-- end data -->
</ul>
<!-- end secondary -->
</div>
<div id="sidebar">
<ul>
<!-- begin parentlinks -->
<!-- end parentlinks -->
<!-- begin pagelinks -->
<!-- end pagelinks -->
<!-- begin commandlinks -->
<ul>
<!-- begin data -->
<li><a href="{{url}}"><!-- begin title -->
<!--end title --></a><!-- set url [[]] --></li>
<!-- end data -->
</ul>
<!-- end commandlinks -->
</div>
</div>
</body>
</html>
EOQ

my $photo_template = <<'EOQ';
<html>
<head>
</head>
<body>
<!-- begin secondary type="photo" sort="id" -->
<ul id="photo-gallery'>
<!-- begin data -->
<!-- set id [[0001]] -->
<li>
<a href="{{photo}}"><img src="{{thumb}}"></a>
<!-- begin title -->
A title
<!-- end title --></li>
<!-- end data -->
</ul>
<!-- end secondary -->
</body>
</html>
EOQ

# Write page as templates and pages

my $indexname = "$data_dir/gallery/index.html";
$indexname = $wf->validate_filename($indexname, 'w');
$wf->writer($indexname, $pagefile);

my $templatename = "$template_dir/photo.htm";
$templatename = $wf->validate_filename($templatename, 'w');
$wf->writer($templatename, $photo_template);

my $gallery_dir = "$params->{base_dir}/gallery";
my $gallery_url = "$params->{base_url}/gallery";

#----------------------------------------------------------------------
# Create object

my $reg = App::Onsite::Support::RegistryFile->new(%$params);
my $gallery = $reg->create_subobject($params, $data_registry, 'gallery');
my $photo = $reg->create_subobject($params, $data_registry, 'photo');

isa_ok($photo, "App::Onsite::PhotoData"); # test 2
can_ok($photo, qw(add_data browse_data edit_data read_data remove_data
                 search_data check_id)); # test 3

#----------------------------------------------------------------------
# Add Photo

my $d = {};
my $s = {};
$d->{id} = 'gallery:0001';
$d->{title} = 'First Photo';
$d->{filename} = "$bin/Images/people.jpg";

%$s = %$d;
$s->{type} = 'photo';
$s->{photo} = "$gallery_url/photo0001.jpg";
$s->{thumb} = "$gallery_url/thumb0001.jpg";
$s->{url} = "$gallery_url/index.html#0001";
delete $s->{filename};

$photo->add_data('gallery', $d);
my $r = $photo->read_data('gallery:0001');

is_deeply($s, $r, "Add first photo"); # Test 4

ok(-e "$gallery_dir/photo0001.jpg", "Photo file"); # Test 5
ok(-e "$gallery_dir/thumb0001.jpg", "Thumb file"); # Test 6

#----------------------------------------------------------------------
# Browse photod

my $results = $gallery->browse_data('gallery');
is_deeply($results, [$s], "Browse photos"); # test 7

#----------------------------------------------------------------------
# Search photos

my $list = $gallery->search_data({title => 'First'}, 'gallery');
is_deeply($list, [$s], "Search photos"); # test 8

#----------------------------------------------------------------------
# Edit photo

$d->{id} = 'gallery:0001';
$d->{title} = 'New Title';
$s->{title} = $d->{title};

$photo->edit_data('gallery:0001', $d);
$r = $photo->read_data('gallery:0001');
is_deeply($r, $s, "Edit photo"); # Test 9

#----------------------------------------------------------------------
# Remove photo

$d->{id} = 'gallery:0001';
$photo->remove_data('gallery:0001', $d);
$r = $photo->read_data('gallery:0001');
is($r, undef, "Remove photo"); # Test 10

ok(! -e "$gallery_dir/photo0001.jpg", "Removed photo file"); # Test 11
ok(! -e "$gallery_dir/thumb0001.jpg", "Removed thumb file"); # Test 12

