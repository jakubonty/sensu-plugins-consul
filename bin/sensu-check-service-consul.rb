#! /usr/bin/env ruby
#
#   check-service-consul
#
# DESCRIPTION:
#   This plugin checks if consul says a service is 'passing' or
#   'critical'
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
#   ./check-service-consul -s influxdb
#   ./check-service-consul -a
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Yieldbot, Inc. <Sensu-Plugins>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'diplomat'
require 'socket'
require 'json'

#
# Service Status
#
class ServiceStatus < Sensu::Plugin::Check::CLI
  # option :service,
  #        description: 'a service managed by consul',
  #        short: '-s SERVICE',
  #        long: '--service SERVICE',
  #        default: 'consul'

  # option :all,
  #        description: 'get all services in a non-passing status',
  #        short: '-a',
  #        long: '--all'

  # Get the check data for the service from consul
  #
  def acquire_service_data
    Diplomat::Check.checks
  rescue Faraday::ConnectionFailed => e
    warning "Connection error occurred: #{e}"
  rescue StandardError => e
    unknown "Exception occurred when checking consul service: #{e}"
  end

  def add_sensu_check_result(result, host='localhost', port=3030)
    s = TCPSocket.new(host, port)
    s.write(result.to_json.to_s)
    s.close
  end

  # Main function
  #
  def run
    data = acquire_service_data
    passing = []
    failing = []
    data.each do |check_name, d|
      if d['Status'] == 'passing'
        add_sensu_check_result({name: d['Name'], output: d['Output'], status: 0})
        passing << {
          'node' => d['Node'],
          'name' => d['Name'],
          'notes' => d['Notes']
        }
      else
        add_sensu_check_result({name: d['Name'], output: d['Output'], status: 2})
        failing << {
          'node' => d['Node'],
          'name' => d['Name'],
          'notes' => d['Notes']
        }
      end
    end
    unknown 'Could not find service - are there checks defined?' if failing.empty? && passing.empty?
    critical failing unless failing.empty?
    ok passing unless passing.empty?
  end
end
