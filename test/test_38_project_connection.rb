require_relative "../lib/bigml/api"


require "test/unit"

class TestProjectConnection < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  #  "Scenario: Successfully creating a prediction with a user's project connection"
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"petal width" => 0.5}, '000004', 'Iris-setosa']]
    puts
    puts "Scenario: Successfully creating a prediction with a user's project connection"

    data.each do |filename, data_input, objective, prediction_result|
      puts
      puts "Given I create a data source uploading a <%s> file" % filename
      source = @api.create_source(filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

      puts "And I wait until the source is ready"
      assert_equal(BigML::HTTP_CREATED, source["code"])
      assert_equal(1, source["object"]["status"]["code"])
      assert_equal(@api.ok(source), true)
      
      puts "And the source is in the project"
      assert_equal(source["object"]['project'],  @project["resource"])
      
      puts "And I create a dataset"
      dataset=@api.create_dataset(source)

      puts "And I wait until the dataset is ready"
      assert_equal(BigML::HTTP_CREATED, dataset["code"])
      assert_equal(1, dataset["object"]["status"]["code"])
      assert_equal(@api.ok(dataset), true)
      
      puts "And the dataset is in the project"
      assert_equal(dataset["object"]['project'],  @project["resource"])
      
      puts "And I create model"
      model=@api.create_model(dataset)
      
      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, model["code"])
      assert_equal(1, model["object"]["status"]["code"])
      assert_equal(@api.ok(model), true)
      
      puts "And the model is in the project"
      assert_equal(model["object"]['project'],  @project["resource"])
      
      puts "When I create a prediction for %s" % JSON.generate(data_input)
      prediction = @api.create_prediction(model, data_input)
      
      assert_equal(BigML::HTTP_CREATED, prediction["code"])
      assert_equal(@api.ok(prediction), true)
      
      puts "And the prediction is in the project"
      assert_equal(prediction["object"]['project'],  @project["resource"])
      
    end
  end
  
end