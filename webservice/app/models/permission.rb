#--
# Webyast Webservice framework
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
#++


#
# Permission class
#
require 'exceptions'
require 'polkit'

class Permission
#list of hash { :name => id, :granted => boolean, :description => string (optional)}
  attr_reader :permissions

  def initialize
    @permissions = []
  end

  def self.find(type,restrictions={})
    permission = Permission.new
    permission.load_permissions restrictions
    return permission
  end

  def save
    raise "Unimplemented"
  end

  def to_xml( options = {} )
    xml = options[:builder] ||= Builder::XmlMarkup.new(options)
    xml.instruct! unless options[:skip_instruct]

    xml.permissions(:type => "array") do 
      @permissions.each do
        |perm| perm.to_xml({:builder => xml, :skip_instruct => true, :root => "permission"})
      end
    end  
  end

  def to_json( options = {} )
    hash = Hash.from_xml(to_xml())
    return hash.to_json
  end

  def load_permissions(options)
    semiresult = all_actions.split(/\n/)
    if (options[:filter])
      semiresult.delete_if { |perm| !perm.include? options[:filter] }
    else
      semiresult = filter_nonsuse_permissions semiresult
    end
  @permissions = semiresult.map do |value|
      ret = {
        :id => value,
        :granted => false
      }
			ret[:description] = get_description(value) if options[:with_description]
			ret
    end
    user = options[:user_id]
    mark_granted_permissions_for_user user if user
  end

private
  def mark_granted_permissions_for_user(user)
    @permissions.collect! do |perm| 
      begin
        if PolKit.polkit_check( perm[:id], user) == :yes
          perm[:granted] = true
          Rails.logger.debug "Action: #{perm[:id]} User: #{user} Result: ok"
        else
          perm[:granted] = false
          Rails.logger.debug "Action: #{perm[:id]} User: #{user} Result: NOT granted"
        end
      rescue RuntimeError => e
        Rails.logger.info e
        if e.message.include?("does not exist")
          raise InvalidParameters.new :user_id => "UNKNOWN" 
        else
          raise PolicyKitException.new(e.message, user, perm[:id])
        end
      end
      perm
    end
  end

  def all_actions
    `/usr/bin/polkit-action`
  end


	def get_description (action)
		desc = `polkit-action --action #{action} | grep description: | sed 's/^description:[:space:]*\\(.\\+\\)$/\\1/'`
		desc.strip!
		Rails.logger.info "description for #{action} is #{desc}"
		desc
  end

  SUSE_STRING = "org.opensuse.yast"
  def filter_nonsuse_permissions (str)
    str.select{ |s|
      s.include?(SUSE_STRING) &&
        !s.include?(SUSE_STRING+".scr") &&
        !s.include?(SUSE_STRING+".module-manager")}
  end

end
