class Status < ActiveRecord::Base
  require 'scr'

  attr_accessor :data

  def initialize
    @scr = Scr.instance
    @health_status = nil
    @data = Hash.new
    start_collectd
#    @collectd_base_dir = "/var/lib/collectd/"
    @datapath = set_datapath
    @metrics = available_metrics
  end

  def start_collectd
    cmd = @scr.execute(["collectd"])
    @timestamp = Time.now
  end

  def stop_collectd
    cmd = @scr.execute(["killall", "collectd"])
    @timestamp = nil
  end

  # set path of stored rrd files, default: /var/lib/collectd/$host.$domain
  def set_datapath(path=nil)
    default = "/var/lib/collectd/"
    unless path.nil?
      @datapath = path.chomp("/")
    else # set default path
      cmd = IO.popen("hostname")
      host = cmd.read
      cmd.close
      cmd = IO.popen("domainname")
      domainname = cmd.read
      cmd.close
      @datapath = "#{default}#{host.strip}.#{domainname.strip}"
    end
    return @datapath
  end

  def available_metrics
    metrics = Hash.new
    cmd = IO.popen("ls #{@datapath}")
    output = cmd.read
    cmd.close
    output.split(" ").each do |l|
      fp = IO.popen("ls #{@datapath}/#{l}")
      files = fp.read
      fp.close
      metrics["#{l}"] = { :rrds => files.split(" ")}
    end
    return metrics
  end

  def available_metric_files
    cmd = IO.popen("ls #{@datapath}..")
    lines = cmd.read.split "\n"
    cmd.close
    return lines
  end

  def determine_status
  end

  def draw_graph(heigth=nil, width=nil)
  end

  # creates several metrics for a defined period
  def collect_data(start=Time.now, stop=Time.now, data = %w{cpu memory disk})
    result = Hash.new
    unless @timestamp.nil? # collectd not started
        case data
        when nil, "all", "All" # all metrics
          @metrics.each_pair do |m, n|
            @metrics["#{m}"][:rrds].each do |rrdb|
              result["#{rrdb}".chomp(".rrd")] = fetch_metric("#{m}/#{rrdb}", start, stop)
            end
            @data["#{m}"] = result
            result = Hash.new
          end
        else # only metrics in data
          data.each do |d|
            @metrics.each_pair do |m, n|
              if m.include?(d)
                @metrics["#{m}"][:rrds].each do |rrdb|
                result["#{rrdb}".chomp(".rrd")] = fetch_metric("#{m}/#{rrdb}", start, stop)
              end
              @data["#{m}"] = result
              result = Hash.new
            end
          end
        end
      end
    end
    return @data
  end

  # creates one metric for defined period
  def fetch_metric(rrdfile, start=nil, stop=nil)
    result = Hash.new
    if start.blank?
      start = "--start #{Time.now.strftime("%H:%M,%m/%d/%Y")}"
    else
      start = "--start #{start}"#start.strftime("%H:%M,%m/%d/%Y")}"
    end
    if stop.blank?
      stop = "--end #{Time.now.strftime("%H:%M,%m/%d/%Y")}"
    else
      stop = "--end #{stop}"#stop.strftime("%H:%M,%m/%d/%Y")}"
    end
    cmd = IO.popen("rrdtool fetch #{@datapath}/#{rrdfile} AVERAGE #{start} #{stop}")

    output = cmd.read
    cmd.close
    return "failed" if output.blank?

    labels=""
    output = output.gsub(",", ".") # translates eg. 1,234e+07 to 1.234e+07
    lines = output.split "\n"
    # set label names
    lines[0].each do |l|
      if l =~ /\D*/
        labels = l.split " "
      end
    end
    unless labels.blank?
      # set values for each label and time
      lines.each do |l| # each time
        unless l.blank?
          if l =~ /\d*:\D*/
            pair = l.split ":"
            values = pair[1].split " "
            column = 0
            values.each do |v| # each label
              result["#{labels[column]}"] ||= Hash.new
              result["#{labels[column]}"].merge!({"T_#{pair[0].chomp(": ")}" => v})
              column += 1
            end
          end
        end
      end
      return result
    else
      return "failed"
    end
  end
end
