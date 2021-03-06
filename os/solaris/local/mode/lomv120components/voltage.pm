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

package os::solaris::local::mode::lomv120components::voltage;

use strict;
use warnings;
use centreon::plugins::misc;

my %conditions = (
    1 => ['^(?!(ok)$)' => 'CRITICAL'],
);

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => "Checking supply voltages");
    $self->{components}->{voltage} = {name => 'voltages', total => 0, skip => 0};
    return if ($self->check_exclude(section => 'voltage'));
    
    #Supply voltages:
    #1               5V status=ok
    #2              3V3 status=ok
    #3             +12V status=ok
    return if ($self->{stdout} !~ /^Supply voltages:(((.*?)(?::|Status flag))|(.*))/ims);
    
    my @content = split(/\n/, $1);
    shift @content;
    foreach my $line (@content) {
        $line = centreon::plugins::misc::trim($line);
        next if ($line !~ /^\s*(\S+).*?status=(.*)/);
        my ($instance, $status) = ($1, $2);
        
        next if ($self->check_exclude(section => 'voltage', instance => $instance));
        $self->{components}->{voltage}->{total}++;
        
        $self->{output}->output_add(long_msg => sprintf("Supply voltage '%s' status is %s.",
                                                        $instance, $status)
                                    );
        foreach (keys %conditions) {
            if ($status =~ /${$conditions{$_}}[0]/i) {
                $self->{output}->output_add(severity => ${$conditions{$_}}[1],
                                            short_msg => sprintf("Supply voltage '%s' status is %s",
                                                                 $instance, $status));
                last;
            }
        }
    }
}

1;