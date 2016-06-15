require_relative "../lib/bigml/api"
require "test/unit"

class TestLibrary < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating a whizzml library 
  def test_scenario1
    data = [{"source_code" => "(define (mu x) (+ x 1))",
             "param" => "name",
             "param_value" => "my libr"}]
    puts 
    puts "Scenario: Successfully creating a whizzml library"
  
    data.each do |item|

       puts "Given I create a whizzml library from a excerpt of code #{item['source_code']}"
       library = @api.create_library(item["source_code"])
 
       puts "And I wait until the library is ready" 
       assert_equal(BigML::HTTP_CREATED, library["code"])
       assert_equal(@api.ok(library), true)
     
       puts "And I update the library with #{item['param']} , #{item['param_value']}"
       library = @api.update_library(library, {item["param"] => item["param_value"]})

       puts "And I wait until the library is ready"
       assert_equal(BigML::HTTP_ACCEPTED, library["code"])
       assert_equal(@api.ok(library), true) 

       puts "Then the library code is #{item['source_code']} and the value of #{item['param']} is #{item['param_value']}"
       assert_equal(library["object"][item["param"]], item["param_value"])

    end

  end

end
