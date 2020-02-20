#!perl
use strict;
use warnings;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

use Mojolicious::Lite;
use Getopt::Long;

#GetOptions(
#    'config|f=s' => \my $config_file,
#    'help'       => \my $display_help,
#) or pod2usage(2);
#pod2usage(1) if $display_help;

=head1 SYNOPSIS

  mojo-assetreloader.pl daemon _site/
  mojo-assetreloader.pl daemon _site/ --config=mysite.ini

  Options:
    --config config file to use

=head1 OPTIONS

=over 4

=item B<--config>

Specify a config file.

=item B<--help>

Print a brief help message

=item B<--verbose>

=back

=head1 DESCRIPTION

This program will serve a directory over HTTP and will notify the browser of
changes to the files on the file system.

=cut

my( $mode, $filename, @options ) = @ARGV;

# If we have a precompressed resource, serve that
app->static->with_roles('+Compressed');

# Compress all dynamic resources as well
plugin 'Gzip';
plugin 'DefaultHelpers';

our $html;

open my $fh, '<', $filename
    or die "Couldn't read '$filename': $!";
binmode $fh, ':encoding(UTF-8)';
$html = do { local $/; <$fh> };
$html =~ s!</head>!<script src="/editor.js"></script></head>!i;
# Do the contenteditable below dynamically from JS so we can make everything except
# our editor controls contenteditable
$html =~ s!<body(\b[^>]*?)>!<body onload="javascript:init_editor()"$1>!i;

get '/' => sub {
    my $c = shift;
    $c->render(text => $html);
};

# consider making this a websocket too...
post '/save' => sub {
    my $c = shift;

    $html = $c->req->body;

    open my $fh, '>', $filename
        or die "Couldn't write '$filename': $!";
    binmode $fh, ':encoding(UTF-8)';
    print { $fh } $html;

    # notify other listeners, maybe

    $c->redirect_to('/');
};

app->max_request_size(16777216);
app->start;

__DATA__
@@ editor.js
"use strict";

// update the cursor position whenever our contentEditable element
// loses focus (onblur)
// let cursorPosition;
var sourcearea;
var editablearea;

function init_editor() {
    //let children = window.document.body.childNodes;
    //for( let i = 0; i < children.length; i++ ) {
        // children[i].contentEditable = true;
        // Add blur listener for saving the cursor position
        // Add input listener for updating the source code view
    //};

    window.document.body.innerHTML
        =
          '<div id="contenteditor_container" style="position:fixed; top:0; width:100%">'
          + '<div id="contenteditor_toolbar">'
          +     '<a href="#" onclick="javascript:insert_bold()" alt="bold"><b>B</b></a>'
          +     ' <a href="#" onclick="javascript:insert_h1()" alt="H1"><b>H1</b></a>'
          +     ' <a href="#" onclick="javascript:insert_li()" alt="LI"><b>LI</b></a>'
          +     ' <a href="#" onclick="javascript:insert_li()" alt="Toggle source view"><b>SRC</b></a>'
          + '</div>'
          + '<textarea id="contenteditor_source" style="width:100%"></textarea>'
        + '</div>'
        + '<div id="contenteditable_container" contenteditable="true">'
        + window.document.body.innerHTML
        + '</div>';
    sourcearea = document.getElementById('contenteditor_source');
    editablearea = document.getElementById('contenteditable_container');
    sourcearea.value = editablearea.innerHTML;
    window.addEventListener('keydown', async (event) => {
        if( event.ctrlKey || event.metaKey) {
            let key = String.fromCharCode(event.which).toLowerCase();
            switch (key) {
                case 's':
                    event.preventDefault();
                    initiateSave(window.document);
                    break;
            }
        }
    });
    sourcearea.addEventListener('input', (el) => {
        if( sourcearea == document.activeElement ) {
            console.log("Updating from textarea");
            editablearea.innerHTML = sourcearea.value;
        } else {
            // console.log("Already during update");
        }
    });
    editablearea.addEventListener('input', (el) => {
        if( document.activeElement.closest('#contenteditable_container') ) {
            // console.log("Updating from HTML contentEditable");
            sourcearea.value = editablearea.innerHTML;
        } else {
            // console.log("contentEditable area does not have focus, nothing to do");
        }
    });
}

function insert_bold() {
    // insert <b></b> at cursorPosition
}

function toggle_source() {
    if(sourcearea.visible) {
        sourcearea.display = 'none';
    } else {
        sourcearea.display = 'block';
    }
    window.documentElement
}

async function initiateSave(doc) {
    // show "saving" animation
    let newDocument = doc.documentElement.cloneNode(true);
    let newBody = newDocument.firstChild;
    while( newBody.tagName !== 'BODY' ) {
        newBody = newBody.nextSibling
    };
    let n = newBody.firstChild;
    while( n ) {
        if( n.id == 'contenteditor_container') {
            let kill = n;
            n = n.prevSibling || n.nextSibling;
            newBody.removeChild(kill);

        } else if( n.id == 'contenteditable_container') {
            let content = n.childNodes;
            while( content.length ) {
                newBody.insertBefore( content[0], n );
            };
            newBody.removeChild(n);
            break;
        } else {
            n = n.nextSibling;
        };
    };
    await fetch(
        '/save', {
            "method": 'POST',
            "headers": {
                'Content-Type' : 'text/html',
            },
            "body": '<html>' + newDocument.innerHTML + '</html>',
        }
    );
};
