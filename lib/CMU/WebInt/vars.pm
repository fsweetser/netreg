#   -*- perl -*-
#
# CMU::WebInt::vars
# This module defines some basic variables to be used
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
# $Id: vars.pm,v 1.82 2008/03/27 19:42:38 vitroth Exp $
#
#

package CMU::WebInt::vars;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %sections %realms
	    %opcodes %htext
	   );

require Exporter;
@ISA = qw(Exporter);

%sections = ('USER_ADMIN' => 'User Administration',
	     'HOST_OPS' => 'Host Operations',
	     'DOMAIN_OPS' => 'Domain Operations');

%opcodes = ('sub_info' => \&CMU::WebInt::subnets::subnets_view,
	    'sub_add_domain' => \&CMU::WebInt::subnets::subnets_add_domain,
	    'sub_del_domain' => \&CMU::WebInt::subnets::subnets_del_domain,
	    'sub_add_pres' => \&CMU::WebInt::subnets::subnets_add_presence,
	    'sub_del_pres' => \&CMU::WebInt::subnets::subnets_del_presence,
	    'sub_update' => \&CMU::WebInt::subnets::subnets_update,
	    'sub_delete' => \&CMU::WebInt::subnets::subnets_delete,
	    'sub_del_conf' => \&CMU::WebInt::subnets::subnets_deleteConfirm,
	    'listShare' => \&CMU::WebInt::subnets::subnets_share_list,
	    'viewshare' => \&CMU::WebInt::subnets::subnets_view_share,
	    'addShare' => \&CMU::WebInt::subnets::subnets_add_share_form,
	    'addShareReal' => \&CMU::WebInt::subnets::subnets_add_share,
	    'deleteShare' => \&CMU::WebInt::subnets::subnets_del_share,
	    'confShareDelete' => \&CMU::WebInt::subnets::subnets_del_share_confirm,
	    'updateShare' => \&CMU::WebInt::subnets::subnets_share_update,
	    'sub_add_form' => \&CMU::WebInt::subnets::subnets_add_form,
	    'sub_add' => \&CMU::WebInt::subnets::subnets_add,
	    'sub_main' => \&CMU::WebInt::subnets::subnets_main,
	    'subnets_show_policy' => \&CMU::WebInt::subnets::subnets_show_policy,
	    'subnets_lookup' => \&CMU::WebInt::subnets::subnets_lookup,
	    'subnets_ddo' => \&CMU::WebInt::subnets::subnets_def_dhcp_options,
	    'subnets_addips' => \&CMU::WebInt::subnets::subnets_addips,
	    'subnets_addips_exec' => \&CMU::WebInt::subnets::subnets_addips_exec,
	    'subnets_add_reg_mode' => \&CMU::WebInt::subnets::subnets_add_reg_mode,
	    'subnets_del_reg_mode' => \&CMU::WebInt::subnets::subnets_del_reg_mode,

	    # Auth
	    'auth_main' => \&CMU::WebInt::auth::authmain,
	    'auth_user_list' => \&CMU::WebInt::auth::auth_user_list,
	    'auth_user_info' => \&CMU::WebInt::auth::auth_userinfo,
	    'auth_user_del' => \&CMU::WebInt::auth::auth_delete_user,
	    'auth_user_upd' => \&CMU::WebInt::auth::auth_update_user,
	    'auth_user_add' => \&CMU::WebInt::auth::auth_add_user,
	    'auth_user_search' => \&CMU::WebInt::auth::auth_search_users,

	    'auth_grp_list' => \&CMU::WebInt::auth::auth_listgroups,
	    'auth_grp_info' => \&CMU::WebInt::auth::auth_groupinfo,
	    'auth_grp_del' => \&CMU::WebInt::auth::auth_delete_group,
	    'auth_grp_upd' => \&CMU::WebInt::auth::auth_update_group,
	    'auth_grp_add' => \&CMU::WebInt::auth::auth_add_group,
	    'auth_grp_search' => \&CMU::WebInt::auth::auth_search_groups,

	    'auth_ug_add' => \&CMU::WebInt::auth::auth_add_to_group,
	    'auth_ug_del' => \&CMU::WebInt::auth::auth_remove_from_group,
	    'auth_user_cred' => \&CMU::WebInt::auth::auth_user_cred,

	    # Buildings
	    'build_view' => \&CMU::WebInt::buildings::build_view,
	    'build_del_conf' => \&CMU::WebInt::buildings::build_confirm_del,
	    'build_del' => \&CMU::WebInt::buildings::build_delete,
	    'build_add' => \&CMU::WebInt::buildings::build_add,
	    'build_add_form' => \&CMU::WebInt::buildings::build_add_form,
	    'build_search' => \&CMU::WebInt::buildings::build_search,
	    'build_s_exec' => \&CMU::WebInt::buildings::build_s_exec,
	    'build_update' => \&CMU::WebInt::buildings::build_update,
	    'build_list' => \&CMU::WebInt::buildings::build_list,

	    # Cables
	    'cable_view' => \&CMU::WebInt::cables::cables_view,
	    'cable_list' => \&CMU::WebInt::cables::cables_main,
	    'cable_search' => \&CMU::WebInt::cables::cables_search,
	    'cable_s_exec' => \&CMU::WebInt::cables::cables_s_exec,
	    'cable_del' => \&CMU::WebInt::cables::cables_delete,
	    'cable_del_conf' => \&CMU::WebInt::cables::cables_confirm_delete,
	    'cable_upd' => \&CMU::WebInt::cables::cables_update,
	    'cable_add_s0' => \&CMU::WebInt::cables::cables_add_s0,
	    'cable_add_s1' => \&CMU::WebInt::cables::cables_add_s1,

	    # Credentials
	    'cred_add' => \&CMU::WebInt::auth::cred_add,
	    'cred_del' => \&CMU::WebInt::auth::cred_del,
	    'cred_change_type' => \&CMU::WebInt::auth::cred_change_type,
	    'cred_change_type_doit' => \&CMU::WebInt::auth::cred_change_type_doit,
        'user_type_mod' => \&CMU::WebInt::auth::user_type_mod,
        'user_type_change' => \&CMU::WebInt::auth::user_type_change,
        'user_type_del' => \&CMU::WebInt::auth::user_type_del,
        'ut_add' => \&CMU::WebInt::auth::ut_add,
        'ut_modify' => \&CMU::WebInt::auth::ut_modify,

        # User Types Perms
        'user_type_perm_mod' => \&CMU::WebInt::auth::user_type_perm_mod,
        'user_type_perm_change' => \&CMU::WebInt::auth::user_type_perm_change,
        'user_type_perm_del' => \&CMU::WebInt::auth::user_type_perm_del,
        'utp_add' => \&CMU::WebInt::auth::utp_add,
        'utp_modify' => \&CMU::WebInt::auth::utp_modify,
	    
        # DHCP Option Types
	    'dhcp_o_t_view' => \&CMU::WebInt::dhcp::dhcp_o_t_view,
	    'dhcp_o_t_add_form' => \&CMU::WebInt::dhcp::dhcp_o_t_add_form,
	    'dhcp_o_t_add' => \&CMU::WebInt::dhcp::dhcp_o_t_add,
	    'dhcp_o_t_update' => \&CMU::WebInt::dhcp::dhcp_o_t_update,
	    'dhcp_o_t_confirm' => \&CMU::WebInt::dhcp::dhcp_o_t_confirm,
	    'dhcp_o_t_delete' => \&CMU::WebInt::dhcp::dhcp_o_t_delete,
	    'dhcp_o_t_list' => \&CMU::WebInt::dhcp::dhcp_o_t_list,

	    # DNS Resource Types     
	    'dns_main' => \&CMU::WebInt::dns::dns_main,
	    'dns_r_t_view' => \&CMU::WebInt::dns::dns_r_t_view,
	    'dns_r_t_add_form' => \&CMU::WebInt::dns::dns_r_t_add_form,
	    'dns_r_t_add' => \&CMU::WebInt::dns::dns_r_t_add,
	    'dns_r_t_update' => \&CMU::WebInt::dns::dns_r_t_update,
	    'dns_r_t_confirm' => \&CMU::WebInt::dns::dns_r_t_confirm,
	    'dns_r_t_delete' => \&CMU::WebInt::dns::dns_r_t_delete,
	    'dns_r_t_list' => \&CMU::WebInt::dns::dns_r_t_list,
	    'dns_r_search' => \&CMU::WebInt::dns::dns_r_search,
	    'dns_r_s_exec' => \&CMU::WebInt::dns::dns_r_s_exec,
	    'dns_update' => \&CMU::WebInt::dns::dns_upd_serial,
	    
	    # Errors
	    'err_lookup' 		=> \&CMU::WebInt::errors::err_lookup,

	    # Machines
	    'login' => \&CMU::WebInt::machines::mach_list,
	    'mach_reg' => \&CMU::WebInt::machines::mach_reg_s0,
	    'mach_reg_s1' => \&CMU::WebInt::machines::mach_reg_s1,
	    'mach_reg_s2' => \&CMU::WebInt::machines::mach_reg_s2,
	    'mach_reg_s3' => \&CMU::WebInt::machines::mach_reg_s3,
	    'mach_list' => \&CMU::WebInt::machines::mach_list,
 	    'mach_conf_view' => \&CMU::WebInt::machines::mach_conf_view,
 	    'mach_dhcpconf_view' => \&CMU::WebInt::machines::mach_dhcpconf_view,
	    'mach_view' => \&CMU::WebInt::machines::mach_view,
	    'mach_expire_list' => \&CMU::WebInt::machines::mach_expire_list,
	    'mach_del' => \&CMU::WebInt::machines::mach_delete,
	    'mach_del_conf' => \&CMU::WebInt::machines::mach_confirm_delete,
	    'mach_upd_sub' => \&CMU::WebInt::machines::mach_update_subnet,
	    'mach_upd' => \&CMU::WebInt::machines::mach_update,
	    'mach_search' => \&CMU::WebInt::machines::mach_search,
	    'mach_s_exec' => \&CMU::WebInt::machines::mach_s_exec,
	    'mach_dns_res_add' => \&CMU::WebInt::mach_dns::mach_dns_add_res_form,
	    'mach_dns_ares_conf' => \&CMU::WebInt::mach_dns::mach_dns_add_res,
	    'mach_dhcp_add' => \&CMU::WebInt::mach_dns::mach_dhcp_add_opt_form,
	    'mach_dhcp_addc' => \&CMU::WebInt::mach_dns::mach_dhcp_add_opt,
	    'mach_dhcp_opt_del' => \&CMU::WebInt::mach_dns::mach_dhcp_opt_del,
	    'mach_dns_res_del' => \&CMU::WebInt::mach_dns::mach_dns_res_del,
	    'mach_dns_gdhcp_list' => \&CMU::WebInt::mach_dns::mach_dns_gdhcp_list,
	    'mach_unexpire' => \&CMU::WebInt::machines::mach_unexpire,
	    'mach_expire' => \&CMU::WebInt::machines::mach_expire,
	    'quickreg_continue' => \&CMU::WebInt::quickreg::qreg_reg_setup,
	    'quickreg_simple' => \&CMU::WebInt::quickreg::qreg_reg_simple,
 	    'quickreg_fake' => \&CMU::WebInt::quickreg::qreg_prereg_text,
	    'device_add_pres' => \&CMU::WebInt::machines::device_add_presence,
	    'device_del_pres' => \&CMU::WebInt::machines::device_del_presence,
            'mach_history_search' => \&CMU::WebInt::machines::mach_history_search,
	    'mach_find_lease' => \&CMU::WebInt::machines::mach_find_lease,
 	    'mach_find_lease_exec' => \&CMU::WebInt::machines::mach_find_lease_exec,

	    # Networks
	    'net_list' => \&CMU::WebInt::networks::net_list,
	    'net_view' => \&CMU::WebInt::networks::net_view,
	    'net_add_form' => \&CMU::WebInt::networks::net_add_form,
	    'net_add' => \&CMU::WebInt::networks::net_add,
	    'net_update' => \&CMU::WebInt::networks::net_upd,
	    'net_upd_conf' =>\ &CMU::WebInt::networks::net_upd_conf,
	    'net_del' => \&CMU::WebInt::networks::net_del,
	    'net_del_conf' => \&CMU::WebInt::networks::net_del_conf,
	    
	    # Outlet activations
	    'oact_list' => \&CMU::WebInt::outlet_act::oact_list_0,
	    'oact_list_1' => \&CMU::WebInt::outlet_act::oact_list_1,
	    'oact_update' => \&CMU::WebInt::outlet_act::oact_update,

	    'oact_telco_0' => \&CMU::WebInt::outlet_act::oact_telco_0,
	    'oact_telco_1' => \&CMU::WebInt::outlet_act::oact_telco_1,
	    'oact_telco_add_closet_2' => \&CMU::WebInt::outlet_act::oact_telco_add_closet_2,
	    'oact_telco_add_closet_3' => \&CMU::WebInt::outlet_act::oact_telco_add_closet_3,
	    'oact_telco_mod_closet_2' => \&CMU::WebInt::outlet_act::oact_telco_mod_closet_2,
	    'oact_telco_mod_closet_3' => \&CMU::WebInt::outlet_act::oact_telco_mod_closet_3,
	    'oact_telco_mod_closet_4' => \&CMU::WebInt::outlet_act::oact_telco_mod_closet_4,

	    'oact_aq_list' => \&CMU::WebInt::outlet_act::oact_aq_list,
	    'oact_aq_view' => \&CMU::WebInt::outlet_act::oact_aq_view,
	    'oact_aq_update' => \&CMU::WebInt::outlet_act::oact_aq_update,
	    'oact_aq_delete' => \&CMU::WebInt::outlet_act::oact_aq_delete,
	    'oact_aq_delete_conf' => \&CMU::WebInt::outlet_act::oact_aq_delete_conf,
	    'oact_aq_add_form' => \&CMU::WebInt::outlet_act::oact_aq_add_form,
	    'oact_aq_add' => \&CMU::WebInt::outlet_act::oact_aq_add,
	    'oact_aq_add_build' => \&CMU::WebInt::outlet_act::oact_aq_add_build,
	    'oact_aq_del_build' => \&CMU::WebInt::outlet_act::oact_aq_del_build,
	    
            # Services
            'svc_main' => \&CMU::WebInt::services::svc_main,
            'svc_add_form' => \&CMU::WebInt::services::svc_add_form,
            'svc_add' => \&CMU::WebInt::services::svc_add,
            'svc_type_list' => \&CMU::WebInt::services::svc_type_list,
            'svc_type_add_form' => \&CMU::WebInt::services::svc_type_add_form,
            'svc_type_add' => \&CMU::WebInt::services::svc_type_add,
            'svc_type_del' => \&CMU::WebInt::services::svc_type_del,
            'svc_type_del_conf' => \&CMU::WebInt::services::svc_type_confirm_del,
            'svc_type_info' => \&CMU::WebInt::services::svc_type_view,
            'svc_info' => \&CMU::WebInt::services::svc_view,
            'svc_del_member' =>\&CMU::WebInt::services::svc_del_member,
            'svc_add_member' =>\&CMU::WebInt::services::svc_add_member,
            'svc_update' =>\&CMU::WebInt::services::svc_update,
            'svc_delete' => \&CMU::WebInt::services::svc_delete,
            'svc_del_conf' => \&CMU::WebInt::services::svc_delete_conf,
            'attr_add' => \&CMU::WebInt::services::attr_add,
            'attr_del' => \&CMU::WebInt::services::attr_del,
            'attr_add_form' => \&CMU::WebInt::services::attr_add_form,
            'attr_spec_add' => \&CMU::WebInt::services::attr_spec_add,
            'attr_spec_view' => \&CMU::WebInt::services::attr_spec_view,
            'attr_spec_upd' => \&CMU::WebInt::services::attr_spec_upd,
            'attr_spec_del' => \&CMU::WebInt::services::attr_spec_del,
	    'attr_spec_list' => \&CMU::WebInt::services::attr_spec_list,
	    'attr_spec_add_form_full' => \&CMU::WebInt::services::attr_spec_add_form_full,

	    # Scheduler
	    'sch_add' => \&CMU::WebInt::scheduled::sch_add,
	    'sch_add_form' => \&CMU::WebInt::scheduled::sch_add_form,
	    'sch_force' => \&CMU::WebInt::scheduled::sch_force,
	    'sch_main' => \&CMU::WebInt::scheduled::sch_main,
	    'sch_upd' => \&CMU::WebInt::scheduled::sch_upd,

	    # Trunk-Set
	    'trunkset_mgmt' 	=> \&CMU::WebInt::trunkset::trunkset_mgmt,
	    'trunkset_view' 	=> \&CMU::WebInt::trunkset::trunkset_view,
	    'trunkset_add'  	=> \&CMU::WebInt::trunkset::trunkset_add,
	    'trunkset_del'  	=> \&CMU::WebInt::trunkset::trunkset_del,
	    'trunkset_del_conf' => \&CMU::WebInt::trunkset::trunkset_del_confirm,
	    'trunkset_update'   => \&CMU::WebInt::trunkset::trunkset_update,
	    'trunkset_main' 	=> \&CMU::WebInt::trunkset::trunkset_main,
	    'trunkset_info' 	=> \&CMU::WebInt::trunkset::trunkset_view,
	    'trunkset_add_membership' => \&CMU::WebInt::trunkset::trunkset_add_membership,
	    'ts_add_member' 	=> \&CMU::WebInt::trunkset::trunkset_add_membership,
	    'ts_del_member' 	=> \&CMU::WebInt::trunkset::trunkset_del_membership,
	    'ts_del_member1' 	=> \&CMU::WebInt::trunkset::trunkset_del_membership1,
	    'ts_add_member1' 	=> \&CMU::WebInt::trunkset::trunkset_add_membership1,
	    
	    # Telecom
	    'telecom_main' => \&CMU::WebInt::outlet_act::oact_telco_0,

	    # Outlets
	    'outlets_reg_s0' => \&CMU::WebInt::outlets::outlets_reg_s0,
	    'outlets_reg_s1' => \&CMU::WebInt::outlets::outlets_reg_s1,
	    'outlets_reg_s2' => \&CMU::WebInt::outlets::outlets_reg_s2,
	    
	    'outlets_reg' => \&CMU::WebInt::outlets::outlets_register,
	    'outlets_info' => \&CMU::WebInt::outlets::outlets_info,
	    'outlets_add_subnet_membership' => \&CMU::WebInt::outlets::outlets_add_subnet_membership,
	    'outlets_del_subnet_membership' => \&CMU::WebInt::outlets::outlets_del_subnet_membership,
	    'outlets_update' => \&CMU::WebInt::outlets::outlets_update,
	    'outlets_search' => \&CMU::WebInt::outlets::outlet_search,
	    'outlets_s_exec' => \&CMU::WebInt::outlets::outlet_s_exec,
	    'outlets_expire_list' => \&CMU::WebInt::outlets::outlets_expire_list,
	    'outlets_unexpire' => \&CMU::WebInt::outlets::outlets_unexpire,

#	    'outlets_deact' => \&CMU::WebInt::outlets::outlets_deact,
	    'outlets_delete' => \&CMU::WebInt::outlets::outlets_delete,
	    'outlets_confirm_delete' => \&CMU::WebInt::outlets::outlets_confirm_delete,
	    'outlets_add_vlan_membership' => \&CMU::WebInt::outlets::outlets_add_vlan_membership,
	    'outlets_del_vlan_membership' => \&CMU::WebInt::outlets::outlets_del_vlan_membership,
	    'outlets_force_vlan_membership' => \&CMU::WebInt::outlets::outlets_force_vlan_membership,
	    
	    'outlet_t_list' => \&CMU::WebInt::outlet_type::outlet_t_list,
	    'outlet_t_view' => \&CMU::WebInt::outlet_type::outlet_t_view,
	    'outlet_t_update' => \&CMU::WebInt::outlet_type::outlet_t_update,
	    'outlet_t_delete' => \&CMU::WebInt::outlet_type::outlet_t_delete,
	    'outlet_t_confirm' => \&CMU::WebInt::outlet_type::outlet_t_confirm,
	    'outlet_t_add' => \&CMU::WebInt::outlet_type::outlet_t_add,
	    'outlet_t_add_form'  => \&CMU::WebInt::outlet_type::outlet_t_add_form,
	    
	    # Protections
	    'prot_s2' => \&CMU::WebInt::protections::prot_s2,
	    'prot_s3' => \&CMU::WebInt::protections::prot_s3,
	    'prot_s4' => \&CMU::WebInt::protections::prot_s4,
	    'protAdd' => \&CMU::WebInt::protections::prot_add,
	    'delProt' => \&CMU::WebInt::protections::prot_del,
	    'prot_main' => \&CMU::WebInt::protections::prot_s1,

	    'prot_deptadmin' => \&CMU::WebInt::protections::prot_deptadmin,
	    'prot_radd_list' => \&CMU::WebInt::protections::prot_radd_list,
	    'prot_radd_del' => \&CMU::WebInt::protections::prot_radd_del,
	    'prot_radd_add' => \&CMU::WebInt::protections::prot_radd_add,

	    # Reports
	    'rep_sub_util' => \&CMU::WebInt::reports::rep_subnet_util,
	    'rep_outlet_util' => \&CMU::WebInt::reports::rep_outlet_util,
	    'rep_main' => \&CMU::WebInt::reports::rep_main,
	    'rep_cname_util' => \&CMU::WebInt::reports::rep_cname_util,
	    'rep_user_mach' => \&CMU::WebInt::reports::rep_user_mach,
	    'rep_dept_mach' => \&CMU::WebInt::reports::rep_dept_mach,
	    'rep_orphan_mach' => \&CMU::WebInt::reports::rep_orphan_mach,
	    'rep_expired_mach' => \&CMU::WebInt::reports::rep_expired_mach,
	    'rep_expired_outlet' => \&CMU::WebInt::reports::rep_expired_outlet,
	    'rep_printlabels' => \&CMU::WebInt::reports::rep_printlabels,
	    'rep_printlabels_confirm' => \&CMU::WebInt::reports::rep_printlabels_confirm,
	    'rep_genlabel_ps' => \&CMU::WebInt::reports::rep_genlabel_ps,
	    'rep_telecomdump' => \&CMU::WebInt::reports::rep_telecomdump,
	    'rep_telecomdump_s2' => \&CMU::WebInt::reports::rep_telecomdump_s2,
	    'rep_zone_config' => \&CMU::WebInt::reports::rep_zone_config,
	    'rep_abuse_suspend' => \&CMU::WebInt::reports::rep_abuse_suspend,
	    'rep_subnet_map' => \&CMU::WebInt::reports::rep_subnet_map,
	    'rep_panels' => \&CMU::WebInt::reports::rep_panels,
	    'rep_subnet_zone_map' => \&CMU::WebInt::reports::rep_subnet_zone_map,
	    'rep_zone_util' => \&CMU::WebInt::reports::rep_zone_util,
	    'sw_panel_config' => \&CMU::WebInt::switch_panel_config::switch_panel_main,
	    'history' => \&CMU::WebInt::reports::History,

	    # Vlans
		'vlan_main' => \&CMU::WebInt::vlans::vlans_main,
		'vlan_add_form' => \&CMU::WebInt::vlans::vlan_add_form,
		'vlan_add' => \&CMU::WebInt::vlans::vlan_add,
		'vlan_delete' => \&CMU::WebInt::vlans::vlans_delete,
		'vlan_del_conf' => \&CMU::WebInt::vlans::vlans_deleteConfirm,
		'vlan_info' => \&CMU::WebInt::vlans::vlans_view,
		'vlan_update' => \&CMU::WebInt::vlans::vlans_update,
	    'vlan_add_pres' => \&CMU::WebInt::vlans::vlans_add_presence,
	    'vlan_del_pres' => \&CMU::WebInt::vlans::vlans_del_presence,
						
	    # Zones
	    'zone_list_old' => \&CMU::WebInt::zones::zone_list_old,
	    'zone_list' => \&CMU::WebInt::zones::zone_list,
	    'zone_info' => \&CMU::WebInt::zones::zone_view,
	    'zone_search' => \&CMU::WebInt::zones::zone_search,
	    'zone_s_exec' => \&CMU::WebInt::zones::zone_s_exec,
	    'zone_add' => \&CMU::WebInt::zones::zone_add,
	    'zone_add_form' => \&CMU::WebInt::zones::zone_add_form,
	    'zone_del' => \&CMU::WebInt::zones::zone_delete,
	    'zone_del_conf' => \&CMU::WebInt::zones::zone_confirm_del,
	    'zone_update' => \&CMU::WebInt::zones::zone_update,
	    'zone_ddns_manual' => \&CMU::WebInt::zones::zone_ddns_manual,	
	    'zone_bulk_rv' => \&CMU::WebInt::zones::zone_bulk_rv
	
	   );

%htext = 
  ('machine.host_name' => 'The fully-qualified hostname for this machine is a combination of the short name, which you can enter in the box below, and the domain name, which you can select from the drop-down list. For example, if you choose a short name of \'mymachine\' and a domain name of \'res.cmu.edu\', your fully-qualified hostname will be \'mymachine.res.cmu.edu\'. If you leave the short name field blank, a name will be automatically assigned. (You must still select an appropriate domain name.)',
   'machine.mac_address' => 'Your hardware address identifies the network card in your machine. For hints about how to find this address on your machine,
<a target=_blank href=/help/topics/hardwareaddress.shtml>click here</a>.',
   'machine.mode' => 'Some areas do not allow the registration of static addresses, while some areas do not allow dynamic registration. If an option is provided, choose the "dynamic" mode unless you have a need for a static address. Dynamic DNS will update your hostname to the assigned IP address if you have a dynamic address.',
   'machine.mode_l9' => 'Static machines associate a fully qualified hostname,
IP address, and MAC address. Dynamic machines need only a MAC Address and hostname will
receive a dynamic IP address on the subnet. A mode of broadcast is used to register
broadcast addresses (MAC address does not matter). Base is similar to broadcast
but used for the subnet base address. Reserved will reserve a hostname, IP
address, with or without a MAC address. Pool means the address is part of a 
dynamic IP pool.',
   'machine.department' => 'Most undergraduate students should select \'Undergraduate Students\' as their affiliation. Other students, faculty, and staff should select the department this machine is being registered in.',
   'machine.ip_address_l9' => 'You may leave this field blank and an IP address will be automatically assigned for this host. If you enter the IP address, it must be valid on the selected subnet.',
   'machine.ip_address' => 'You may leave this field blank and an IP address will be automatically assigned for this host.',
   'machine.host_name_ttl' => 'The hostname TTL specifies the value propagated to DNS as the time-to-live for this host, which specifies the length of time
machines will cache this lookup. Setting it to \'0\' will cause the host to
inherit the default value - the recommended setting.',
   'machine.ip_address_ttl' => 'The IP address TTL specifies the value propagated to DNS as the time-to-live for this IP address, which specifies the length of time machines will cache this lookup. Setting it to \'0\' will cause the IP address to inherit the default value - the recommended setting.',
   'machine.expires' => 'This machine is scheduled to expire on the specified date. To prevent this machine from expiring, select \'Retain\'.',
   'machine.reg0_select' => 'Please select the location for this machine. You may select by
network, building, or subnet. Subnets are collections of common machines
and typically are constrained to a single building or department. Networks are
popular subnets that do not belong to an individual buildings. If you select
the building that this machine will be used in, you will next be presented with
a list of subnets in the building (assuming that more than one exists for the
building.) If you know the subnet already, you can select the subnet and proceed
directly to the registration page.',
   'machine.view_general' => 'To change any of the information below, make your changes and then click \'Update\'.',
   'machine.flags' => 'Setting the Abuse or Suspend flags will prevent any changes from being made to this registration except by netreg:admins. Setting Suspend will cause the machine to be dropped from DNS/DHCP propagation. Setting Stolen will cause any attempt to register this MAC Address to be reported.',
   'machine.flags_l5' => 'If the Abuse flag is set, this machine has been tagged
for abuse. If the Suspend flag is set, the machine is not propogating to DNS
and DHCP.',
   'machine.comment_lvl1' => 'The comment field can be seen anyone who can see this record, and is for personal record keeping only.',
   'machine.comment_lvl5' => 'The departmental comment field can be seen by anyone with departmental access to this record.',
   'machine.comment_lvl9' => 'The administrative comment field is only seen by network administrators.',
   'machine.ip_address_subnet' => 'This defines the location for the machine. Changing the subnet may requiring changing your hostname and will cause your IP address to change.',
   'machine.search_general' => "<ul><li>Enter your search parameters.
<li>Fields left blank are ignored.
<li>Results only include hosts that you have read permission to.
<li>For text searches, your input will match any 
part of the specified field unless you include % operators to indicate wildcard areas.</ul>",

   'mach_view.dns_resources' => 'Typical machines do not need additional DNS
resources to functional properly, however there may be instances in which a 
resource is necessary. ',

   'mach_view.dhcp_options' => 'This area allows you to configure certain options that will be returned
to this machine by the DHCP server. One common option is the \'next-server\' (for TFTP booting). Note that
this machine most likely inherits global and subnet-specifics options, and may inherit options from class
matching.',

    'mach_view.trunk_set' => 'This machine\'s membership in various Trunk Sets is listed here.',

   'service.dhcp_options' => 'This area lists DHCP options used as part of
this service group. The DHCP configuration generation must know how to 
intrepret options based on the service group type.',

   'mach_view.service_groups' => 'This machine\'s membership in various service groups is listed here.',
   'subnet_view.service_groups' => 'This subnet\'s membership in various service groups is listed here.',

   'prot_s3.general' => 'This page shows the protections for the selected 
resource (machine or outlet, most likely). For machine and outlets, a user
or group having READ permission is able to view the resource, while only 
users or groups having WRITE permission may update the resource. The ADD
permission type is not relevant for machines and outlets. Only departmental
administrators (members of the dept: groups) may update the protections for
a machine or outlet.',

   'building.name' => 'A general name for the building.',
   'building.abbreviation' => 'A short abbrevation for this building (8 char).',
   'building.number' => 'The eight-character designation for this building.',

   'dhcp_option.type' => 'The dhcp option type.',
   'dhcp_option.value' => 'The value of this option type.',

   'dhcp_option_type.name' => 'Provides a unique name for this option. Sub-option spaces are separated by
a period.',
   'dhcp_option_type.number' => 'Specifies the DHCP option type number (or code).',
   'dhcp_option_type.format' => 'The DHCP Option Type format provides the means for strict verification of
option values. See the administration manual for a complete description of format parameters.',
   'dhcp_option_type.builtin' => 'Builtin options are those that are recognized by the ISC DHCP server. Non-builtin options will have formatting information
generated in the configuration file.',

   'dns_resource_type.name' => 'The name of this DNS resource type.',
   'dns_resource_type.format' => 'The format of this DNS resource type.',

   'network.name' => 'The name of this network.',
   'network.subnet' => 'The subnet that this network corresponds to.',

   'subnet.name' => 'The name of this subnet, as displayed to users.',
   'subnet.abbreviation' => "A short abbreviation for this subnet.",
   'subnet.base_address' => "This subnet's base address (or 'network number').",
   'subnet.network_mask' => 'This subnet\'s netmask (or \'prefix length\'). It controls how many addresses the subnet contains.',
   'subnet.vlan' => 'This subnet\'s vlan number, as configured on network devices on this subnet.',
   'subnet.expire_static' => 'The length (in seconds) of DHCP leases issued to statically registered machines on this subnet.',
   'subnet.expire_dynamic' => 'The length (in seconds) of DHCP leases issued to dynamically registered machines on this subnet.',
   'subnet.default_mode' => 'The mode presented by default for new registrations on this subnet.',

   'subnet.dynamic' => 'Whether or not dynamic DHCP is available on this subnet.  If set to "restrict", only registered machines may get a dynamic address.  If set to "allow" unregistered machines are allowed.',
   'subnet.share' => 'If this subnet is on a shared wire, indicate the wire here.',
   'subnet.flags' => 'If the no_dhcp flag is set, this subnet will not be integrated into the DHCP configuration and no machines registered on this subnet will be able to use DHCP.  If the no_static flag is set, new static registrations will not be permitted on this subnet.',

   'subnet_share.name' => 'A general name for the subnet share.',
   'subnet_share.abbreviation' => 'A short abbrevation for this subnet share (8 char).',

   'subnet.purge_interval' => 'The number of days between automated subnet purge operations. A value of "0" indicates no automated purge should be done.',
   'subnet.purge_notupd' => 'The number of days a machine must not have been updated in NetReg for it to be purged.',
   'subnet.purge_notseen' => 'The number of days a machine must be absent from the network for it to be purged.',
   'subnet.purge_explen' => 'Candidate machines for purging will be set to expire this many days after the purge operation.',
   'subnet.hostname_format' => 'Specifies the format of hostnames for the registered addresses. The string \'%ip\' is replaced by the IP address at the time of registration. Ex: <tt>dyn-%ip.net.cmu.edu</tt>',
   'subnet.number_ips' => 'The number of IPs to allocate.',
   'subnet.mode' => 'Specify the mode for the registrations. Pool mode is used for DHCP dynamic IP assignment.',
   'subnet.alloc_method' => 'The allocation method specifies the strategy for allocating IPs from the pool of unregistered IP addresses.',

   'dns_zone.name' => 'The full name of this zone.',
   'dns_zone.type' => 'Specifies the type of zone. If this is a forward zone, the type should begin \'fw-\'. Reverse zones should begin with \'rv-\'. If a zonefile should be generated for this zone, a \'toplevel\' zone should be selected. Zones for which we must include delegation information should be \'delegated\'. Otherwise, select \'permissible\'.',
   'dns_zone.soa_host' => 'Specifies the hostname of the master server for this zone. WILL BE OVERWRITTEN by the DNS configuration information below.',
   'dns_zone.soa_email' => 'The email of a designated contact for this record, with the at-sign transposed for a dot.',
   'dns_zone.soa_serial' => 'The current serial number of this zone. Secondary servers check for updates by later serials.',
   'dns_zone.soa_refresh' => 'Refresh is the number of seconds nameservers will cache SOA information. Thus secondary nameservers will, on average, notice zone changes after this period of time. Good value: 900',
   'dns_zone.soa_retry' => 'If a nameserver is unreachable, hosts will attempt to re-connect after this number of seconds. Good value: 450',
   'dns_zone.soa_expire' => 'Secondary nameservers will consider zone data valid up to this number of seconds after losing contact with primary nameservers. Good value: 3600000',
   'dns_zone.soa_minimum' => 'The default time to live for all records in this zone is specified, in seconds, by the minimum setting. Good value: 86400',
   'dns_zone.soa_default' => 'The default setting is a mirror of the soa_minimum. Good value: 86400',
   'dns_zone.ddns_auth' => 'Specifies the DDNS Authorization information. If blank, the zone will be assumed NOT-DDNS. Can contain \'key:XXX\', where XXX is a TSIG key, and/or IP:128.2.4.21,128.2.64.2 (a list of IP addresses that can update this zone, or a range in the form 128.2.0.0/16.)',

   'credentials.authid' => 'Specifies the Unix login name/userid of this user.',
   'credentials.description' => 'Generally, the real (full) name of the user is stored here.',
   'users.comment' => 'The comment field is visible to administrators only.',
   'users.flags' => 'Setting the abuse or suspend flag will disable NetReg logins from this user.',

   'groups.name' => 'The short version of the group (prefix:name)',
   'groups.description' => 'A description of this group',
   'groups.comment_lvl9' => 'The administrative comment is only seen by network administrators',
   'groups.comment_lvl5' => 'The group comment is seen by members of the group',
   'groups.flags' => 'Flags for this group (currently only advisory)',

   'outlet.type' => 'The type specifies the capabilities of the physical port of the network device this outlet is connected to.',
   'outlet.deviceport' => 'The network equipment this outlet is connected to',
   'outlet.device' => 'The network device this outlet is connected to',
   'outlet.port' => 'The port on the network device that this outlet is connected to',
   'outlet.attributes' => 'The attributes specify if this outlet is currently waiting to be activated or deactivated. When connected, no attributes are set.',
   'outlet.flags' => 'The flags specify if this outlet is currently activated and/or if the outlet is permanently pre-connected',
   'outlet.comment_lvl1' => 'The comment field can be seen by anyone who can see this record, and is for personal record keeping only.',
   'outlet.comment_lvl5' => 'The departmental comment field can be seen by anyone with departmental access to this record.',
   'outlet.comment_lvl9' => 'The administrative comment is only seen by NetReg administrators.',
   'outlet.comment' => 'The administrative comment is only seen by NetReg administrators.',
   'outlet.reg0_select' => '<center><table border=1 bgcolor=black><tr><td bgcolor=#ff9900>Activation of a new outlet in an academic or administrative building on campus requires that you register the outlet through NetReg and that you or your department pay an activation fee to cover the cost of network switches and other infrastructure. The current activation fee schedule is available at the Carnegie Mellon Computer Store; payments for outlet activations should be made at the store.<p>Note that the outlets in all residence hall rooms are pre-activated; students DO NOT need to request outlet activation.</td></tr></table></center><p>Please select the building in which you are activating an outlet, or enter all/part of either the "From" or "To" addresses of the outlet, if you know this information.<br>',

   'outlet.summary' => 'Outlets must be both enabled and activated. Activation refers to the process of physically connecting the outlet to a network device, after which the port must be enabled on the network device (hub or switch). Some outlets are pre-activated (all residence halls), so the outlet merely needs to be enabled, a process which is done automatically several times daily.',
   'outlet.subnet' => 'Select the primary network segment you want this outlet connected to.  Typically this should be the subnet on which the machines that are connected to this outlet are registered.  More complex operations (for experts only) are available by selecting "Advanced Options". (Only available after initial outlet activation is complete.)',
   'outlet.vlan' => 'Select the primary vlan you want this outlet connected to. Typically this should be the vlan or vlans in subnet in related building.',
   'outlet.port_speed' => 'Select the speed at which this port should operate.  Setting the speed to anything other than \'Auto Negotiate\' should <b>only</b> be done when auto negotiation of port speed is not working, or your network interface doesn\'t support speed negotiation.',
   'outlet.port_duplex' => 'Select the duplex mode which this port should use.  Setting the duplex mode to anything other than \'Auto Negotiate\' should <b>only</b> be done when auto negotation is not working.  Note that setting the duplex has no effect unless you also set the speed.',
   'outlet.expires' => 'This outlet is scheduled to expire on the specified date. To prevent this outlet from expiring, select \'Retain\'.',

   'machines.reg_s0' => 'Please select the subnet within this building to register a machine on. The subnet dictates what IP address you will receive, as well as the possible domain names. Note that registering a machine on a particular subnet does not mean it will work on any outlet in the building.',

   'oact_telco_0.select' => 'Select the building and whether you will be adding or modifying a closet.',

   'cable.from_closet' => 'FIXME',
   'cable.from_floor' => 'FIXME',
   'cable.from_wing' => 'FIXME',
   'cable.type' => 'FIXME',
   'cable.rack' => 'FIXME',

   'activation_queue.name' => 'Specify a human-readable name for this queue.',
   'mach_reg_s2.protections' => 'If you are an administrator for the selected department (above), you may assign different protections from the default (granting only yourself access). Additional protections can be established after the machine is registered.',
   
   'service.name' => 'The name of a service should follow hostname conventions, although it does not need to <b>be</b> a valid hostname. This uniquely identifies the service.',
   
   'service.description' => 'A free-form description of this service.',
   
   'service_type.name' => 'This specifies the name of this service type. Each service inherits the attributes and properties of a single service type.',
   
   'attribute_spec.scope' => 'Defines the scope of this attribute. Set \'service_membership\' if this attribute should be available for every member in a service. Otherwise, set \'service\' for attributes applicable to the entire service. \'Users\' or \'Groups\' can also be set, making this attribute apply to users or groups.',
  
   'attribute_spec.name' => 'The name of this attribute.',

   'attribute_spec.description' => 'A free-form description of this attribute.',

   'attribute_spec.format' => 'Attributes can be constrained to a given format. Valid formats are: \'ustring\' for a string of unlimited length, \'stringNNN\' for a string of length NNN (NNN can be 1-255), \'int\' for a general integer, and \'uint\' for an unsigned integer. There are also \'enum()\' and \'set()\' types. Acceptable values are separated by spaces and enclosed by the parentheses. Values may contain letters, numbers, underscore, dash, and dot. Enum will restrict the attribute to one value, while set allows one or more values to be present.',
   'attribute_spec.ntimes' => 'Set the maximum number of times the attribute can appear per machine or service (based on scope).',
   'attribute.spec' => 'Select the attribute that you wish to add to this service or machine in this service.',
   'attribute.data' => 'Enter the attribute data in the required format. If the data is misformatted, the format will be available on the next screen.',

   'scheduler_notes' => 'The system checks once per minute for tasks that need to be run. '.
   'From the next run time, assume that DNS changes will take less than 10 minutes to propogate, while DHCP may '.
   'take up to 30 minutes to be available.',

   'vlan.name' => 'The name of this VLAN, as displayed to users.',
   'vlan.abbreviation' => "A short abbreviation for this VLAN.",
   'vlan.number' => 'The number of this VLAN, as configured on switches.',
   'vlan.description' => 'A short description for this VLAN.',

   'trunk_set.name' => 'The name of this Trunk Set, as displayed to users. ',
   'trunk_set.abbreviation' => 'A short abbreviation for this Trunk Set.',
   'trunk_set.description' => 'A short description for this Trunk Set.',

# Text to send users of the quickreg system (explaining what's happening, etc.)
   'quickreg.user_text' => 'The Network Registration system has detected that your machine
is not registered on the network it is currently connected. By clicking "Continue" below, 
you will be presented with a nearly complete registration form. You must select a domain name,
and optionally enter a hostname. Then click the "Continue" button on the bottom of the 
registration form, and your registration will be complete.<br><br>Once complete, please wait
30 minutes and then release/renew your IP address, or reboot your machine. 
 You should then have full access to the 
 internal network and the Internet.<br><br>We will be registering your machine on the
"%subnet_name%" subnet. We\'ve detected your MAC address to be: %mac%. %foobar%',

   'register_ips.dept' => 'Each pool address must have an associated department. Please select
the appropriate department from the list below.',

   'register_ips.user' => 'Each pool address should have an associated user
(the system will require a user unless you are a member of the department
specified here). Enter the username of the user that will own these pool
addresses. (For example: "dc0m").',

   'zone_rv_mgmt.txt1' => 'Enter the range of subnets to create reverse zones for, in CIDR notation (ex: 128.2.0.0/20). You will be able to specify protections for these zones on the next screen.' ,
   'zone_rv_mgmt.txt2' => 'Enter the protections for the zones. If you wish to clear any existing protections (on zones that exist), check the "Clear Existing Protections" checkbox. The default protection profile for DNS zones will additionally be added to the protections (typically gives netreg:admins full access).'
   
  
  );

my %glossary = 
  ('hardware address' => 'Thing in your computer.',
   'ip address' => 'Internet Protocol Address',
   'subnet' => 'a sub-part of a net',
   'network' => 'a special network',
   'building' => 'a physical structure');


   
	     
