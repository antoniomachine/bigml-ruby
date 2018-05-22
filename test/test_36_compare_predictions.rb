require_relative "../lib/bigml/api"
require_relative "../lib/bigml/deepnet"
require_relative "../lib/bigml/multimodel"
require_relative "../lib/bigml/ensemble"
require_relative "../lib/bigml/logistic"
require_relative "../lib/bigml/supervised"
require "test/unit"

class Test36ComparePredictions < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully comparing predictions for deepnets
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"petal width" => 4}, '000004', 'Iris-virginica', {}],
            [File.dirname(__FILE__)+'/data/iris.csv', {"sepal length" => 4.1, "sepal width" => 2.4}, '000004', 'Iris-setosa', {}],
            [File.dirname(__FILE__)+'/data/iris_missing2.csv', {}, '000004', 'Iris-setosa', {}],
            [File.dirname(__FILE__)+'/data/grades.csv', {}, '000005', 42.15474, {}],
            [File.dirname(__FILE__)+'/data/spam.csv', {}, '000000', 'ham', {}]
           ]
    puts
    puts "Scenario: Successfully comparing predictions for deepnets"

    data.each do |filename, data_input, objective, prediction_result, params|
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
      
       puts "And I create a deepnet with objective <%s> and <%s>" % [objective, JSON.generate(params)]
       deepnet = @api.create_deepnets(dataset, params.merge({"objective_field" => objective}))
           
       puts "And I wait until the deepnet is ready"
       assert_equal(BigML::HTTP_CREATED, deepnet["code"])
       assert_equal(@api.ok(deepnet), true)
       
       puts "And I create a local deepnet"
       local_deepnet = BigML::Deepnet.new(deepnet['resource'])
       
       puts " When I create a prediction for <%s>" % [JSON.generate(data_input)]
       prediction = @api.create_prediction(deepnet['resource'], data_input)

       puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
       
       if !prediction['object']['prediction'][objective].is_a?(String)
         assert_equal(prediction['object']['prediction'][objective].to_f.round(5), prediction_result.to_f.round(5))
       else
         assert_equal(prediction['object']['prediction'][objective], prediction_result)
       end    
      
       puts "And I create a local prediction for <%s>" % JSON.generate(data_input)
       local_prediction = local_deepnet.predict(data_input)
       
       puts "Then the local prediction is <%s>" % prediction_result
       
       if local_prediction.is_a?(Array)
         local_prediction = local_prediction[0]
       elsif local_prediction.is_a?(Hash)
         local_prediction = local_prediction['prediction']
       else
         local_prediction = local_prediction
       end    
       
       if (local_deepnet.regression) or 
          (local_deepnet.is_a?(BigML::MultiModel) and local_deepnet.models[0].regression)
          assert_equal(local_prediction.to_f.round(4), prediction_result.to_f.round(4))
       else
         assert_equal(local_prediction, prediction_result)
       end   
       
    end
  end
  
  # Scenario: Successfully comparing predictions in operating points for models
  def test_scenario2
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"petal width" => 4}, 'Iris-setosa', {"kind" => "probability", "threshold" => 0.1, "positive_class" => "Iris-setosa"}, "000004"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"petal width" => 4}, 'Iris-versicolor', {"kind" => "probability", "threshold" => 0.9, "positive_class" => "Iris-setosa"}, "000004"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"sepal length" => 4.1, "sepal width" => 2.4}, 'Iris-setosa', {"kind" => "confidence", "threshold" => 0.1, "positive_class" => "Iris-setosa"}, "000004"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"sepal length" => 4.1, "sepal width" => 2.4}, 'Iris-versicolor', {"kind" => "confidence", "threshold" => 0.9, "positive_class" => "Iris-setosa"}, "000004"]
           ]
    puts
    puts "Scenario : Successfully comparing predictions in operating points for models"

    data.each do |filename, data_input, prediction_result, operating_point, objective|
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
       
       puts "And I create model"
       model=@api.create_model(dataset)
       
       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)
       
       puts "And I create a local model"
       local_model = BigML::Model.new(model, @api)

       puts "When I create a prediction for %s in %s " % [JSON.generate(data_input), JSON.generate(operating_point)]
       prediction = @api.create_prediction(model, data_input, {"operating_point" => operating_point})
       
       assert_equal(BigML::HTTP_CREATED, prediction["code"])
       assert_equal(@api.ok(prediction), true)

       puts "Then the prediction for '<%s>' is '<%s>'" % [objective, prediction_result]
       
       if !prediction['object']['prediction'][objective].is_a?(String)
         assert_equal(prediction['object']['prediction'][objective].to_f.round(5), prediction_result.to_f.round(5))
       else
         assert_equal(prediction['object']['prediction'][objective], prediction_result)
       end

       puts "And I create a local prediction for <%s> in <%s>" % [JSON.generate(data_input), JSON.generate(operating_point)]
       local_prediction = local_model.predict(data_input, {"operating_point" => operating_point})
       
       puts "Then the local prediction is <%s>" % prediction_result
       
       if local_prediction.is_a?(Array)
         local_prediction = local_prediction[0]
       elsif local_prediction.is_a?(Hash)
         local_prediction = local_prediction['prediction']
       else
         local_prediction = local_prediction
       end    
       
       if (local_model.regression) or 
          (local_model.is_a?(BigML::MultiModel) and local_model.models[0].regression)
          assert_equal(local_prediction.to_f.round(4), prediction_result.to_f.round(4))
       else
         assert_equal(local_prediction, prediction_result)
       end  
       
    end
    
  end
  
  # Scenario: Successfully comparing predictions for deepnets with operating point
  def test_scenario3
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"petal width" => 4}, '000004', 'Iris-versicolor', {}, {"kind" => "probability", "threshold" => 1, "positive_class" => "Iris-virginica"}],
           ]
    puts
    puts "Scenario: Successfully comparing predictions for deepnets with operating point"

    data.each do |filename, data_input, objective, prediction_result, params, operating_point|
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
      
       puts "And I create a deepnet with objective <%s> and <%s>" % [objective, JSON.generate(params)]
       deepnet = @api.create_deepnets(dataset, params.merge({"objective_field" => objective}))
           
       puts "And I wait until the deepnet is ready"
       assert_equal(BigML::HTTP_CREATED, deepnet["code"])
       assert_equal(@api.ok(deepnet), true)
       
       puts "And I create a local deepnet"
       local_deepnet = BigML::Deepnet.new(deepnet['resource'])
       
       puts " When I create a prediction for <%s>" % [JSON.generate(data_input)]
       prediction = @api.create_prediction(deepnet['resource'], data_input, {"operating_point" => operating_point})

       puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
       
       if !prediction['object']['prediction'][objective].is_a?(String)
         assert_equal(prediction['object']['prediction'][objective].to_f.round(5), prediction_result.to_f.round(5))
       else
         assert_equal(prediction['object']['prediction'][objective], prediction_result)
       end    
      
       puts "And I create a local prediction for <%s>" % JSON.generate(data_input)
       local_prediction = local_deepnet.predict(data_input,  {"operating_point" => operating_point})
       
       puts "Then the local prediction is <%s>" % prediction_result
       
       if local_prediction.is_a?(Array)
         local_prediction = local_prediction[0]
       elsif local_prediction.is_a?(Hash)
         local_prediction = local_prediction['prediction']
       else
         local_prediction = local_prediction
       end    
       
       if (local_deepnet.regression) or 
          (local_deepnet.is_a?(BigML::MultiModel) and local_deepnet.models[0].regression)
          assert_equal(local_prediction.to_f.round(4), prediction_result.to_f.round(4))
       else
         assert_equal(local_prediction, prediction_result)
       end   
       
    end
  end
  
  # Scenario: Successfully comparing predictions in operating points for ensembles
  def test_scenario4
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"petal width" => 4}, 'Iris-setosa', {"kind" => "probability", "threshold" => 0.1, "positive_class" => "Iris-setosa"}, "000004"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"petal width" => 4}, 'Iris-virginica', {"kind" => "probability", "threshold" => 0.9, "positive_class" => "Iris-setosa"}, "000004"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"sepal length" => 4.1, "sepal width"=> 2.4}, 'Iris-setosa', {"kind" => "confidence", "threshold" => 0.1, "positive_class" => "Iris-setosa"}, "000004"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"sepal length" => 4.1, "sepal width"=> 2.4}, 'Iris-versicolor', {"kind" => "confidence", "threshold" => 0.9, "positive_class" => "Iris-setosa"}, "000004"]
           ]
    puts
    puts "Successfully comparing predictions in operating points for ensembles"

    data.each do |filename, data_input, prediction_result, operating_point, objective|
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
       
       puts "And I create an ensemble"
       ensemble = @api.create_ensemble(dataset, {"number_of_models"=> 2, "seed" => 'BigML', 'ensemble_sample'=>{'rate' => 0.7, 'seed' => 'BigML'}, 'missing_splits' => false})
       
       puts "And I wait until the ensemble is ready"
       assert_equal(BigML::HTTP_CREATED, ensemble["code"])
       assert_equal(1, ensemble["object"]["status"]["code"])
       assert_equal(@api.ok(ensemble), true)
       
       puts "And I create a local ensemble"
       local_ensemble = BigML::Ensemble.new(ensemble, @api)
       local_model = BigML::Model.new(local_ensemble.model_ids[0], @api)
       
       puts " When I create a prediction for <%s>" % [JSON.generate(data_input)]
       prediction = @api.create_prediction(ensemble['resource'], data_input, {"operating_point" => operating_point})
       
       assert_equal(BigML::HTTP_CREATED, prediction["code"])
       assert_equal(@api.ok(prediction), true)
       
       
       puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
       
       if !prediction['object']['prediction'][objective].is_a?(String)
         assert_equal(prediction['object']['prediction'][objective].to_f.round(5), prediction_result.to_f.round(5))
       else
         assert_equal(prediction['object']['prediction'][objective], prediction_result)
       end    
      
       puts "And I create a local prediction for <%s>" % JSON.generate(data_input)
       local_prediction = local_ensemble.predict(data_input,  {"operating_point" => operating_point})
       
       puts "Then the local prediction is <%s>" % prediction_result
       
       if local_prediction.is_a?(Array)
         local_prediction = local_prediction[0]
       elsif local_prediction.is_a?(Hash)
         local_prediction = local_prediction['prediction']
       else
         local_prediction = local_prediction
       end    
       
       if (local_ensemble.regression) or 
          (local_ensemble.is_a?(BigML::MultiModel) and local_ensemble.models[0].regression)
          assert_equal(local_prediction.to_f.round(4), prediction_result.to_f.round(4))
       else
         assert_equal(local_prediction, prediction_result)
       end 
       
    end
  end 
  
  # Scenario: Successfully comparing predictions in operating kind for models:
  def test_scenario5
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2.46, "sepal length" => 5}, 'Iris-versicolor', "probability", "000004"],
           [File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2.46, "sepal length" => 5}, 'Iris-versicolor', "confidence", "000004"],
           [File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2}, 'Iris-setosa', "probability", "000004"],
           [File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2}, 'Iris-setosa', "confidence", "000004"],
           ]
    puts
    puts "Scenario: Successfully comparing predictions in operating kind for models:"

    data.each do |filename, data_input, prediction_result, operating_kind, objective|
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
       
       puts "And I create model"
       model=@api.create_model(dataset)
       
       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)
       
       puts "And I create a local model"
       local_model = BigML::Model.new(model, @api)

       puts "When I create a prediction for %s in %s " % [JSON.generate(data_input), JSON.generate(operating_kind)]
       prediction = @api.create_prediction(model, data_input, {"operating_kind" => operating_kind})
       
       assert_equal(BigML::HTTP_CREATED, prediction["code"])
       assert_equal(@api.ok(prediction), true)

       puts "Then the prediction for '<%s>' is '<%s>'" % [objective, prediction_result]
       
       if !prediction['object']['prediction'][objective].is_a?(String)
         assert_equal(prediction['object']['prediction'][objective].to_f.round(5), prediction_result.to_f.round(5))
       else
         assert_equal(prediction['object']['prediction'][objective], prediction_result)
       end

       puts "And I create a local prediction for <%s> in <%s>" % [JSON.generate(data_input), JSON.generate(operating_kind)]
       local_prediction = local_model.predict(data_input, {"operating_kind" => operating_kind})
       
       puts "Then the local prediction is <%s>" % prediction_result
       
       if local_prediction.is_a?(Array)
         local_prediction = local_prediction[0]
       elsif local_prediction.is_a?(Hash)
         local_prediction = local_prediction['prediction']
       else
         local_prediction = local_prediction
       end    
       
       if (local_model.regression) or 
          (local_model.is_a?(BigML::MultiModel) and local_model.models[0].regression)
          assert_equal(local_prediction.to_f.round(4), prediction_result.to_f.round(4))
       else
         assert_equal(local_prediction, prediction_result)
       end  
       
    end
    
  end 
  
  # Scenario: Successfully comparing predictions for deepnets with operating kind
  def test_scenario6
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2.46}, '000004', 'Iris-setosa', {}, "probability"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2}, '000004', 'Iris-setosa', {}, "probability"],
           ]
           
    puts
    puts "Scenario: Successfully comparing predictions for deepnets with operating kind"

    data.each do |filename, data_input, objective, prediction_result, params, operating_kind|
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
      
       puts "And I create a deepnet with objective <%s> and <%s>" % [objective, JSON.generate(params)]
       deepnet = @api.create_deepnets(dataset, params.merge({"objective_field" => objective}))
           
       puts "And I wait until the deepnet is ready"
       assert_equal(BigML::HTTP_CREATED, deepnet["code"])
       assert_equal(@api.ok(deepnet), true)
       
       puts "And I create a local deepnet"
       local_deepnet = BigML::Deepnet.new(deepnet['resource'])
       
       puts " When I create a prediction for <%s>" % [JSON.generate(data_input)]
       prediction = @api.create_prediction(deepnet['resource'], data_input, {"operating_kind" => operating_kind})

       puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
       
       if !prediction['object']['prediction'][objective].is_a?(String)
         assert_equal(prediction['object']['prediction'][objective].to_f.round(5), prediction_result.to_f.round(5))
       else
         assert_equal(prediction['object']['prediction'][objective], prediction_result)
       end    

       puts "And I create a local prediction for <%s>" % JSON.generate(data_input)
       local_prediction = local_deepnet.predict(data_input,{"operating_kind" => operating_kind})
       
       puts "Then the local prediction is <%s>" % prediction_result
       
       if local_prediction.is_a?(Array)
         local_prediction = local_prediction[0]
       elsif local_prediction.is_a?(Hash)
         local_prediction = local_prediction['prediction']
       else
         local_prediction = local_prediction
       end    
       
       if (local_deepnet.regression) or 
          (local_deepnet.is_a?(BigML::MultiModel) and local_deepnet.models[0].regression)
          assert_equal(local_prediction.to_f.round(4), prediction_result.to_f.round(4))
       else
         assert_equal(local_prediction, prediction_result)
       end   
       
    end
  end
  
  # Scenario: Successfully comparing predictions in operating points for ensembles
  def test_scenario7

    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2.46}, 'Iris-versicolor', "probability", "000004"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2}, 'Iris-setosa', "probability", "000004"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2.46}, 'Iris-versicolor', "confidence", "000004"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2}, 'Iris-setosa', "confidence", "000004"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2.46}, 'Iris-versicolor', "votes", "000004"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 1}, 'Iris-setosa', "votes", "000004"]
           ]
    puts
    puts "Successfully comparing predictions in operating points for ensembles"

    data.each do |filename, data_input, prediction_result, operating_kind, objective|
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
       
       puts "And I create an ensemble"
       ensemble = @api.create_ensemble(dataset, {"number_of_models"=> 2, "seed" => 'BigML', 'ensemble_sample'=>{'rate' => 0.7, 'seed' => 'BigML'}, 'missing_splits' => false})
       
       puts "And I wait until the ensemble is ready"
       assert_equal(BigML::HTTP_CREATED, ensemble["code"])
       assert_equal(1, ensemble["object"]["status"]["code"])
       assert_equal(@api.ok(ensemble), true)
       
       puts "And I create a local ensemble"
       local_ensemble = BigML::Ensemble.new(ensemble, @api)
       local_model = BigML::Model.new(local_ensemble.model_ids[0], @api)
       
       puts "When I create a prediction for <%s>" % [JSON.generate(data_input)]
       prediction = @api.create_prediction(ensemble['resource'], data_input, {"operating_kind" => operating_kind})
       
       assert_equal(BigML::HTTP_CREATED, prediction["code"])
       assert_equal(@api.ok(prediction), true)

       puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
       
       if !prediction['object']['prediction'][objective].is_a?(String)
         assert_equal(prediction['object']['prediction'][objective].to_f.round(5), prediction_result.to_f.round(5))
       else
         assert_equal(prediction['object']['prediction'][objective], prediction_result)
       end    
      
       puts "And I create a local prediction for <%s>" % JSON.generate(data_input)
       local_prediction = local_ensemble.predict(data_input,  {"operating_kind" => operating_kind})
       
       puts "Then the local prediction is <%s>" % prediction_result
       
       if local_prediction.is_a?(Array)
         local_prediction = local_prediction[0]
       elsif local_prediction.is_a?(Hash)
         local_prediction = local_prediction['prediction']
       else
         local_prediction = local_prediction
       end    
       
       if (local_ensemble.regression) or 
          (local_ensemble.is_a?(BigML::MultiModel) and local_ensemble.models[0].regression)
          assert_equal(local_prediction.to_f.round(4), prediction_result.to_f.round(4))
       else
         assert_equal(local_prediction, prediction_result)
       end 
       
    end
  end 
  
  # Scenario: Successfully comparing predictions for logistic regressions with operating kind
  def test_scenario8
    
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 5}, "000004", 'Iris-versicolor', {}, "probability"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2}, "000004", 'Iris-setosa', {}, "probability" ]
           ]
    puts
    puts "Scenario: Successfully comparing predictions for logistic regressions with operating kind"

    data.each do |filename, data_input, objective, prediction_result, params, operating_point|
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
    
       puts "And I create a logistic regression with objective" 
       logisticregression=@api.create_logisticregression(dataset)

       puts "And I wait until the logistic regression is ready"
       assert_equal(BigML::HTTP_CREATED, logisticregression["code"])
       assert_equal(1, logisticregression["object"]["status"]["code"])
       assert_equal(@api.ok(logisticregression), true)
       
       puts "And I create a local logistic regression"
       localLogisticRegression = BigML::Logistic.new(logisticregression)

       puts "When I create a prediction for <%s>" % [JSON.generate(data_input)]
       prediction = @api.create_prediction(logisticregression['resource'], data_input, {"operating_kind" => operating_point})
       
       assert_equal(BigML::HTTP_CREATED, prediction["code"])
       assert_equal(@api.ok(prediction), true)

       puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
       
       if !prediction['object']['prediction'][objective].is_a?(String)
         assert_equal(prediction['object']['prediction'][objective].to_f.round(5), prediction_result.to_f.round(5))
       else
         assert_equal(prediction['object']['prediction'][objective], prediction_result)
       end
      
       puts "And I create a local prediction for <%s>" % JSON.generate(data_input)
       local_prediction = localLogisticRegression.predict(data_input,  {"operating_kind" => operating_point})
       
       puts "Then the local prediction is <%s>" % prediction_result
       
       if local_prediction.is_a?(Array)
         local_prediction = local_prediction[0]
       elsif local_prediction.is_a?(Hash)
         local_prediction = local_prediction['prediction']
       else
         local_prediction = local_prediction
       end    

       assert_equal(local_prediction, prediction_result)
       
    end
   
  end
  
  # Successfully comparing predictions for logistic regressions with operating kind and supervised model:
  def test_scenario9
    
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 5}, "000004", 'Iris-versicolor', {}, "probability"],
            [File.dirname(__FILE__)+'/data/iris.csv', {"petal length" => 2}, "000004", 'Iris-setosa', {}, "probability" ]
           ]
    puts
    puts "Scenario: Successfully comparing predictions for logistic regressions with operating kind and supervised model:"

    data.each do |filename, data_input, objective, prediction_result, params, operating_kind|
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
    
       puts "And I create a logistic regression with objective" 
       logisticregression=@api.create_logisticregression(dataset)

       puts "And I wait until the logistic regression is ready"
       assert_equal(BigML::HTTP_CREATED, logisticregression["code"])
       assert_equal(1, logisticregression["object"]["status"]["code"])
       assert_equal(@api.ok(logisticregression), true)
       
       puts "And I create a local logistic regression"
       localSupervisedModel = BigML::SupervisedModel.new(logisticregression)

       puts "When I create a prediction for <%s>" % [JSON.generate(data_input)]
       prediction = @api.create_prediction(logisticregression['resource'], data_input, {"operating_kind" => operating_kind})
       
       assert_equal(BigML::HTTP_CREATED, prediction["code"])
       assert_equal(@api.ok(prediction), true)

       puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
       
       if !prediction['object']['prediction'][objective].is_a?(String)
         assert_equal(prediction['object']['prediction'][objective].to_f.round(5), prediction_result.to_f.round(5))
       else
         assert_equal(prediction['object']['prediction'][objective], prediction_result)
       end
      
       puts "And I create a local prediction for <%s>" % JSON.generate(data_input)
       local_prediction = localSupervisedModel.predict(data_input, {"operating_kind" => operating_kind})
       
       puts "Then the local prediction is <%s>" % prediction_result
       
       if local_prediction.is_a?(Array)
         local_prediction = local_prediction[0]
       elsif local_prediction.is_a?(Hash)
         local_prediction = local_prediction['prediction']
       else
         local_prediction = local_prediction
       end    

       assert_equal(local_prediction, prediction_result)
       
    end
   
  end
end