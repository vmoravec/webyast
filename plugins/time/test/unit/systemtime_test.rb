require 'test_helper'
require 'systemtime'

class SystemtimeTest < ActiveSupport::TestCase

  TEST_TIMEZONES = [{
      "name" => "Europe",
      "central" => "Europe/Prague",
      "entries" => {
        "Europe/Prague" => "Czech Republic",
        "Europe/Kiev" => "Ukraine (Kiev)"
      }
    },
    {
      "name" => "USA",
      "central" => "America/Chicago",
      "entries" => {
        "America/Chicago" => "Central (Chicago)",
        "America/Kentucky/Monticello" => "Kentucky (Monticello)"
      }
    }
  ]

  def read_arguments
    return {
      "zones"=> "true",
      "timezone"=> "true",
      "utcstatus"=> "true",
      "currenttime" => "true"
    }
  end

  def read_response
    return {
      "zones"=> TEST_TIMEZONES,
      "timezone"=> "Europe/Prague",
      "utcstatus"=> "true",
      "time" => "2009-07-02 - 12:18:00"
    }
  end

  def write_arguments
    return {
      "timezone"=> "America/Kentucky/Monticello",
      "utcstatus"=> "false"
    }
  end

  def setup    
    @model = Systemtime.new
  end

  
  def test_getter
    result = read_response
    YastService.stubs(:Call).with("YaPI::TIME::Read",read_arguments).returns(result)

    @model = Systemtime.find
    assert_equal("02/07/2009", @model.date)
    assert_equal("12:18:00", @model.time)
    assert_equal("Europe/Prague", @model.timezone)
    assert_equal("true", @model.utcstatus)
    assert_equal(TEST_TIMEZONES,Systemtime.timezones)
  end

  def test_setter
    YastService.stubs(:Call).with("YaPI::TIME::Write",write_arguments).returns(true)
    YastService.expects(:Call).once

    @model.timezone = "Europe/Prague"
    @model.utcstatus = "false"
    @model.save
  end

  def test_xml
    #inject Timezones to set available timezone for direct testing
    def @model.timezones=(val)
      @@timezones=val
    end

    data = read_response
    @model.timezone = data["timezone"]
    @model.utcstatus = data["utcstatus"]
    @model.date = "02/07/2009"
    @model.time = "12:18:00"
    @model.timezones = TEST_TIMEZONES

    response = Hash.from_xml(@model.to_xml)
    response = response["systemtime"]

    assert_equal(data["timezone"], response["timezone"])
    assert_equal(data["utcstatus"], response["utcstatus"])
    assert_equal("12:18:00", response["time"])
    assert_equal("02/07/2009", response["date"])

    zone_response = TEST_TIMEZONES
    zone_response.each { |zone|
      entries = []
      zone["entries"].each { |k,v|
        entries.push({"id"=>k,"name"=>v})
      }
      zone["entries"] = entries
    }

    assert_equal(zone_response.sort { |a,b| a["name"] <=> b["name"] },
      response["timezones"].sort { |a,b| a["name"] <=> b["name"] })
  end

  def test_json
    #inject Timezones to set available timezone for direct testing
    def @model.timezones=(val)
      @@timezones=val
    end
    

    data = read_response
    @model.timezone = data["timezone"]
    @model.utcstatus = data["utcstatus"]
    @model.date = "02/07/2009"
    @model.time = "12:18:00"
    @model.timezones = TEST_TIMEZONES

    assert_not_nil(@model.to_json)
  end

end
