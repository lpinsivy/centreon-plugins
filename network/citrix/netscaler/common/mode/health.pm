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

package network::citrix::netscaler::common::mode::health;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

my $oid_nsSysHealthEntry = '.1.3.6.1.4.1.5951.4.1.1.41.7.1';
my $oid_sysHealthCounterName = '.1.3.6.1.4.1.5951.4.1.1.41.7.1.1';
my $oid_sysHealthCounterValue = '.1.3.6.1.4.1.5951.4.1.1.41.7.1.2';

my $thresholds = {
    psu => [
        ['normal', 'OK'],
        ['not present', 'OK'],
        ['failed', 'CRITICAL'],
        ['not supported', 'UNKNOWN'],
    ],
};

my %map_psu_status = (
    0 => 'normal',
    1 => 'not present',
    2 => 'failed',
    3 => 'not supported',
);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                {
                                  "exclude:s"               => { name => 'exclude' },
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
    
    if (defined($self->{option_results}->{no_component})) {
        if ($self->{option_results}->{no_component} ne '') {
            $self->{no_components} = $self->{option_results}->{no_component};
        } else {
            $self->{no_components} = 'critical';
        }
    }
    
    $self->{overload_th} = {};
    foreach my $val (@{$self->{option_results}->{threshold_overload}}) {
        if ($val !~ /^(.*?),(.*)$/) {
            $self->{output}->add_option_msg(short_msg => "Wrong treshold-overload option '" . $val . "'.");
            $self->{output}->option_exit();
        }
        my ($section, $status, $filter) = ('psu', $1, $2);
        if ($self->{output}->is_litteral_status(status => $status) == 0) {
            $self->{output}->add_option_msg(short_msg => "Wrong treshold-overload status '" . $val . "'.");
            $self->{output}->option_exit();
        }
        $self->{overload_th}->{$section} = [] if (!defined($self->{overload_th}->{$section}));
        push @{$self->{overload_th}->{$section}}, {filter => $filter, status => $status};
    }
}

sub run {
    my ($self, %options) = @_;
    # $options{snmp} = snmp object
    $self->{snmp} = $options{snmp};
    
    $self->{result} = $self->{snmp}->get_table(oid => $oid_nsSysHealthEntry);
        
    if ($self->{option_results}->{component} eq 'all') {    
        $self->check_psu();
        $self->check_fanspeed();
        $self->check_temperature();
        $self->check_voltage();
    } elsif ($self->{option_results}->{component} eq 'psu') {
        $self->check_psu();
    } elsif ($self->{option_results}->{component} eq 'fanspeed') {
        $self->check_fanspeed();
    } elsif ($self->{option_results}->{component} eq 'temperature') {
        $self->check_temperature();
    } elsif ($self->{option_results}->{component} eq 'voltage') {
        $self->check_voltage();
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
        my $count_by_components = $self->{components}->{$comp}->{total} + $self->{components}->{$comp}->{skip}; 
        $display_by_component .= $display_by_component_append . $self->{components}->{$comp}->{total} . '/' . $count_by_components . ' ' . $self->{components}->{$comp}->{name};
        $display_by_component_append = ', ';
    }
    
    $self->{output}->output_add(severity => 'OK',
                                short_msg => sprintf("All %s components are ok [%s].", 
                                                     $total_components,
                                                     $display_by_component,
                                                    )
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


sub absent_problem {
    my ($self, %options) = @_;
    
    if (defined($self->{option_results}->{absent}) && 
        $self->{option_results}->{absent} =~ /(^|\s|,)($options{section}(\s*,|$)|${options{section}}[^,]*#\Q$options{instance}\E#)/) {
        $self->{output}->output_add(severity => 'CRITICAL',
                                    short_msg => sprintf("Component '%s' instance '%s' is not present", 
                                                         $options{section}, $options{instance}));
        return 1;
    }
    
    return 0;
}

sub check_fanspeed {
    my ($self) = @_;
    
    $self->{output}->output_add(long_msg => "Checking fanspeed");
    $self->{components}->{fanspeed} = {name => 'fanspeed', total => 0, skip => 0};
    return if ($self->check_exclude(section => 'fanspeed'));

    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{result}})) {
        next if ($oid !~ /^$oid_sysHealthCounterName\.(.*)$/ || $self->{result}->{$oid} !~ /Speed|Fan/i);
        my $name = $self->{result}->{$oid};
        $oid =~ /^$oid_sysHealthCounterName\.(.*)$/;
        my $value = $self->{result}->{$oid_sysHealthCounterValue . '.' . $1};
        
        if ($value == 0) {
            $self->{output}->output_add(long_msg => sprintf("Skipping Fanspeed '%s' (counter is 0)", 
                                                            $name));
            next;
        }
        
        next if ($self->check_exclude(section => 'fanspeed', instance => $name));
        $self->{components}->{fanspeed}->{total}++;
        $self->{output}->output_add(long_msg => sprintf("Fan '%s' speed is %s (rpm)", 
                                                        $name, $value));
        
        $self->{output}->perfdata_add(label => "speed_" . $name, unit => 'rpm',
                                      value => $value,
                                      min => 0);
    }
}

sub check_psu {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => "Checking power supplies");
    $self->{components}->{psu} = {name => 'psus', total => 0, skip => 0};
    return if ($self->check_exclude(section => 'psu'));

    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{result}})) {
        next if ($oid !~ /^$oid_sysHealthCounterName\.(.*)$/ || $self->{result}->{$oid} !~ /PowerSupply(.)FailureStatus/i);
        my $instance = $1;
        my $name = $self->{result}->{$oid};
        $oid =~ /^$oid_sysHealthCounterName\.(.*)$/;
        my $value = $self->{result}->{$oid_sysHealthCounterValue . '.' . $1};
                
        next if ($map_psu_status{$value} eq 'not present' &&
                 $self->absent_problem(section => 'psu', instance => $instance));
        
        next if ($self->check_exclude(section => 'psu', instance => $instance));
        $self->{components}->{psu}->{total}++;
        
        $self->{output}->output_add(long_msg => sprintf("Power Supply '%s' status is %s",
                                                        $instance, $map_psu_status{$value}));
        my $exit = $self->get_severity(section => 'psu', value => $map_psu_status{$value});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity => $exit,
                                        short_msg => sprintf("Power Supply '%s' status is %s",
                                                             $instance, $map_psu_status{$value}));
        }
    }
}

sub check_voltage {
    my ($self) = @_;
    
    $self->{output}->output_add(long_msg => "Checking voltages");
    $self->{components}->{voltage} = {name => 'voltages', total => 0, skip => 0};
    return if ($self->check_exclude(section => 'voltage'));

    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{result}})) {
        next if ($oid !~ /^$oid_sysHealthCounterName\.(.*)$/ || $self->{result}->{$oid} !~ /Voltage|IntelCPUVttPower/i);
        my $name = $self->{result}->{$oid};
        $oid =~ /^$oid_sysHealthCounterName\.(.*)$/;
        my $value = $self->{result}->{$oid_sysHealthCounterValue . '.' . $1} / 1000; # in mv
        
        if ($value == 0) {
            $self->{output}->output_add(long_msg => sprintf("Skipping voltage '%s' (counter is 0)", 
                                                            $name));
            next;
        }
        
        next if ($self->check_exclude(section => 'voltage', instance => $name));
        $self->{components}->{voltage}->{total}++;
        $self->{output}->output_add(long_msg => sprintf("Voltage '%s' is %.2f V", 
                                                        $name, $value));
        
        $self->{output}->perfdata_add(label => "volt_" . $name, unit => 'V',
                                      value => sprintf("%.2f", $value),
                                      min => 0);
    }
}

sub check_temperature {
    my ($self) = @_;
    
    $self->{output}->output_add(long_msg => "Checking temperatures");
    $self->{components}->{temperature} = {name => 'temperatures', total => 0, skip => 0};
    return if ($self->check_exclude(section => 'temperature'));

    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{result}})) {
        next if ($oid !~ /^$oid_sysHealthCounterName\.(.*)$/ || $self->{result}->{$oid} !~ /temperature/i);
        my $name = $self->{result}->{$oid};
        $oid =~ /^$oid_sysHealthCounterName\.(.*)$/;
        my $value = $self->{result}->{$oid_sysHealthCounterValue . '.' . $1}; # in C
        
        if ($value == 0) {
            $self->{output}->output_add(long_msg => sprintf("Skipping temperature '%s' (counter is 0)", 
                                                            $name));
            next;
        }
        
        next if ($self->check_exclude(section => 'temperature', instance => $name));
        $self->{components}->{temperature}->{total}++;
        $self->{output}->output_add(long_msg => sprintf("temperature '%s' is %s C", 
                                                        $name, $value));
        
        $self->{output}->perfdata_add(label => "temp_" . $name, unit => 'C',
                                      value => $value,
                                      min => 0);
    }
}

1;

__END__

=head1 MODE

Check System Health Status (temperatures, voltages, power supplies, fanspeed).

=over 8

=item B<--component>

Which component to check (Default: 'all').
Can be: 'temperature', 'voltage', 'fanspeed', 'psu'.

=item B<--exclude>

Exclude some parts (comma seperated list) (Example: --exclude=psu)
Can also exclude specific instance: --exclude='psu#1#'

=item B<--no-component>

Return an error if no compenents are checked.
If total (with skipped) is 0. (Default: 'critical' returns).

=item B<--absent-problem>

Return an error if an entity is not 'present' (default is 'ok') (only for psu)
Can be specific or global: --exclude=psu#1#

=item B<--threshold-overload>

Set to overload default threshold values (syntax: status,regexp).
It used before default thresholds (order stays) (only for psu).
Example: --threshold-overload='CRITICAL,^(?!(normal)$)'

=back

=cut