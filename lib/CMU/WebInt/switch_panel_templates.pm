#   -*- perl -*- 
# 
# CMU::WebInt::switch_panel_templates
# 
# Copyright 2001 Carnegie Mellon University  
# 
# All Rights Reserved 
# 
# Permission to use, copy, modify, and distribute this software and its 
# documentation for any purpose and without fee is hereby granted, 
# provided that the above copyright notice appear in all copies and that 
# both that copyright notice and this permission notice appear in 
# supporting documentation, and that the name of CMU not be 
# used in advertising or publicity pertaining to distribution of the 
# software without specific, written prior permission. 
#  
# CMU DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING 
# ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL 
# CMU BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR 
# ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, 
# WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, 
# ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS 
# SOFTWARE. 
# 
# 

 
package CMU::WebInt::switch_panel_templates; 
use strict; 
use warnings;

use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings $THCOLOR 
             $style); 
use CMU::WebInt; 
use CMU::Netdb; 
use CGI; 
use DBI; 
{ 
  no strict; 
  $VERSION = '0.01'; 
} 
 
require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw($style);


$style =<<EndOfStyle;
<style><!--

div.h_scroll {
	width: 100%;
	overflow: auto;
	border: 1px solid #666;
	padding: 8px;
}


table.switch {
  background : black;
  border : black;
}

table.state {
  background : white;
  border : black;
}

th.visible {
  background : white;
  color : black;
}

.plug {
  width: 60px;
  text-align: center;
}

.plug_wide {
  width: 80px;
  text-align: center;
}

.buttons a {
  color: #000000;
  background-color: rgb(255,255,255) ;
  display: block;
  width: 100%;
  height: 100%;
  font: 12px Arial, sans-serif;
  font-weight: bold;
  text-decoration: none;
  text-align: center;
  padding-top: 5px;
  padding-bottom: 5px;
}

.gbic {
  width: 60px;
  text-align: center;
}

.up a {
  background-color : rgb(0,175,0);
}

.up {
  background-color : rgb(0,175,0);
}

.unconf a {
  background-color : rgb(255,255,255);
}

.unconf {
  background-color : rgb(255,255,255);
}

.partitioned a {
  background-color : rgb(255,0,0);
}

.partitioned {
  background-color : rgb(255,0,0);
}

.error a {
  background-color : rgb(240,200,0);
}

.error {
  background-color : rgb(240,200,0);
}

.nolink a {
  background-color : rgb(104,246,104);
}

.nolink {
  background-color : rgb(104,246,104);
}

.misconf a {
  background-color : rgb(23,202,234)
}

.misconf {
  background-color : rgb(23,202,234)
}

.spacer {
  background-color : rgb(0,0,0);
}


//--></style>

EndOfStyle


1;
