class Security #< ActiveRecord::Base

  require "scr"


#    @scr = Scr.instance
  attr_accessor :error_id,
                :error_string,
                :firewall,
                :firewall_after_startup,
                :ssh

  public

  def initialize
    @firewall = ""
    @firewall_after_startup = ""
    @ssh = ""
    @error_string = ""
    @error_id = 0
    @scr = Scr.instance
  end

  def update
    @firewall = firewall?
    @firewall_after_startup = firewall_after_startup?
    @ssh = ssh?
  end

  def write(a, b, c)
    @firewall = firewall(a)
    @firewall_after_startup = firewall_after_startup(b)
    @ssh = ssh(c)
  end

  def to_xml(options = {})
    xml = options[:builder] ||= Builder::XmlMarkup.new(options)
    xml.instruct! unless options[:skip_instruct]

    xml.security do
      xml.tag!(:ssh, @ssh, {:type => "boolean"})
      xml.tag!(:firewall, @firewall, {:type => "boolean"})
      xml.tag!(:firewall_after_startup, @firewall_after_startup, {:type => "boolean"})
      xml.tag!(:error_id, @error_id, {:type => "integer"})
      xml.tag!(:error_string, @error_string)
    end
  end

  def to_json(options = {})
    hash = Hash.from_xml(to_xml())
    return hash.to_json
  end

  private
  def firewall?
    IO.popen("rcSuSEfirewall2 status", 'r+') do |pipe|
      break if pipe.eof?
      if pipe.read.to_str.include? "running"
        return true
      else#if retval.include? "unused"
        return false
      end
    end
  end

  def firewall_after_startup?
#=begin
    cmd = @scr.execute(["/sbin/yast2", "firewall", "startup", "show"])
    lines = cmd[:stderr].split "\n"
    lines.each do |l|
      if l.length > 0
        if l.include? "enabled"
          return true
        elsif l.include? "manual"
          return false
        end
      end
    end
#=end
  end

  def ssh?
    IO.popen("rcsshd status", 'r+') do |pipe|
      break if pipe.eof?
      if pipe.read.to_str.include? "running"
        return true
      else #if retval.include? "unused"
        return false
      end
    end
  end

  # returns true for success and false for failure
  def firewall(param)
    if param == true   # start firewall
      action = "restart"
    else               # stop firewall
      action = "stop"
    end
    IO.popen("rcSuSEfirewall2 #{action}", 'r+') do |pipe|
      break if pipe.eof?
      retval = pipe.read.to_str
      if retval.include? "done" #success
        return true
      end
    end
    return false
  end

  # returns true for success and false for failure
  def firewall_after_startup(param)
    @scr = Scr.instance
    if param == true    # enable
      action = "atboot"
      verify = "Enabling"
    else                # disable
      action = "manual"
      verify = "Removing"
    end
    cmd = @scr.execute(["/sbin/yast2", "firewall", "startup", "#{action}"])
    lines = cmd[:stderr].split "\n"
    lines.each do |l|
      if l.length > 0
        if l.include? "#{verify}"
          return true
        end
      end
    end
    return false
  end

  # returns true for success and false for failure
  def ssh(param)
    if param == true   # start sshd
      action = "restart"
    else
      action = "stop"  # stop sshd
    end
    IO.popen("rcsshd #{action}", 'r+') do |pipe|
      break if pipe.eof?
      retval = pipe.read.to_str
      if retval.include? "done" #success
        return true
      end
    end
    return false
  end
end
