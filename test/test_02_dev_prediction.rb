require "test/unit"
require_relative "../lib/bigml/api"

class TestDevPredicction < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new(nil, nil, true)
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating a prediction:
  def test_scenario1
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv", 
             "data_input" => {'petal width'=> 0.5},
	     "objective" => "000004",
	     "prediction" => "Iris-setosa"},
	     {"filename" => File.dirname(__FILE__)+"/data/iris_sp_chars.csv",
	     "data_input" => {'pétal&width'=> 0.5},
	     "objective" => "000004",
	     "prediction" => "Iris-setosa"}]

    data.each do |item|
       puts
       puts "\nScenario: Successfully creating a prediction:\n"
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

       puts "When I create a prediction for "  + JSON.generate(item["data_input"])
       prediction = @api.create_prediction(model, item["data_input"])
       assert_equal(BigML::HTTP_CREATED, prediction["code"])

       puts "Then the prediction for " + item["objective"] + " is " + item["prediction"]
       assert_equal(item["prediction"], prediction["object"]["prediction"][item["objective"]])

    end

  end

end

