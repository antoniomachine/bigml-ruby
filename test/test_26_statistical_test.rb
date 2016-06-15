require_relative "../lib/bigml/api"
require "test/unit"

class TestStatisticalTest < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating an statistical test from a dataset 
  def test_scenario1
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv",
             "test_name" => "my new statistical test name"}]

    puts 
    puts "Scenario: Successfully creating an statistical test from a dataset"
  
    data.each do |item|
       puts
       puts "Given I create a data source uploading a " + item["filename"] + " file"
       source = @api.create_source(item["filename"], {'name'=> 'source_test', 'project'=> @project["resource"]})

       puts "And I wait until the source is ready"
       assert_equal(BigML::HTTP_CREATED, source["code"])
       assert_equal(1, source["object"]["status"]["code"])
       assert_equal(@api.ok(source), true)

       puts "And I create dataset with local source"
       dataset=@api.create_dataset(source)

       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)

       puts "And I create an statistical test from a dataset"
       statistical_test = @api.create_statistical_test(dataset, {'name'=> 'new statistical test'})
       
       puts "And I wait until the statistical test is ready"
       assert_equal(BigML::HTTP_CREATED, statistical_test["code"])
       assert_equal(@api.ok(statistical_test), true)

       puts "And I update the statistical test name to #{item['test_name']}"
       statistical_test = @api.update_statistical_test(statistical_test, {"name" => item["test_name"]})

       puts "When I wait until the statistical test is ready";
       assert_equal(BigML::HTTP_ACCEPTED, statistical_test["code"])
       assert_equal(@api.ok(statistical_test), true)

       puts "Then the statistical test name is #{item['test_name']}"
       assert_equal(item["test_name"], statistical_test["object"]["name"])

    end

  end

end
