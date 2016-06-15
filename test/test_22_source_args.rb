require_relative "../lib/bigml/api"
require "test/unit"

class TestSourceArgs < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new(nil, nil, true)
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Uploading source with structured args 
 
  def test_scenario1
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv",
             "params" => {"tags" => ["my tag", "my second tag"], 
                          "project" => @project["resource"]}}]
            #{"filename" => "./data/iris.csv",
            # "params" => {"name" => "Testing unicode names: áé",
            #              "project" =>  @project["resource"]}}]

    puts
    puts "Scenario: Uploading source with structured args" 

    data.each do |item|
       puts
       puts "Given I create a data source uploading a " + item["filename"] + " file"
       source = @api.create_source(item["filename"], item["params"].clone)

       puts "And I wait until the source is ready"
       assert_equal(BigML::HTTP_CREATED, source["code"])
       assert_equal(1, source["object"]["status"]["code"])
       assert_equal(@api.ok(source), true)

       puts "Then the source exists and has args #{JSON.generate(item['params'])}"
       #source = @api.get_source(source)
       #pp source
 
       item['params'].each do |param, value|
          assert_equal(source["object"][param], value)
       end

    end

  end

end

