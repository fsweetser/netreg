#   -*- perl -*-
#
# CMU::Netdb::SOAPAccess
# This module provides the SOAP wrappers for the entire API
#
# Copyright 2004 Carnegie Mellon University
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

package CMU::Netdb::SOAPAccess;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug $AUTOLOAD %SOAP_FUNCTIONS $output_limit);
use CMU::Netdb;
use UNIVERSAL;
use Data::Dumper;

require Exporter;
@ISA = qw(Exporter SOAP::Server::Parameters);
@EXPORT = qw();

my $debug = 0;

$output_limit = 2000;

#################
# README
#
# Things still to be done/considered:
# - Error Output.  Right now three different types of errors can occur. 
#   I want to fix this.  The three types are: NetReg API errors (standard two part
#   error code array in $soapRes->result->{result}, wrapper config/argument errors
#   (no $soapRes->result->{result}, instead ->{error} and ->{error_text} exist), and 
#   wrapper runtime/generation errors, which currently call die (bad idea?, should 
#   be changed to error/error_text style.
#   - UPDATE: FIXED in this version.  Either $soapRes->result->{result} will exist, and 
#     have "valid" data, or a SOAP fault will be returned, which should be tested for
#     via $soapRes->fault, with the fault message being in $soapRes->faultdetail.  
#     This is the correct SOAP way to return errors.
#
#
# - API export configuration.  The 'what API calls to export' structure should be 
#   moved to the config file.  This means new API calls could be exported without
#   having to restart the server
#   - I'm still debating this.  
#
# - API argument types.  At least one more argument type needs to be added, UNSIGNED_INTEGER,
#   for modify/delete calls that take an id & version.
#   - I'm also adding DATE and CONSTANT.
#
# - SQL Sanity checking.  Right now i'm only checking for semicolons in the where clause
#
# - API argument sanity checking.  Right now we're just relying on the API to catch 
#   argument errors.  This is probably ok, but as more of the API is exported
#   we need to be conscious of this.
#
# - The SOAP API doesn't do any per-column filtering by access level.  The 
#   changes to the core API to do this must be deployed along with the SOAP API.



%SOAP_FUNCTIONS = ( 'add_machine' => { 'function' => \&CMU::Netdb::add_machine,
				       'arguments' => [ { 'type' => 'EVAL',
							  'eval' => 'CMU::Netdb::get_add_level($dbh, $dbuser, \'machine\', 0);',
							},
							{ 'name' => 'fields',
							  'type' => 'HASHREF',
							  'blank' => 'DISALLOWED',
							  'optional' => 0,
							},
							{ 'name' => 'perms',
							  'type' => 'HASHREF',
							  'blank' => 'DISALLOWED',
							  'optional' => 0,
							},
						      ],
				       'return' => 'ARRAY',
				     },
		    'expire_machine' => { 'function' => \&CMU::Netdb::expire_machine,
					  'arguments' => [ { 'name' => 'id',
							     'type' => 'UNSIGNED_INTEGER',
							     'blank' => 'DISALLOWED',
							     'optional' => 0,
							   },
							   { 'name' => 'version',
							     'type' => 'UNSIGNED_INTEGER',
							     'blank' => 'DISALLOWED',
							     'optional' => 0,
							   },
							   { 'name' => 'expires',
							     'type' => 'DATE',
							     'blank' => 'ALLOWED',
							     'optional' => 0,
							   },
							 ],
					  'return' => 'ARRAY',
					},
		    'get_subnets_ref' => { 'function' => \&CMU::Netdb::get_subnets_ref,
					   'arguments' => [ { 'name' => 'where',
							      'type' => 'SQL',
							      'blank' => 'DISALLOWED',
							      'optional' => 0,
							    },
							    { 'type' => 'CONSTANT',
							      'value' => 'subnet.name',
							    },
							  ],
					   'return' => 'REFERENCE',
					 },
		    'get_vlan_subnet_presence' => { 'function' => \&CMU::Netdb::get_vlan_subnet_presence,
					    'arguments' => [ { 'name' => 'where',
							       'type' => 'SQL',
							       'blank' => 'ALLOWED',
							       'optional' => 0,
							     },
						       ],
					    'return' => 'REFERENCE',
					  },
		    'get_write_level' => { 'function' => \&CMU::Netdb::get_write_level,
					   'arguments' => [ { 'name' => 'table',
							      'type' => 'TABLE',
							      'blank' => 'DISALLOWED',
							      'optional' => 0,
							    },
							    { 'name' => 'tid',
							      'type' => 'UNSIGNED_INTEGER',
							      'blank' => 'DISALLOWED',
							      'optional' => 0,
							    },
							  ],
					   'return' => 'INTEGER',
					 },
		    'list_groups' => { 'function' => \&CMU::Netdb::list_groups,
				       'arguments' => [ { 'name' => 'where',
							  'type' => 'SQL',
							  'blank' => 'ALLOWED',
							  'optional' => 0,
							},
						      ],
				       'return' => 'REFERENCE',
				     },
		    'list_vlans' => { 'function' => \&CMU::Netdb::list_vlans,
				       'arguments' => [ { 'name' => 'where',
							  'type' => 'SQL',
							  'blank' => 'ALLOWED',
							  'optional' => 0,
							},
						      ],
				       'return' => 'REFERENCE',
				     },
		    'list_machines' => { 'function' => \&CMU::Netdb::list_machines,
					 'arguments' => [ { 'name' => 'where',
							    'type' => 'SQL',
							    'blank' => 'DISALLOWED',
							    'optional' => 0,
							  },
							],
					 'return' => 'REFERENCE',
				       },
		    'list_machines_protections' => { 'function' => \&CMU::Netdb::list_machines_protections,
						     'arguments' => [ { 'name' => 'where',
									'type' => 'SQL',
									'blank' => 'DISALLOWED',
									'optional' => 0,
								      },
								    ],
						     'return' => 'REFERENCE',
						   },
		    'count_machines' => { 'function' => \&CMU::Netdb::count_machines,
					  'arguments' => [ {'name' => 'where',
							    'type' => 'SQL',
							    'blank' => 'DISALLOWED',
							    'optional' => 1,
							   },
							 ],
					  'return' => 'REFERENCE',
					},
		    'list_machines_personal' => { 'function' => \&CMU::Netdb::list_machines_munged_protections,
						  'arguments' => [ { 'type' => 'CONSTANT',
								     'value' => 'USER',
								   },
								   { 'type' => 'EVAL',
								     'eval' => '$dbuser',
								   },
								   { 'name' => 'where',
								     'type' => 'SQL',
								     'blank' => 'ALLOWED',
								     'optional' => 0,
								   },
								 ],
						  'return' => 'REFERENCE',
						},
		    'list_machines_by_user' => { 'function' => \&CMU::Netdb::list_machines_munged_protections,
						  'arguments' => [ { 'type' => 'CONSTANT',
								     'value' => 'USER',
								   },
								   { 'type' => 'CREDENTIAL',
								     'name' => 'user',
								     'blank' => 'DISALLOWED',
								     'optional' => 0
								   },
								   { 'name' => 'where',
								     'type' => 'SQL',
								     'blank' => 'ALLOWED',
								     'optional' => 0,
								   },
								 ],
						  'return' => 'REFERENCE',
						},
		    'list_machines_writable_by_user' => { 'function' => \&CMU::Netdb::list_machines_munged_protections,
							  'arguments' => [ { 'type' => 'CONSTANT',
									     'value' => 'WRITE',
									   },
									   { 'type' => 'CREDENTIAL',
									     'name' => 'user',
									     'blank' => 'DISALLOWED',
									     'optional' => 0
									   },
									   { 'name' => 'where',
									     'type' => 'SQL',
									     'blank' => 'ALLOWED',
									     'optional' => 0,
									   },
									 ],
							  'return' => 'REFERENCE',
						},
		    'list_machines_by_group' => { 'function' => \&CMU::Netdb::list_machines_munged_protections,
						  'arguments' => [ { 'type' => 'CONSTANT',
								     'value' => 'GROUP',
								   },
								   { 'type' => 'GROUPNAME',
								     'name' => 'group',
								     'blank' => 'DISALLOWED',
								     'optional' => 0
								   },
								   { 'name' => 'where',
								     'type' => 'SQL',
								     'blank' => 'ALLOWED',
								     'optional' => 0,
								   },
								 ],
						  'return' => 'REFERENCE',
						},
		    'list_members_of_group' => { 'function' => \&CMU::Netdb::list_members_of_group,
						 'arguments' => [ { 'name' => 'group',
								    'type' => 'SQL',
								    'blank' => 'DISALLOWED',
								    'optional' => 0,
								  },
								  { 'name' => 'where',
								    'type' => 'SQL',
								    'blank' => 'ALLOWED',
								    'optional' => 0,
								  },
								],
						 'return' => 'REFERENCE',
					       },
 		    'list_memberships_of_user' => { 'function' => \&CMU::Netdb::list_memberships_of_user,
 						    'arguments' => [ { 'name' => 'user',
								       'type' => 'SQL',
								       'blank' => 'DISALLOWED',
								       'optional' => 0,
								     },
 								   ],
 						    'return' => 'REFERENCE',
 						  },
 		    'list_protections' => { 'function' => \&CMU::Netdb::list_protections,
 					    'arguments' => [ { 'name' => 'table',
							       'type' => 'SQL',
							       'blank' => 'DISALLOWED',
							       'optional' => 0,
							     },
							     { 'name' => 'row',
							       'type' => 'UNSIGNED_INTEGER',
							       'blank' => 'DISALLOWED',
							       'optional' => 0,
							     },
							     { 'name' => 'where',
							       'type' => 'SQL',
							       'blank' => 'ALLOWED',
							       'optional' => 1,
							     },
 							   ],
 					    'return' => 'REFERENCE',
 					  },
		    'delete_user_from_protections' => { 'function' => \&CMU::Netdb::delete_user_from_protections,
							'arguments' => [
									{ 'name' => 'user',
									  'type' => 'CREDENTIAL',
									  'blank' => 'DISALLOWED',
									  'optional' => 0
									},
									{ 'name' => 'table',
									  'type' => 'SQL',
									  'blank' => 'DISALLOWED',
									  'optional' => 0
									},
									{ 'name' => 'row',
									  'type' => 'UNSIGNED_INTEGER',
									  'blank' => 'DISALLOWED',
									  'optional' => 0
									},
									{ 'name' => 'level',
									  'type' => 'UNSIGNED_INTEGER',
									  'blank' => 'DISALLOWED',
									  'optional' => 0
									},
								       ],
							'return' => 'ARRAY',
						      },
		    'add_outlet' => { 'function' => \&CMU::Netdb::add_outlet,
				      'arguments' => [ { 'type' => 'EVAL',
							 'eval' => 'CMU::Netdb::get_add_level($dbh, $dbuser, \'machine\', 0);',
						       },
						       { 'name' => 'fields',
							 'type' => 'HASHREF',
							 'blank' => 'DISALLOWED',
							 'optional' => 0,
						       },
						       { 'name' => 'perms',
							 'type' => 'HASHREF',
							 'blank' => 'DISALLOWED',
							 'optional' => 0,
						       },
						     ],
				      'return' => 'ARRAY',
				    },
		    
		    
		    
		    'list_outlets_cables' => { 'function' => \&CMU::Netdb::list_outlets_cables,
					       'arguments' => [ { 'name' => 'where',
								  'type' => 'SQL',
								  'blank' => 'DISALLOWED',
								  'optional' => 0,
								},
							      ],
					       'return' => 'REFERENCE',
					     },
		    'list_cables_outlets' => { 'function' => \&CMU::Netdb::list_cables_outlets,
					       'arguments' => [ { 'name' => 'where',
								  'type' => 'SQL',
								  'blank' => 'DISALLOWED',
								  'optional' => 0,
								},
							      ],
					       'return' => 'REFERENCE',
					     },
		    'list_outlets_devport' => { 'function' => \&CMU::Netdb::list_outlets_devport,
					 'arguments' => [ { 'name' => 'where',
							    'type' => 'SQL',
							    'blank' => 'DISALLOWED',
							    'optional' => 0,
							  },
							],
					 'return' => 'REFERENCE',
					      },
		    'list_outlet_vlan_memberships' => { 'function' => \&CMU::Netdb::list_outlet_vlan_memberships,
							'arguments' => [ { 'name' => 'where',
									   'type' => 'SQL',
									   'blank' => 'DISALLOWED',
									   'optional' => 0,
									 },
								       ],
							'return' => 'REFERENCE',
						      },
		    'list_services' => { 'function' => \&CMU::Netdb::list_services,
					'arguments' => [ { 'name' => 'where',
							   'type' => 'SQL',
							   'blank' => 'ALLOWED',
							   'optional' => 0,
							 },
						       ],
					'return' => 'REFERENCE',
				      },
		    'list_service_members' => { 'function' => \&CMU::Netdb::list_service_members,
					'arguments' => [ { 'name' => 'where',
							   'type' => 'SQL',
							   'blank' => 'ALLOWED',
							   'optional' => 0,
							 },
						       ],
					'return' => 'SIMPLEARRAY',
				      },
		    'list_service_full_ref' => { 'function' => \&CMU::Netdb::list_service_full_ref,
					'arguments' => [ { 'name' => 'service',
							   'type' => 'UNSIGNED_INTEGER',
							   'blank' => 'DISALLOWED',
							   'optional' => 0,
							 },
						       ],
					'return' => 'REFERENCE',
				      },
		    'list_subnets' => { 'function' => \&CMU::Netdb::list_subnets,
					'arguments' => [ { 'name' => 'where',
							   'type' => 'SQL',
							   'blank' => 'ALLOWED',
							   'optional' => 0,
							 },
						       ],
					'return' => 'REFERENCE',
				      },
		    'list_subnets_ref' => { 'function' => \&CMU::Netdb::list_subnets_ref,
					    'arguments' => [ { 'name' => 'where',
							       'type' => 'SQL',
							       'blank' => 'ALLOWED',
							       'optional' => 0,
							     },
							     { 'name' => 'efield',
							       'type' => 'SQL',
							       'blank' => 'DISALLOWED',
							       'optional' => 0,
							     },
						       ],
					    'return' => 'REFERENCE',
					  },
		    'list_subnet_presences' => { 'function' => \&CMU::Netdb::list_subnet_presences,
					    'arguments' => [ { 'name' => 'where',
							       'type' => 'SQL',
							       'blank' => 'ALLOWED',
							       'optional' => 0,
							     },
						       ],
					    'return' => 'REFERENCE',
					  },
		    'list_vlan_subnet_presences' => { 'function' => \&CMU::Netdb::list_vlan_subnet_presences,
					    'arguments' => [ { 'name' => 'where',
							       'type' => 'SQL',
							       'blank' => 'ALLOWED',
							       'optional' => 0,
							     },
						       ],
					    'return' => 'REFERENCE',
					  },
		    'list_users' => { 'function' => \&CMU::Netdb::list_users,
				      'arguments' => [ { 'name' => 'where',
							 'type' => 'SQL',
							 'blank' => 'ALLOWED',
							 'optional' => 0,
						       },
						     ],
				      'return' => 'REFERENCE',
				    },

 		    'modify_machine' => { 'function' => \&CMU::Netdb::modify_machine,
					  'arguments' => [ { 'name' => 'id',
							     'type' => 'UNSIGNED_INTEGER',
							     'blank' => 'DISALLOWED',
							     'optional' => 0,
							   },
							   { 'name' => 'version',
							     'type' => 'UNSIGNED_INTEGER',
							     'blank' => 'DISALLOWED',
							     'optional' => 0,
							   },
							   { 'type' => 'EVAL',
							     'eval' => 'CMU::Netdb::get_add_level($dbh, $dbuser, \'machine\', 0);',
							   },
							   { 'name' => 'fields',
							     'type' => 'HASHREF',
							     'blank' => 'DISALLOWED',
							     'optional' => 0,
							   },
							 ],
					  'return' => 'ARRAY',
 					},
		    'get_departments' => => { 'function' => \&CMU::Netdb::get_departments,
					      'arguments' => [ { 'type' => 'CONSTANT',
								 'value' => '',
							       },
							       { 'type' => 'CONSTANT',
								 'value' => 'ALL',
							       },
							       { 'type' => 'CONSTANT',
								 'value' => '',
							       },
							       { 'type' => 'CONSTANT',
								 'value' => 'groups.description',
							       },
							       { 'type' => 'CONSTANT',
								 'value' => 'GET',
							       },
							     ],
					      'return' => 'REFERENCE',
					    },
		     'search_leases' => { 'function' => \&CMU::Netdb::search_leases,
					  'arguments' => [ { 'name' => 'fields',
							     'type' => 'HASHREF',
							     'blank' => 'DISALLOWED',
							     'optional' => 0,
							   },
							   { 'name' => 'time',
							     'type' => 'UNSIGNED_INTEGER',
							     'blank' => 'DISALLOWED',
							     'optional' => 0,
							   },
							  ],
					   'return' => 'ARRAY',
					 },
		    'get_db_hostname' => { 'function' => \&CMU::Netdb::get_db_variable,
					   'arguments' => [ { 'type' => 'CONSTANT',
							      'value' => 'hostname',
							    },
							  ],
					   'return' => 'ARRAY',
					 },


		  );


sub AUTOLOAD {
  return if $AUTOLOAD =~ /::DESTROY$/;
  warn Data::Dumper->Dump([\%SOAP_FUNCTIONS],['SOAP_FUNCTIONS']) if ($debug >= 2);
  $AUTOLOAD =~ s/^.*:://;
  die "No $AUTOLOAD method in NetDB SOAP API" 
    unless defined($SOAP_FUNCTIONS{$AUTOLOAD});

  warn __FILE__,':',__LINE__, ": SOAPAccess compiling subroutine for $AUTOLOAD\n" if ($debug >= 1);

  my $code = <<END_CODE;
sub $AUTOLOAD {
  my \$self = shift;
  my \$env = pop;
  my \$params = \$env->method();
  my %dummy;
  my \$dbh=soap_db_connect();
  my \$dbuser = getUserInfo();
  my \$res;
  my \@ret;
  if (!ref \$params) {
    \$params = {};
  }
  warn "SOAPAccess:",__FILE__,':',__LINE__, ": Entering $AUTOLOAD at ".localtime(time)."\\n"if (\$debug >= 2); 
#  warn "$AUTOLOAD arguments:\\n".Data::Dumper->Dump([\\\@_],['args'])."\\n";
#  warn Data::Dumper->Dump([\\\%SOAP_FUNCTIONS],['SOAP_FUNCTIONS']);  
  warn "SOAPAccess:$AUTOLOAD: dbuser '\$dbuser'" if (\$debug >= 3);
  warn "SOAPAccess:$AUTOLOAD: " . Data::Dumper->Dump([\$self, \$params, \$env->body],['object', 'params', 'request']) . "\\n" if (\$debug >= 3);
  my \@args = ();
  for (my \$i = 0; \$i <= \$\#{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}}; \$i++) {
    if (\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{type} eq 'EVAL') {
      push \@args, eval(\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{eval});
      next;
    } elsif (\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{type} eq 'CONSTANT') {
      push \@args, \$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{value};
      next;
    } elsif (\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{optional} == 1 
	&& !defined(\$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}})) {
      push \@args, undef;
      next;
    } elsif (!defined \$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}) {
      die "Server configuration error:  $AUTOLOAD argument \$i has no name and is not of type EVAL.";
    } elsif (!defined(\$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}})) {
      die "Missing argument '\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}' (\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{type}) to $AUTOLOAD";
    } elsif (\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{blank} eq 'ALLOWED'
        && \$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}} eq '') {
      push \@args, '';
      next;
    } elsif (\$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}} eq '') {
      die "Argument '\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}' (\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{type}) to $AUTOLOAD may not be blank.";
    } elsif (\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{type} eq 'SQL') {
      # FIXME Validate SQL here
      if (\$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}} =~ /;|--|union\\s+select/i) {
        die "Invalid SQL in argument \$i to $AUTOLOAD";
      } else {
        push \@args, \$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}};
        next;
      }
    } elsif (\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{type} eq 'UNSIGNED_INTEGER') {
      if (!((int(\$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}}) 
             eq \$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}})
            && (\$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}} >= 0))) {
        die "Argument \$i to $AUTOLOAD must be an UNSIGNED_INTEGER";
      } else {
        push \@args, \$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}};
        next;
      }
    } elsif (\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{type} eq 'CREDENTIAL') {
      if (!(\$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}} =~ /^[A-Za-z0-9\.\\@]+\$/s)) {
        die "Argument \$i to $AUTOLOAD must be a CREDENTIAL";
      } else {
        push \@args, \$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}};
        next;
      }
    } elsif (\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{type} eq 'GROUPNAME') {
      if (!(\$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}} =~ /^[A-Za-z]+:[A-Za-z]+\$/s)) {
        die "Argument \$i to $AUTOLOAD must be a CREDENTIAL";
      } else {
        push \@args, \$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}};
        next;
      }
    } elsif (\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{type} eq 'DATE') {
      if (!((\$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}}
             =~ /^\d{4}-\d{2}-\d{2}\$/ ))) {
        die "Argument \$i to $AUTOLOAD must be a DATE (YYYY-MM-DD)";
      } else {
        push \@args, \$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}};
        next;
      }
    } elsif (\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{type} eq 'HASHREF') {
      if (ref(\$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}}) eq "HASH") {
        push \@args, \$params->{\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}};
        next;
      } else {
        die "Argument '\$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{name}' to $AUTOLOAD is not a hash reference";
      }
    } else {
      die "Server configuration error: Unknown argument type \$SOAP_FUNCTIONS{$AUTOLOAD}{arguments}[\$i]{type} at argument \$i in $AUTOLOAD";
    }
  }

  if (ref(\$SOAP_FUNCTIONS{$AUTOLOAD}{function}) ne "CODE") {
    warn Data::Dumper->Dump([\\\%SOAP_FUNCTIONS],['SOAP_FUNCTIONS']);
    die 'Server configuration error: No function pointer for $AUTOLOAD, found a reference to '.ref(\$SOAP_FUNCTIONS{$AUTOLOAD}{function}).' instead.';
  }
  eval {
    if (\$SOAP_FUNCTIONS{'$AUTOLOAD'}{return} eq 'REFERENCE') {
      if (\@args) {
        \$res= \$SOAP_FUNCTIONS{'$AUTOLOAD'}{function}->(\$dbh, \$dbuser, \@args);
      } else {
        \$res= \$SOAP_FUNCTIONS{'$AUTOLOAD'}{function}->(\$dbh, \$dbuser);
      }
    } elsif (\$SOAP_FUNCTIONS{'$AUTOLOAD'}{return} eq 'ARRAY' 
             || \$SOAP_FUNCTIONS{'$AUTOLOAD'}{return} eq 'SIMPLEARRAY') {
      if (\@args) {
        \@\$res= \$SOAP_FUNCTIONS{'$AUTOLOAD'}{function}->(\$dbh, \$dbuser, \@args);
      } else {
        \@\$res= \$SOAP_FUNCTIONS{'$AUTOLOAD'}{function}->(\$dbh, \$dbuser);
      }
    } else {
      die "Server configuration error: Unknown return type \$SOAP_FUNCTIONS{'$AUTOLOAD'}{return} for $AUTOLOAD";
    }
  };
  if (\$@) {
     warn __FILE__, ":", __LINE__, " : $AUTOLOAD: not ok: ", \$@, " \\nCode: \$res= \\\$SOAP_FUNCTIONS{$AUTOLOAD}{function}(\\\$dbh, \$dbuser, ".join(', ',\@args).");" if ($debug >= 2);
     die "API error: $AUTOLOAD: ".\$@;
  } elsif (\$SOAP_FUNCTIONS{'$AUTOLOAD'}{return} eq 'REFERENCE' && !ref \$res) {
    die "Error in $AUTOLOAD: \$CMU::Netdb::errors::errmeanings{\$res} \$CMU::Netdb::primitives::db_errstr\\n" 
      if (\$res eq \$CMU::Netdb::errcodes{EDB});
    die "Error in $AUTOLOAD: \$CMU::Netdb::errors::errmeanings{\$res}\n";
  } elsif (\$SOAP_FUNCTIONS{'$AUTOLOAD'}{return} eq 'ARRAY' && \$res->[0] <= 0) {
    die "Error in $AUTOLOAD: \$CMU::Netdb::errors::errmeanings{\$res->[0]} \$CMU::Netdb::primitives::db_errstr\\n"
      if (\$res->[0] eq \$CMU::Netdb::errcodes{EDB});
    die "Error in $AUTOLOAD: \$CMU::Netdb::errors::errmeanings{\$res->[0]} (".join(',',\@{\$res->[1]}).")\\n";
  } elsif (ref \$res eq 'ARRAY' && scalar \@\$res > \$output_limit) {
    warn 'SOAPAccess:', __FILE__, ':', __LINE__, ": Aborting return of $AUTOLOAD at ".localtime(time)." because of output limit settings, ".scalar \@\$res." rows returned.\\n" if (\$debug >= 2); 
    die "Too many rows returned (".scalar \@\$res." > ".\$output_limit.")\n";
  } else {
    warn 'SOAPAccess:', __FILE__, ':', __LINE__, ": Normal exit of $AUTOLOAD at ".localtime(time)."\\n" if (\$debug >= 2); 
    \$dbh->disconnect();
    return SOAP::Data->name('result')
                     ->value(\$res)
                     ->uri('http://www.net.cmu.edu/netreg');
  }
}
END_CODE
  eval $code;
  if ($@) {
    die "Cannot create AUTOLOAD stub for $AUTOLOAD: $@\n$code\n";
  }
  goto &$AUTOLOAD;
}

sub soap_db_connect {
  my ($dbh, $pass);

  my ($vres, $SOAP_DB) = CMU::Netdb::config::get_multi_conf_var('soap', 'NetReg_SOAP_DB');

  die "Error connecting to netreg database: NetReg_SOAP_DB connect info not found".
    "($vres)" if ($vres != 1);

  if (defined $SOAP_DB->{'password_file'}) {
    open(FILE, $SOAP_DB->{'password_file'})
      || die "Cannot open NetDB password file (".$SOAP_DB->{'password_file'}.")!";
    $pass = <FILE>;
    chomp $pass;
    close(FILE);
  }else{
    $pass = $SOAP_DB->{'password'};
  }

  warn __FILE__, ':', __LINE__, ' :>'.
    "connection: ".$SOAP_DB->{'connect_string'}." / ".$SOAP_DB->{'username'}."\n"
      if ($debug >= 1);
  
  $dbh = DBI->connect($SOAP_DB->{'connect_string'},
		      $SOAP_DB->{'username'},
		      $pass);
  if (!$dbh) {
    die "Unable to get database connection.\n";
  }

  my $user = &getUserInfo;
  my ($vres, $rSuperUsers) = CMU::Netdb::config::get_multi_conf_var
    ('soap', 'SuperUsers');
  $rSuperUsers = [$rSuperUsers] if ($vres == 1 && !ref $rSuperUsers eq 'ARRAY');

  if ($user eq 'netreg') {
    die("Netreg User Denied: For safety reasons, the netreg user is not allowed to use the ".
	"soap interface to the database.\n");
  }
  if (!grep(/^$user$/, @$rSuperUsers)) {
    my ($code, $val) = CMU::Netdb::get_sys_key($dbh, 'DB_OFFLINE');
    if ($code >= 1) {
      die("Database Offline: The database is temporarily offline. Please try again later.\n");
    }
  }

  return $dbh;
}

sub getUserInfo {
  my $user = '';
  $user = $ENV{REMOTE_USER} if (defined $ENV{REMOTE_USER});
  if ($user eq '' && defined $ENV{SSL_CLIENT_V3EXT_SUBJECT_ALT_NAME}) {
    my @AltNames = split(/\s*\,\s*/, $ENV{SSL_CLIENT_V3EXT_SUBJECT_ALT_NAME});
    my @EmailNames = grep (/^email:/i, @AltNames);
    if ($#EmailNames > -1) {
      # Can only use one email sadly
      $user = $EmailNames[0];
      $user =~ s/^email://i;
    }else{
      # Just get the first one
      if ($#AltNames > -1) {
	my $nul;
	($nul, $user) = split(/\:/, $AltNames[0], 2);
      }
    }
  }

  $user = $ENV{SSL_CLIENT_S_DN_Email} if ($user eq '' &&
					  defined $ENV{SSL_CLIENT_S_DN_Email});
  $user = $ENV{SSL_CLIENT_EMAIL} if ($user eq '' &&
				     defined $ENV{SSL_CLIENT_EMAIL});

  warn "User is '$user'" if ($debug >= 3);

  CMU::Netdb::primitives::clear_changelog("SOAP:$ENV{REMOTE_ADDR}");


  return $user;
}

1;
