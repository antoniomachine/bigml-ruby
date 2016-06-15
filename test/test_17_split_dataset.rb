require_relative "../lib/bigml/api"
require "test/unit"

class TestSplitDataset < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new(nil, nil, true)
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully  creating a split dataset
 
  def test_scenario1
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv",
             'rate' => 0.8}]

    puts
    puts "Scenario: Successfully  creating a split dataset"

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

       puts "And I create a dataset extracting a #{item['rate']} sample"
       
       dataset_sample = @api.create_dataset(dataset, {'sample_rate' => item["rate"]})
       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset_sample["code"])
       assert_equal(@api.ok(dataset_sample), true)

       puts "When I compare the datasets' instances"
       dataset = @api.get_dataset(dataset)
       dataset_sample = @api.get_dataset(dataset_sample)

       puts "Then the proportion of instances between datasets is #{item['rate']}"
       assert_equal(dataset_sample["object"]["rows"], (dataset["object"]["rows"]*item["rate"]).to_i)

    end

  end

end

