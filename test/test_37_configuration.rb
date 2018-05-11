require_relative "../lib/bigml/api"


require "test/unit"

class TestConfiguration < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  #  "Scenario: Successfully creating configuration"
  def test_scenario1
    data = [[{"dataset" => {"name" => "Customer FAQ dataset"}}, {"name" => 'my new configuration name'}]
           ]
    puts
    puts "Scenario: Successfully creating configuration"

    data.each do |config, new_configuration|
      puts
      
      puts "Given I create a configuration from '<%s>' info" % JSON.generate(config)
      configuration = @api.create_configuration(config, {"name" => "configuration"})
      assert_equal(BigML::HTTP_CREATED, configuration["code"])
      assert_equal(@api.ok(configuration), true)
      puts "And I update the configuration name to '<%s>'" % JSON.generate(new_configuration)
      configuration = @api.update_configuration(configuration, new_configuration)
     
      puts "When I wait until the configuration is ready"
      assert_equal(BigML::HTTP_ACCEPTED, configuration["code"])
      assert_equal(@api.ok(configuration), true)
      
      puts "Then the configuration name is '<%s>'" % JSON.generate(new_configuration["name"])
      assert_equal(configuration['object']["name"], new_configuration["name"])
      puts  "And the configuration contents are '<%s>'" % JSON.generate(config)
      assert_equal(configuration['object']["configurations"], config)
       
    end
  end
  
end