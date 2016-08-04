require "test/unit"
require_relative "../lib/bigml/api"
require_relative "../lib/bigml/multimodel"

class TestMultimodelBatchPrediction < Test::Unit::TestCase

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
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"tags" => ["mytag"]}, 'mytag', [{"petal width" => 0.5}, {"petal length" => 6, "petal width" => 2}, {"petal length" => 4, "petal width" => 1.5}], './tmp', ["Iris-setosa", "Iris-virginica", "Iris-versicolor"]]]

    puts 
    puts "Scenario: Successfully creating a batch prediction from a multi model"

    data.each do |filename, params, tag, data_input, path, predictions|
       puts
       puts "Given I create a data source uploading a <%s> file" % filename
       source = @api.create_source(filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

       puts "And I wait until the source is ready"
       assert_equal(BigML::HTTP_CREATED, source["code"])
       assert_equal(1, source["object"]["status"]["code"])
       assert_equal(@api.ok(source), true)

       puts "And I create a dataset"
       dataset=@api.create_dataset(source)

       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)

       list_of_models = []
 
       puts "And I create a model with <%s> " % JSON.generate(params)
       model=@api.create_model(dataset, params)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)

       list_of_models << model

       puts "And I create a model with <%s> " % JSON.generate(params)
       model=@api.create_model(dataset, params)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)

       list_of_models << model 
  
       puts "And I create a model with <%s> " % JSON.generate(params)
       model=@api.create_model(dataset, params)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)

       list_of_models << model 

       puts "And I create a local multi model"
       local_multimodel = BigML::MultiModel.new(list_of_models)

       if (!File.directory?(path))
          Dir.mkdir path
       end

       puts "When I create a batch prediction for <%s> and save it in <path>" % [data_input, path]
       batch_predict = local_multimodel.batch_predict(data_input, path)

       puts "And I combine the votes in <%s>" % [path]
       votes=local_multimodel.batch_votes(path)

       puts "Then the plurality combined predictions are <%s>" % JSON.generate(predictions)
       i=0

       votes.each do |vote|
          assert_equal(predictions[i], vote.combine()) 
          i+=1
       end
      
       puts "And the confidence weighted predictions are <%s>" % JSON.generate(predictions)
       i=0
       votes.each do |vote|
          assert_equal(predictions[i], vote.combine(1))
          i+=1
       end

    end

  end

end

