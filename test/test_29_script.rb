require_relative "../lib/bigml/api"
require "test/unit"

class TestScript < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating a whizzml script 
  def test_scenario1
    data = [{"source_code" => "(+ 1 1)",
             "param" => "name",
             "param_value" => "my script"}]
    puts 
    puts "Scenario: Successfully creating a whizzml script"
  
    data.each do |item|

       puts "Given I create a whizzml script from a excerpt of code #{item['source_code']}"
       script = @api.create_script(item["source_code"])
 
       puts "And I wait until the script is ready" 
       assert_equal(BigML::HTTP_CREATED, script["code"])
       assert_equal(@api.ok(script), true)
     
       puts "And I update the script with #{item['param']} , #{item['param_value']}"
       script = @api.update_script(script, {item["param"] => item["param_value"]})

       puts "And I wait until the script is ready"
       assert_equal(BigML::HTTP_ACCEPTED, script["code"])
       assert_equal(@api.ok(script), true) 

       puts "Then the script code is #{item['source_code']} and the value of #{item['param']} is #{item['param_value']}"
       assert_equal(script["object"][item["param"]], item["param_value"])

    end

  end

end
