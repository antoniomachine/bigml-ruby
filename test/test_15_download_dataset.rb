require_relative "../lib/bigml/api"
require "test/unit"

class TestDownloadDataset < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})

   unless File.directory?(File.dirname(__FILE__)+'/tmp/')
     FileUtils.mkdir_p(File.dirname(__FILE__)+'/tmp/')
   end

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
  
  def test_scenario2
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv",
             "expected_file" => File.dirname(__FILE__)+"/tmp/model/iris.json", "pmml" => false}, 
            {"filename" => File.dirname(__FILE__)+"/data/iris_sp_chars.csv",
              "expected_file" => File.dirname(__FILE__)+"/tmp/model/iris_sp_chars.pmml", "pmml" => true}]

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
       
       puts "And I create model"
       model=@api.create_model(dataset)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)
       
       puts "And I export the <%s> model to file <%s>" % [item["pmml"], item["expected_file"]]
       @api.export(model["resource"], item["expected_file"], item["pmml"])
       
       puts "Then I check the model is stored in <%s> file in <%s>" % [item["expected_file"], item["pmml"]]
       
       content = File.read(item["expected_file"])
       model_id = model["resource"][model["resource"].index("/")+1..-1]       
       assert_equal(content.index(model_id) > -1, true)

    end

  end

end

