require 'yaml'
require 'exceptions'

# = Systemtime model
# Provides set and gets resources from YaPI time module.
# Main goal is handle YaPI specific calls and data formats. Provides cleaned
# and well defined data.
class Role < BaseModel::Base

attr_accessor :users
attr_accessor :permissions
attr_accessor :name
attr_writer :new_record
#specify serialized attributes to prevent new_record serialization
attr_serialized :users, :permissions, :name

ROLES_DEF_PATH = File.join Paths::VAR, "roles", "roles.yml"
ROLES_ASSIGN_PATH = File.join Paths::VAR, "roles", "roles_assign.yml"

def initialize(name="",permissions=[],users=[])
  @name = name
  @permissions = (permissions||[]).sort
  @users = (users||[]).sort
	@new_record = true
end

def new_record?
	@new_record
end

def self.find(what=:all,options={})
  result = find_all
  return case what
  when :all then
    result.values || []
  else
		Rails.logger.info "find role for id #{what}"
    v = result.find { |k,v| k.to_sym == what.to_sym }
		v[1] if v #return value, not key
  end
end

def update
	roles = Role.find_all
	#check what really changes to avoid unneccesary write and also better permissions
	roles[name] = self
	Role.write_definitions roles.values
	Role.write_assigns roles.values
end

def create
	roles = Role.find_all
	roles[name] = self
	Role.write_definitions roles.values
	Role.write_assigns roles.values
end

def self.delete (id)
	roles = find_all
	roles.delete id.to_s
	write_definitions roles.values
	write_assigns roles.values
end

private 
def self.find_all
  raise CorruptedFileException.new( ROLES_DEF_PATH ) unless File.exist? ROLES_DEF_PATH
  raise CorruptedFileException.new( ROLES_ASSIGN_PATH ) unless File.exist? ROLES_ASSIGN_PATH
  definitions = YAML::load( IO.read( ROLES_DEF_PATH ) ) || {}#FIXME convert yaml parse error to own exc
  result = {}
  definitions.each do |k,v|
    result[k] = Role.new( k, v )
		result[k].new_record = false #already known role
  end
  assigns = YAML::load( IO.read( ROLES_ASSIGN_PATH ) ) || {}
  assigns.each do |k,v|
    if result[k].nil? #incosistent files
			result[k] = Role.new(k)
			result[k].new_record = false
		end
    result[k].users = v.sort
  end
  return result
end

def self.write_definitions(roles)
	result = {}
	roles.each do |v|
		result[v.name] = v.permissions
	end
	File.open ROLES_DEF_PATH, "w" do |io|
		io.write result.to_yaml
	end
end

def self.write_assigns(roles)
	result = {}
	roles.each do |v|
		result[v.name] = v.users
	end
	File.open ROLES_ASSIGN_PATH, "w" do |io|
		io.write result.to_yaml
	end
end
end