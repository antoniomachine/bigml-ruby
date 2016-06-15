require_relative "../lib/bigml/api"
require "test/unit"

class TestExecution < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating a whizzml execution

  def test_scenario1
    data = [{"source_code" => "(+ 1 1)",
             "param" => "name",
             "param_value" => "my script",
             "result" => 2}]

    puts 
    puts "Scenario: creating a whizzml execution"
  
    data.each do |item|

       puts "Given I create a whizzml script from a excerpt of code #{item['source_code']}"
       script = @api.create_script(item["source_code"])
 
       puts "And I wait until the script is ready" 
       assert_equal(BigML::HTTP_CREATED, script["code"])
       assert_equal(@api.ok(script), true)
    
       puts "And I create a whizzml script execution from an existing script"
       execution = @api.create_execution(script)
       
       puts "And I wait until the execution is ready" 
       assert_equal(BigML::HTTP_CREATED, execution["code"])
       assert_equal(@api.ok(execution), true)
 
       puts "And I update the execution with #{item['param']} , #{item['param_value']}"
       execution = @api.update_execution(execution, {item["param"] => item["param_value"]})

       puts "And I wait until the execution is ready"
       assert_equal(BigML::HTTP_ACCEPTED, execution["code"])
       assert_equal(@api.ok(execution), true)

       puts "Then the script id is correct and the value of #{item['param']} is #{item['param_value']} and the result is #{item['result']}"
       assert_equal(execution["object"][item["param"]], item["param_value"])
       assert_equal(execution["object"]["execution"]["results"][0], item["result"])

    end

  end

  def test_scenario2
    data = [{'source_code' => '(+ 1 1)',
            'param' => 'name',
            'param_value' => 'my execution',
            'result' => [2,2]}]
    puts
    puts "Scenario: Successfully creating a whizzml script execution from a list of scripts"
    data.each do |item|
       puts
       puts "Given I create a whizzml script from a excerpt of code #{item['source_code']}"
       script = @api.create_script(item["source_code"])
 
       puts "And I wait until the script is ready" 
       assert_equal(BigML::HTTP_CREATED, script["code"])
       assert_equal(@api.ok(script), true)

       puts "And I create a other whizzml script from a excerpt of code #{item['source_code']}"
       script2 = @api.create_script(item["source_code"])
  
       puts "And I wait until the script is ready"
       assert_equal(BigML::HTTP_CREATED, script2["code"])
       assert_equal(@api.ok(script2), true)

       puts "And I create a whizzml execution from the last two scripts"
       execution = @api.create_execution([script, script])

       puts "And I wait until the execution is ready" 
       assert_equal(BigML::HTTP_CREATED, execution["code"])
       assert_equal(@api.ok(execution), true)

       puts "And I update the execution with #{item['param']} , #{item['param_value']}"
       execution = @api.update_execution(execution, {item["param"] => item["param_value"]})

       puts "And I wait until the execution is ready"
       assert_equal(BigML::HTTP_ACCEPTED, execution["code"])
       assert_equal(@api.ok(execution), true) 

       puts "Then the script id is correct and the value of #{item['param']} is #{item['param_value']} and the result is #{item['result']}"
       assert_equal(execution["object"][item["param"]], item["param_value"])
       assert_equal(execution["object"]["execution"]["results"], item["result"])

    end
 
  end


end
