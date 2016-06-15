require_relative "../lib/bigml/api"
require "test/unit"

class TestSampleDataset < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new(nil, nil, true)
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating a sample from a dataset 
 
  def test_scenario1
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv",
             "sample_name" => "my new sample name"}]

    puts
    puts "Scenario:  Successfully creating a sample from a dataset" 

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

       puts "And I create a sample from a dataset"
       sample = @api.create_sample(dataset, {'name'=> 'new sample'})

       puts "And I wait the sample is ready"
       assert_equal(BigML::HTTP_CREATED, sample["code"]) 
       assert_equal(@api.ok(sample), true)

       puts "I update the sample name to #{item['sample_name']}"

       sample = @api.update_sample(sample, {'name'=> item["sample_name"]})
       assert_equal(BigML::HTTP_ACCEPTED, sample["code"])

       puts "When I wait until the sample is ready"
       assert_equal(@api.ok(sample), true)
       sample = @api.get_sample(sample)

       puts "Then the sample name is #{item['sample_name']}"
       assert_equal(sample["object"]["name"], item["sample_name"])

    end

  end

end

