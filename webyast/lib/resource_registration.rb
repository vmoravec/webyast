#
# Webyast framework
#
# Copyright (C) 2009, 2010 Novell, Inc.
#   This library is free software; you can redistribute it and/or modify
# it only under the terms of version 2.1 of the GNU Lesser General Public
# License as published by the Free Software Foundation.
#
#   This library is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
#   You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 021101301 USA
#++

require 'singleton'

# load resources and populate database

class ResourceRegistrationError < StandardError
end

class ResourceRegistrationPathError < ResourceRegistrationError
end

class ResourceRegistrationFormatError < ResourceRegistrationError
end

class ResourceRegistration
  attr_reader :resources

  include Singleton

  def initialize
    @in_production = (ENV['RAILS_ENV'] == "production")
    @resources = Hash.new

    WebyastEngine.find.each do |engine|
      Rails.logger.info "Found Webyast engine #{engine.class}"
      res_path = File.join(engine.config.root, 'config')
      if defined? RESOURCE_REGISTRATION_TESTING
        raise ResourceRegistrationPathError.new("Could not access plugin directory: #{res_path}") unless File.exists?( res_path )
      end

      res_path = File.join(res_path, 'resources')
      if defined? RESOURCE_REGISTRATION_TESTING
        raise ResourceRegistrationPathError.new("Could not access plugin directory: #{res_path}") unless File.exists?( res_path )
      end

      found = false
      Dir.glob(File.join(res_path, '**/*.y*ml')).each do |descriptor|
        next unless descriptor =~ %r{#{res_path}/((\w+)/)?(\w+)\.y(a)?ml$}
        register(descriptor)
        found = true
      end

      if defined? RESOURCE_REGISTRATION_TESTING
        raise ResourceRegistrationPathError.new("Could not find any YAML file with resource description below #{res_path}") unless found
      end
    end
  end


  private

  def self.error msg
    if @in_production
      log.error msg
      return
    else
      raise ResourceRegistrationFormatError.new( msg )
    end
  end



  # register a (.yaml) resource description
  # optionally the interface and controller can be passed
  # otherwise they are read from the yml file

  def register(file, interface = nil, controller = nil)
    require 'yaml'
    name = name || File.basename(file, ".*")

    begin
      resource = YAML.load(File.open(file)) || Hash.new
    rescue Exception => e
      raise # reraise
    end

    error "#{file} has wrong format" unless resource.is_a? Hash

    # interface: can override
    interface = resource['interface'] || interface

    error "#{file} does not specify interface" unless interface
    error "#{file}: interface is not a qualified name" unless interface =~ %r{((\w+)\.)+(\w+)}

    name = interface.split(".").pop

    # controller: must be given
    controller = resource['controller'] || controller
    error "#{file} does not specify controller" unless controller

    # policy: is optional, interface is used otherwise
    policy = resource["policy"]

    # singular: is optional, defaults to false
    singular = resource["singular"] || false

    # cache_enabled: is optional, default to true
    unless resource["cache"].blank?
      cache_enabled = resource["cache"]["enabled"]
    else
      cache_enabled =  true
    end

    # cache_priority: is optional, default to 10
    cache_priority = (resource["cache"]["priority"].to_i unless resource["cache"].blank?) || 10

    # cache_reload_after: is optional, default to 0 (no reload)
    cache_reload_after = (resource["cache"]["reload_after"].to_i unless resource["cache"].blank?) || 0

    # cache_arguments: is optional, default to ""
    cache_arguments = (resource["cache"]["arguments"] unless resource["cache"].blank? ) || ""

    error "#{file}: has nonplural interface #{interface} without being flagged as singular" if !singular and name != name.pluralize

    # nested: is optional, defaults to nil
    nested = resource["nested"]
    error "#{file}: singular resources don't support nested" if singular and nested

    resources[interface] ||= Array.new
    resources[interface] << { :controller => controller, :singular => singular, :nested => nested, :policy => policy,
                              :cache_enabled => cache_enabled, :cache_priority => cache_priority, :cache_reload_after => cache_reload_after,
                              :cache_arguments => cache_arguments }
  end


  public
    # reset registered resources
    # useful for testing
    def self.reset
      @@resources = Hash.new
    end



end # class ResourceRegistration
