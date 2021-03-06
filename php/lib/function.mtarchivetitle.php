<?php
# Movable Type (r) Open Source (C) 2001-2013 Six Apart, Ltd.
# This program is distributed under the terms of the
# GNU General Public License, version 2.
#
# $Id$

require_once("archive_lib.php");
function smarty_function_mtarchivetitle($args, &$ctx) {
    $at = $ctx->stash('current_archive_type');
    if (isset($args['type'])) {
        $at = $args['type'];
    } elseif (isset($args['archive_type'])) {
        $at = $args['archive_type'];
    }
    if ($at == 'Category') {
         $title = $ctx->tag('CategoryLabel', $args);
         if ( !empty( $title )) {
             $title = encode_html( strip_tags( $title ));
         } else {
             $title = '';
         }
         return $title;
    } else {
        $ar = ArchiverFactory::get_archiver($at);
        return $ar->get_title($args, $ctx);
    }
}
?>
