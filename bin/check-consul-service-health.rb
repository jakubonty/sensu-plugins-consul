#! /usr/bin/env ruby
#
#   check-consul-service-health
#
# DESCRIPTION:
#   This plugin assists in checking the check status of a Consul Service
#   In addition, it provides additional Yieldbot logic for Output containing
#   JSON.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: diplomat
#
# USAGE:
#   ./check-consul-service-health -s influxdb
#   ./check-consul-service-health -a
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Yieldbot, Inc. <devops@yieldbot.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'diplomat'
require 'json'

#
# Service Status
#
class CheckConsulServiceHealth < Sensu::Plugin::Check::CLI
  option :service,
         description: 'a service managed by consul',
         short: '-s SERVICE',
         long: '--service SERVICE',
         default: 'consul'

  option :all,
         description: 'get all services',
         short: '-a',
         long: '--all'

  # Get the service checks for the given service
  def acquire_service_data
    if config[:all]
      Diplomat::Health.checks
    else
      Diplomat::Health.checks(config[:service])
    end
  end

  # Do work
  def run
    warnings   = false
    criticals  = false
    checks     = {}

    # Process all of the nonpassing service checks
    acquire_service_data.each do |d|
      checkId     = d['CheckID'] # rubocop:disable Style/VariableName
      checkStatus = d['Status'] # rubocop:disable Style/VariableName

      # If we are passing do nothing
      next if checkStatus == 'passing'

      checks[checkId] = d['Output']

      warnings  = true  if %w(warning).include? checkStatus
      criticals = true  if %w(critical unknown).include? checkStatus
    end

    critical checks if criticals
    warning checks  if warnings
    ok
  end
end
