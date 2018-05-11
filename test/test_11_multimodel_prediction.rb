require_relative "../lib/bigml/api"
require_relative "../lib/bigml/multimodel"

require "test/unit"

class TestMultimodelPrediction < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating a prediction from a multi model 
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"tags" => ["mytag"]}, 'mytag', {"petal width" => 0.5}, 'Iris-setosa']]

    puts 
    puts "Scenario: Successfully creating a prediction from a multi model"

    data.each do |filename,params,tag,data_input,prediction_result|
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

       list_of_models = []
       puts "And I create model with params %s" % JSON.generate(params)
       model=@api.create_model(dataset, params)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)

       list_of_models << model 
       puts "And I create model with params %s" % JSON.generate(params)
       model=@api.create_model(dataset, params)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true) 

       list_of_models << model

       puts "And I create model with params %s" % JSON.generate(params)
       model=@api.create_model(dataset, params)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)

       list_of_models << model

       print "And I create a local multi model"
       local_multimodel = BigML::MultiModel.new(list_of_models, @api)

       print "When I create a local prediction for <%s>" % data_input
       prediction = local_multimodel.predict(data_input)

       print "Then the prediction is <%s>" % prediction
       assert_equal(prediction, prediction_result)

    end

  end

  # Scenario: Successfully creating a local batch prediction from a multi model
  def test_scenario2
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"tags" => ["mytag"]}, 'mytag', [{"petal width" => 0.5}, {"petal length" => 6, "petal width" => 2}], ["Iris-setosa", "Iris-virginica"]]]

    puts
    puts "Scenario: Successfully creating a local batch prediction from a multi model"

    data.each do |filename, params, tag, data_inputs, predictions_result|
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

       list_of_models = []
       puts "And I create model with params %s" % JSON.generate(params)
       model=@api.create_model(dataset, params)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)

       list_of_models << model

       puts "And I create model with params %s" % JSON.generate(params)
       model=@api.create_model(dataset, params)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)

       list_of_models << model

       puts "And I create model with params %s" % JSON.generate(params)
       model=@api.create_model(dataset, params)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)

       list_of_models << model

       puts "And I create a local multi model"
       local_multimodel = BigML::MultiModel.new(list_of_models, @api)

       puts "When I create a batch multimodel prediction for <%s>" % JSON.generate(data_inputs)
       predictions = local_multimodel.batch_predict(data_inputs, nil, false, 
                                                    BigML::LAST_PREDICTION, nil,
                                                    false, false)
       i=0
       predictions.each do |multivote|
          multivote.predictions.each do |prediction|
              assert_equal(prediction["prediction"], predictions_result[i])
          end
          i+=1
       end

       assert_equal(i, predictions_result.size)
 
    end

  end

end

