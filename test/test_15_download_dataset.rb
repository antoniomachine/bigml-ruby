require_relative "../lib/bigml/api"
require "test/unit"

class TestDownloadDataset < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new(nil, nil, true)
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully exporting a dataset
 
  def test_scenario1
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv",
             "local_file" => File.dirname(__FILE__)+"/tmp/exported_iris.csv"}] 

    puts
    puts "Scenario: Successfully exporting a dataset:"
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

       puts "And I download the dataset file to #{item['local_file']} "
       filename = @api.download_dataset(dataset, item["local_file"])
       assert_not_nil(filename)

       puts "Then the download dataset file is like #{item['filename']}"
       assert_equal(FileUtils.compare_file(item["filename"], item["local_file"]), true)

    end

  end

end

