require_relative "../lib/bigml/api"
require "test/unit"

class TestCorrelations < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating a correlation from a dataset 
  def test_scenario1
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv",
             'correlation_name' => "my new correlation name"}]

    puts 
    puts "Scenario: Successfully creating a correlation from a dataset" 
  
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

       puts "And I create a correlation from a dataset"
       correlation = @api.create_correlation(dataset)

       puts "And I wait until the correlation is ready"
       assert_equal(BigML::HTTP_CREATED, correlation["code"])
       assert_equal(@api.ok(correlation), true)

       puts "And I update the correlation with new name #{item['correlation_name']}"
       correlation=@api.update_correlation(correlation,{'name'=> item["correlation_name"]})
       assert_equal(BigML::HTTP_ACCEPTED, correlation["code"])
     
       puts "When I wait until the correlation is ready" 
       assert_equal(@api.ok(correlation), true)

       puts "Then the correlation name is #{item['correlation_name']}"
       assert_equal(item["correlation_name"], correlation["object"]["name"])

    end

  end

end
