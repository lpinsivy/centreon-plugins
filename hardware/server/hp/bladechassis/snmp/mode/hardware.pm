################################################################################
# Copyright 2005-2013 MERETHIS
# Centreon is developped by : Julien Mathis and Romain Le Merlus under
# GPL Licence 2.0.
# 
# This program is free software; you can redistribute it and/or modify it under 
# the terms of the GNU General Public License as published by the Free Software 
# Foundation ; either version 2 of the License.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with 
# this program; if not, see <http://www.gnu.org/licenses>.
# 
# Linking this program statically or dynamically with other modules is making a 
# combined work based on this program. Thus, the terms and conditions of the GNU 
# General Public License cover the whole combination.
# 
# As a special exception, the copyright holders of this program give MERETHIS 
# permission to link this program with independent modules to produce an executable, 
# regardless of the license terms of these independent modules, and to copy and 
# distribute the resulting executable under terms of MERETHIS choice, provided that 
# MERETHIS also meet, for each linked independent module, the terms  and conditions 
# of the license of that module. An independent module is a module which is not 
# derived from this program. If you modify this program, you may extend this 
# exception to your version of the program, but you are not obliged to do so. If you
# do not wish to do so, delete this exception statement from your version.
# 
# For more information : contact@centreon.com
# Authors : Quentin Garnier <qgarnier@merethis.com>
#
####################################################################################

package hardware::server::hp::bladechassis::snmp::mode::hardware;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use hardware::server::hp::bladechassis::snmp::mode::components::enclosure;
use hardware::server::hp::bladechassis::snmp::mode::components::manager;
use hardware::server::hp::bladechassis::snmp::mode::components::fan;
use hardware::server::hp::bladechassis::snmp::mode::components::blade;
use hardware::server::hp::bladechassis::snmp::mode::components::network;
use hardware::server::hp::bladechassis::snmp::mode::components::psu;
use hardware::server::hp::bladechassis::snmp::mode::components::temperature;
use hardware::server::hp::bladechassis::snmp::mode::components::fuse;

my $thresholds = {
    temperature => [
        ['other', 'CRITICAL'], 
        ['ok', 'OK'], 
        ['degraded', 'WARNING'], 
        ['failed', 'CRITICAL'],
    ],
    blade => [
        ['other', 'CRITICAL'], 
        ['ok', 'OK'], 
        ['degraded', 'WARNING'], 
        ['failed', 'CRITICAL'],
    ],
    enclosure => [
        ['other', 'CRITICAL'], 
        ['ok', 'OK'], 
        ['degraded', 'WARNING'], 
        ['failed', 'CRITICAL'],
    ],
    fan => [
        ['other', 'CRITICAL'], 
        ['ok', 'OK'], 
        ['degraded', 'WARNING'], 
        ['failed', 'CRITICAL'],
    ],
    fuse => [
        ['other', 'CRITICAL'], 
        ['ok', 'OK'], 
        ['degraded', 'WARNING'], 
        ['failed', 'CRITICAL'],
    ],
    manager => [
        ['other', 'CRITICAL'], 
        ['ok', 'OK'], 
        ['degraded', 'WARNING'], 
        ['failed', 'CRITICAL'],
    ],
    psu => [
        ['other', 'CRITICAL'], 
        ['ok', 'OK'], 
        ['degraded', 'WARNING'], 
        ['failed', 'CRITICAL'],
    ],
};

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                { 
                                  "exclude:s"               => { name => 'exclude' },
                                  "absent-problem:s"        => { name => 'absent' },
                                  "component:s"             => { name => 'component', default => 'all' },
                                  "no-component:s"          => { name => 'no_component' },
                                  "threshold-overload:s@"   => { name => 'threshold_overload' },
                                });
    $self->{components} = {};
    $self->{no_components} = undef;
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
    
    $self->{overload_th} = {};
    foreach my $val (@{$self->{option_results}->{threshold_overload}}) {
        if ($val !~ /^(.*?),(.*?),(.*)$/) {
            $self->{output}->add_option_msg(short_msg => "Wrong treshold-overload option '" . $val . "'.");
            $self->{output}->option_exit();
        }
        my ($section, $status, $filter) = ($1, $2, $3);
        if ($self->{output}->is_litteral_status(status => $status) == 0) {
            $self->{output}->add_option_msg(short_msg => "Wrong treshold-overload status '" . $val . "'.");
            $self->{output}->option_exit();
        }
        $self->{overload_th}->{$section} = [] if (!defined($self->{overload_th}->{$section}));
        push @{$self->{overload_th}->{$section}}, {filter => $filter, status => $status};
    }
    if (defined($self->{option_results}->{no_component})) {
        if ($self->{option_results}->{no_component} ne '') {
            $self->{no_components} = $self->{option_results}->{no_component};
        } else {
            $self->{no_components} = 'critical';
        }
    }
}

sub global {
    my ($self, %options) = @_;

    hardware::server::hp::bladechassis::snmp::mode::components::enclosure::check($self);
    hardware::server::hp::bladechassis::snmp::mode::components::manager::check($self);
    hardware::server::hp::bladechassis::snmp::mode::components::fan::check($self);
    hardware::server::hp::bladechassis::snmp::mode::components::blade::check($self);
    hardware::server::hp::bladechassis::snmp::mode::components::network::check($self);
    hardware::server::hp::bladechassis::snmp::mode::components::psu::check($self);
    hardware::server::hp::bladechassis::snmp::mode::components::temperature::check($self);
    hardware::server::hp::bladechassis::snmp::mode::components::fuse::check($self);
}

sub run {
    my ($self, %options) = @_;
    # $options{snmp} = snmp object
    $self->{snmp} = $options{snmp};
    
    if ($self->{option_results}->{component} eq 'all') {
        $self->global();
    } elsif ($self->{option_results}->{component} eq 'enclosure') {
        hardware::server::hp::bladechassis::snmp::mode::components::enclosure::check($self);
    } elsif ($self->{option_results}->{component} eq 'manager') {
        hardware::server::hp::bladechassis::snmp::mode::components::manager::check($self, force => 1);
    } elsif ($self->{option_results}->{component} eq 'fan') {
        hardware::server::hp::bladechassis::snmp::mode::components::fan::check($self);
    } elsif ($self->{option_results}->{component} eq 'blade') {
        hardware::server::hp::bladechassis::snmp::mode::components::blade::check($self);
    } elsif ($self->{option_results}->{component} eq 'network') {
        hardware::server::hp::bladechassis::snmp::mode::components::network::check($self);
    } elsif ($self->{option_results}->{component} eq 'psu') {
        hardware::server::hp::bladechassis::snmp::mode::components::psu::check($self);
    } elsif ($self->{option_results}->{component} eq 'temperature') {
        hardware::server::hp::bladechassis::snmp::mode::components::temperature::check($self);
    } elsif ($self->{option_results}->{component} eq 'fuse') {
        hardware::server::hp::bladechassis::snmp::mode::components::fuse::check($self);
    } else {
        $self->{output}->add_option_msg(short_msg => "Wrong option. Cannot find component '" . $self->{option_results}->{component} . "'.");
        $self->{output}->option_exit();
    }
    
    my $total_components = 0;
    my $display_by_component = '';
    my $display_by_component_append = '';
    foreach my $comp (sort(keys %{$self->{components}})) {
        # Skipping short msg when no components
        next if ($self->{components}->{$comp}->{total} == 0 && $self->{components}->{$comp}->{skip} == 0);
        $total_components += $self->{components}->{$comp}->{total} + $self->{components}->{$comp}->{skip};
        $display_by_component .= $display_by_component_append . $self->{components}->{$comp}->{total} . '/' . $self->{components}->{$comp}->{skip} . ' ' . $self->{components}->{$comp}->{name};
        $display_by_component_append = ', ';
    }
    
    $self->{output}->output_add(severity => 'OK',
                                short_msg => sprintf("All %s components [%s] are ok.", 
                                                     $total_components,
                                                     $display_by_component)
                                );

    if (defined($self->{option_results}->{no_component}) && $total_components == 0) {
        $self->{output}->output_add(severity => $self->{no_components},
                                    short_msg => 'No components are checked.');
    }
                           
    $self->{output}->display();
    $self->{output}->exit();
}

sub check_exclude {
    my ($self, %options) = @_;

    if (defined($options{instance})) {
        if (defined($self->{option_results}->{exclude}) && $self->{option_results}->{exclude} =~ /(^|\s|,)${options{section}}[^,]*#\Q$options{instance}\E#/) {
            $self->{components}->{$options{section}}->{skip}++;
            $self->{output}->output_add(long_msg => sprintf("Skipping $options{section} section $options{instance} instance."));
            return 1;
        }
    } elsif (defined($self->{option_results}->{exclude}) && $self->{option_results}->{exclude} =~ /(^|\s|,)$options{section}(\s|,|$)/) {
        $self->{output}->output_add(long_msg => sprintf("Skipping $options{section} section."));
        return 1;
    }
    return 0;
}

sub absent_problem {
    my ($self, %options) = @_;
    
    if (defined($self->{option_results}->{absent}) && 
        $self->{option_results}->{absent} =~ /(^|\s|,)($options{section}(\s*,|$)|${options{section}}[^,]*#\Q$options{instance}\E#)/) {
        $self->{output}->output_add(severity => 'CRITICAL',
                                    short_msg => sprintf("Component '%s' instance '%s' is not present", 
                                                         $options{section}, $options{instance}));
    }

    $self->{output}->output_add(long_msg => sprintf("Skipping $options{section} section $options{instance} instance (not present)"));
    $self->{components}->{$options{section}}->{skip}++;
    return 1;
}

sub get_severity {
    my ($self, %options) = @_;
    my $status = 'UNKNOWN'; # default 
    
    if (defined($self->{overload_th}->{$options{section}})) {
        foreach (@{$self->{overload_th}->{$options{section}}}) {            
            if ($options{value} =~ /$_->{filter}/i) {
                $status = $_->{status};
                return $status;
            }
        }
    }
    foreach (@{$thresholds->{$options{section}}}) {           
        if ($options{value} =~ /$$_[0]/i) {
            $status = $$_[1];
            return $status;
        }
    }
    
    return $status;
}

1;

__END__

=head1 MODE

Check Hardware (Fans, Power Supplies, Blades, Temperatures, Fuses).

=over 8

=item B<--component>

Which component to check (Default: 'all').
Can be: 'enclosure', 'manager', 'fan', 'blade', 'network', 'psu', 'temperature', 'fuse'.

=item B<--exclude>

Exclude some parts (comma seperated list) (Example: --exclude=temperature,psu).
Can also exclude specific instance: --exclude=temperature#1#

=item B<--absent-problem>

Return an error if an entity is not 'present' (default is skipping) (comma seperated list)
Can be specific or global: --absent-problem=blade#12#

=item B<--no-component>

Return an error if no compenents are checked.
If total (with skipped) is 0. (Default: 'critical' returns).

=item B<--threshold-overload>

Set to overload default threshold values (syntax: section,status,regexp)
It used before default thresholds (order stays).
Example: --threshold-overload='temperature,OK,other'

=back

=cut
    