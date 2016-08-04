require_relative "../lib/bigml/api"
require_relative "../lib/bigml/model"

require "test/unit"

class TestPublicModelPrediction < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new(nil, nil)
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating a prediction using a public model
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"petal width" => 0.5}, '000004', 'Iris-setosa']]

    puts 
    puts "Scenario: Successfully creating a prediction using a public model"

    data.each do |filename, data_input, objective, prediction_result|
       puts 
       puts "Given I create a data source uploading a %s file" % filename
       source = @api.create_source(filename, {'name'=> 'source_test', 'project'=> @project["resource"]})
  
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

       puts "And I make the model public"
       model = @api.update_model(model, {'private'=> false, 'white_box' => true})

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_ACCEPTED, model["code"])
       assert_equal(@api.ok(model), true)

       puts "And I check the model status using the model's public url"
       model = @api.get_model("public/%s" % model["resource"])
       assert_equal(BigML::FINISHED, model["object"]["status"]["code"]) 

       puts "When I create a prediction for <%s>" % JSON.generate(data_input)
       prediction = @api.create_prediction(model, data_input)
       assert_equal(BigML::HTTP_CREATED, prediction["code"])

       puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
       assert_equal(prediction_result, prediction["object"]["prediction"][objective])

       puts "And I make the model private again"
       model = @api.update_model(model, {'private'=> true, 'white_box' => true})
       assert_equal(BigML::HTTP_ACCEPTED, model["code"])
 
    end

  end

  # Scenario: Successfully creating a prediction using a shared model
  def test_scenario2
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"petal width" => 0.5}, 'Iris-setosa']]

    puts
    puts "Scenario: Successfully creating a prediction using a shared model"

    data.each do |filename, data_input, prediction_result|
       puts
       puts
       puts "Given I create a data source uploading a %s file" % filename
       source = @api.create_source(filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

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

       puts "And I make the model shared"
       model = @api.update_model(model, {'shared'=> true})

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_ACCEPTED, model["code"])
       assert_equal(@api.ok(model), true)

       shared_hash = model["object"]["shared_hash"]
       sharing_key = model["object"]["sharing_key"]

       puts "I check the model status using the model\'s shared url"
       model = @api.get_model("shared/model/%s" % shared_hash)
       assert_equal(BigML::FINISHED, model["object"]["status"]["code"])

       puts "I check the model status using the model\'s shared key"
       model = @api.get_model(model, nil, ENV["BIGML_USERNAME"], sharing_key)

       assert_equal(BigML::FINISHED, model["object"]["status"]["code"])

       puts "And I create a local model"
       local_model = BigML::Model.new(model, @api)

       puts "When I create a local prediction for %s" % JSON.generate(data_input)
       prediction = local_model.predict(data_input)

       puts "Then the prediction for is %s" % prediction_result
       assert_equal(prediction, prediction_result)
 
    end
  end

end  
