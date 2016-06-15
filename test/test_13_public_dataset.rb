require_relative "../lib/bigml/api"
require "test/unit"

class TestPublicDataset < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating and reading a public dataset
  def test_scenario1
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv"}] 

    puts
    puts "Scenario: Successfully creating and reading a public dataset"
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

       puts "I make the dataset public"
       dataset = @api.update_dataset(dataset, {'private'=> false})
       assert_equal(BigML::HTTP_ACCEPTED, dataset["code"])
       assert_equal(@api.ok(dataset), true)

       puts "When I get the dataset status using the dataset's public url";
       dataset = @api.get_dataset("public/#{dataset['resource']}")

       puts "Then the dataset's status is FINISHED";
       assert_equal(BigML::FINISHED, dataset["object"]["status"]["code"])

       puts "And I make the dataset private again"
       dataset = @api.update_dataset(dataset, {'private'=> true})
       assert_equal(BigML::HTTP_ACCEPTED, dataset["code"])

    end

  end

end

