class Systemtime

  @@timezones = Array.new()

  attr_accessor :datetime,
                :timezone,
                :utcstatus            

  private
  def parse_response(response)
    @datetime = response["time"]
    @utcstatus= response["utcstatus"]
    @timezone = response["timezone"]
    if response["zones"]
      @@timezones = response["zones"]
    end
  end

  def create_read_question
    ret = {
      "timezone" => "true",
      "utcstatus" => "true",
      "currenttime" => "true"
    }
    ret["zones"]= "true" if @@timezones.empty?
    return ret
  end

  public

  def initialize     
  end

  def read
    parse_response YastService.Call("YaPI::TIME::Read",create_read_question)
  end

  def to_xml( options = {} )
    xml = options[:builder] ||= Builder::XmlMarkup.new(options)
    xml.instruct! unless options[:skip_instruct]

    xml.systemtime do
      xml.tag!(:time, @datetime )
      xml.tag!(:timezone, @timezone )
      xml.tag!(:utcstatus, @utcstatus )
      xml.timezones({:type => "array"}) do
         @@timezones.each do |region|
            if not region.empty?
               xml.region do
                 xml.tag!(:name,  region["name"])
                 xml.tag!(:central,  region["central"])
                 xml.entries({:type => "array"}) do
                  region["entries"].each do |id,name|
                    xml.timezone do
                      xml.tag!(:id, id)
                      xml.tag!(:name, name)
                    end
                  end
                 end
                  
               end
            end
         end
      end
    end
  end

  def to_json( options = {} )
    hash = Hash.from_xml(to_xml())
    return hash.to_json
  end

end
