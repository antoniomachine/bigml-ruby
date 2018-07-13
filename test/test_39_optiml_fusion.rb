require_relative "../lib/bigml/api"


require "test/unit"
require_relative "../lib/bigml/fusion"

class TestOptimlFusionConnection < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  #  "Scenario 1: Successfully creating an optiml from a dataset"
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 'my new optiml name']]
    puts
    puts "Scenario 1: Successfully creating an optiml from a dataset:"

    data.each do |filename, optiml_name|
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
      
      puts "And I create an optiml from a dataset"
      optiml = @api.create_optiml(dataset, {"max_training_time" =>9, 
                                            "model_types" => ["model", "logisticregression"]})                  
      puts "And I wait until the optiml is ready"
      assert_equal(BigML::HTTP_CREATED, optiml["code"])
      assert_equal(1, optiml["object"]["status"]["code"])
      assert_equal(@api.ok(optiml), true)
      
      puts "And I update the optiml name to <%s>" % optiml_name      
      optiml=@api.update_optiml(optiml['resource'], {'name' => optiml_name})
      
      puts "When I wait until the optiml is ready"
      assert_equal(BigML::HTTP_ACCEPTED, optiml["code"])
      assert_equal(@api.ok(optiml), true)
      
      puts "Then the optiml name is <%s>" % optiml_name
      assert_equal(optiml["object"]["name"], optiml_name)
      
    end
  end
  
  #  "Scenario 2: Successfully creating a fusion from a dataset"
  def test_scenario2
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 
             'my new fusion name', {"tags" => ["my_fusion_2_tag"]}, 
             "my_fusion_2_tag", {"petal width" => 1.75, "petal length" => 2.45}, 
             "000004", "Iris-setosa", 'average_phi', 1.0]]
     
    puts
    puts "Scenario 2: Successfully creating a fusion from a dataset"

    data.each do |filename, fusion_name, params, tag, data_input, objective, prediction_result, measure, measure_value|
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
      
      
      puts "And I create model with params %s" % JSON.generate(params)
      model_1=@api.create_model(dataset,  {'missing_splits' => false}.merge(params))
      
      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, model_1["code"])
      assert_equal(1, model_1["object"]["status"]["code"])
      assert_equal(@api.ok(model_1), true)
      
      puts "And I create model with params %s" % JSON.generate(params)
      model_2=@api.create_model(dataset,  {'missing_splits' => false}.merge(params))
      
      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, model_2["code"])
      assert_equal(1, model_2["object"]["status"]["code"])
      assert_equal(@api.ok(model_2), true)
      
      puts "And I create model with params %s" % JSON.generate(params)
      model_3=@api.create_model(dataset,  {'missing_splits' => false}.merge(params))
      
      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, model_3["code"])
      assert_equal(1, model_3["object"]["status"]["code"])
      assert_equal(@api.ok(model_3), true)
      
      puts "And I retrieve a list of remote models tagged with <%s>" % tag
      list_of_models = @api.list_models("tags__in=%s" % tag)['objects'].map {|model| @api.get_model(model["resource"])}
      
      puts "And I create a fusion from a list of models"
      fusion =  @api.create_fusion(list_of_models)
      
      puts "And I wait until the fusion is ready"
      assert_equal(BigML::HTTP_CREATED, fusion["code"])
      assert_equal(1, fusion["object"]["status"]["code"])
      assert_equal(@api.ok(fusion), true)

      puts "And I update the fusion name to <%s>" % fusion_name
      fusion = @api.update_fusion(fusion['resource'], {'name' => fusion_name})
      
      puts "When I wait until the fusion is ready"
      assert_equal(BigML::HTTP_ACCEPTED, fusion["code"])
      assert_equal(@api.ok(fusion), true)
      
      puts "Then the fusion name is %s" % fusion_name
      assert_equal(fusion["object"]["name"], fusion_name)
      
      puts "And I create a prediction for <%s>" % JSON.generate(data_input)
      prediction =@api.create_prediction(fusion, data_input)
      assert_equal(BigML::HTTP_CREATED, prediction["code"])
      assert_equal(@api.ok(prediction), true)
      
      puts "And the prediction for <%s> is <%s>" % [objective, prediction_result]
      assert_equal(prediction_result, prediction["object"]["prediction"][objective])
      
      puts "And I create an evaluation for the fusion with the dataset"
      evaluation = @api.create_evaluation(fusion, dataset)
      puts "And I wait until the evaluation is ready"
      assert_equal(BigML::HTTP_CREATED, prediction["code"])
      assert_equal(@api.ok(evaluation), true)
      
      puts "Then the measured <%s> is <%s>" % [measure, measure_value]
      evaluation = @api.get_evaluation(evaluation)
      assert_equal(evaluation["object"]['result']['model'][measure].to_f, measure_value.to_f)
    end
  end
  
  #  "Scenario 3: Successfully creating a fusion from a dataset"
  def test_scenario3
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 
             'my new fusion name', {"tags" => ["my_fusion_3_tag"]}, 
             "my_fusion_3_tag", File.dirname(__FILE__)+'/tmp/batch_predictions.csv', 
             File.dirname(__FILE__)+'/data/batch_predictions_fs.csv']]
    puts
    puts "Scenario 3: Successfully creating a fusion from a dataset"

    data.each do |filename, fusion_name, params, tag, local_file, predictions_file|
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
      
      
      puts "And I create model with params %s" % JSON.generate(params)
      model_1=@api.create_model(dataset,  {'missing_splits' => false}.merge(params))
      
      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, model_1["code"])
      assert_equal(1, model_1["object"]["status"]["code"])
      assert_equal(@api.ok(model_1), true)
      
      puts "And I create model with params %s" % JSON.generate(params)
      model_2=@api.create_model(dataset,  {'missing_splits' => false}.merge(params))
      
      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, model_2["code"])
      assert_equal(1, model_2["object"]["status"]["code"])
      assert_equal(@api.ok(model_2), true)
      
      puts "And I create model with params %s" % JSON.generate(params)
      model_3=@api.create_model(dataset,  {'missing_splits' => false}.merge(params))
      
      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, model_3["code"])
      assert_equal(1, model_3["object"]["status"]["code"])
      assert_equal(@api.ok(model_3), true)
      
      puts "And I retrieve a list of remote models tagged with <%s>" % tag
      list_of_models = @api.list_models("tags__in=%s" % tag)['objects'].map {|model| @api.get_model(model["resource"])}
      
      puts "And I create a fusion from a dataset"
      fusion =  @api.create_fusion(list_of_models)
      
      puts "And I wait until the fusion is ready"
      assert_equal(BigML::HTTP_CREATED, fusion["code"])
      assert_equal(1, fusion["object"]["status"]["code"])
      assert_equal(@api.ok(fusion), true)
      
      puts "I create a batch prediction for the dataset with the fusion"
      batch_prediction = @api.create_batch_prediction(fusion, dataset)
      
      puts "And I wait until the batch prediction is ready"
      assert_equal(BigML::HTTP_CREATED, batch_prediction["code"])
      assert_equal(@api.ok(batch_prediction), true)
      
      puts "And I download the created predictions file to #{local_file}"
      filename = @api.download_batch_prediction(batch_prediction, local_file)
      assert_not_nil(filename)

      puts "Then the batch prediction file is like #{predictions_file}"
      assert_equal(FileUtils.compare_file(local_file, predictions_file), true)
  
    end
  end
  
  #  "Scenario 4: Successfully creating a fusion"
  def test_scenario4
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 
             {"tags" => ["my_fusion_4_tag"], "missing_numerics" => true},
             'my_fusion_4_tag',
             {"petal width" => 1.75, "petal length" => 2.45},
             "000004",
             "Iris-setosa",
             0.4727]]
    puts
    puts "Scenario 4: Successfully creating a fusion"

    data.each do |filename, params, tag, data_input, objective, prediction_result, probability_result|
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
      
      
      puts "I create a logistic regression model with objective %s and parms %s" % [objective, JSON.generate(params)]
      logistic_1=@api.create_logisticregression(dataset,  {'objective_field' => objective}.merge(params))
      
      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, logistic_1["code"])
      assert_equal(1, logistic_1["object"]["status"]["code"])
      assert_equal(@api.ok(logistic_1), true)
      
      puts "And I create model with params %s" % JSON.generate(params)
      logistic_2=@api.create_logisticregression(dataset,  {'objective_field' => objective}.merge(params))
      
      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, logistic_2["code"])
      assert_equal(1, logistic_2["object"]["status"]["code"])
      assert_equal(@api.ok(logistic_2), true)
      
      puts "And I retrieve a list of remote logistic regression tagged with <%s>" % tag
      list_of_models = @api.list_logisticregressions("tags__in=%s" % tag)['objects'].map {|model| @api.get_logisticregression(model["resource"])}
      
      puts "And I create a fusion from a list of models"
      fusion = @api.create_fusion(list_of_models)
      
      puts "And I wait until the fusion is ready"
      assert_equal(BigML::HTTP_CREATED, fusion["code"])
      assert_equal(1, fusion["object"]["status"]["code"])
      assert_equal(@api.ok(fusion), true)
      
      puts "And I create a local fusion"
      local_fusion = BigML::Fusion.new(fusion)
      
      puts "And I create a prediction for <%s>" % JSON.generate(data_input)
      prediction =@api.create_prediction(fusion, data_input)
      assert_equal(BigML::HTTP_CREATED, prediction["code"])
      assert_equal(@api.ok(prediction), true)
      
      puts "And the prediction for <%s> is <%s>" % [objective, prediction_result]
      assert_equal(prediction_result, prediction["object"]["prediction"][objective])
      
      puts "And the probality is <%s>" % probability_result
      assert_equal(probability_result.round(4), prediction["object"]["probability"].round(4))
      
      puts "And I create a local prediction for <%s>" % JSON.generate(data_input)
      local_prediction = local_fusion.predict(data_input, {"full" => true})
      
      puts "Then the local prediction is <%s>" % probability_result

      if local_prediction.is_a?(Array)
        local_probability = local_prediction[1]
        local_prediction = local_prediction[0]
      elsif local_prediction.is_a?(Hash)
        local_probability = local_prediction['probability']
        local_prediction = local_prediction['prediction']
      else
        local_prediction = local_prediction
      end    

      assert_equal(local_prediction, prediction_result)
  
      puts "And the local probality is <%s>" % probability_result
      assert_equal(local_probability.round(4), prediction["object"]["probability"].round(4))
      
    end
  end
  
  #  "Scenario 5: Successfully creating a fusion"
  def test_scenario5
    data = [[File.dirname(__FILE__)+'/data/iris.csv',
             {"tags" => ["my_fusion_5_tag"], "missing_numerics" => true},
             'my_fusion_5_tag',
             {"petal width" => 1.75, "petal length" => 2.45},
             "000004",
             "Iris-setosa",
             0.4727,
             {"tags" =>["my_fusion_5_tag"], "missing_numerics" => false, "balance_fields" => false }]]
    puts
    puts "Scenario 5: Successfully creating a fusion from a dataset"

    data.each do |filename, params, tag, data_input, objective, prediction_result, probability_result, params2|
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
      
      
      puts "I create a logistic regression model with objective %s and parms %s" % [objective, JSON.generate(params)]
      logistic_1=@api.create_logisticregression(dataset,  {'objective_field' => objective}.merge(params))
      
      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, logistic_1["code"])
      assert_equal(1, logistic_1["object"]["status"]["code"])
      assert_equal(@api.ok(logistic_1), true)
      
      puts "And I create model with params %s" % JSON.generate(params2)
      logistic_2=@api.create_logisticregression(dataset,  {'objective_field' => objective}.merge(params2))
      
      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, logistic_2["code"])
      assert_equal(1, logistic_2["object"]["status"]["code"])
      assert_equal(@api.ok(logistic_2), true)
      
      puts "And I retrieve a list of remote logistic regression tagged with <%s>" % tag
      list_of_models = @api.list_logisticregressions("tags__in=%s" % tag)['objects'].map {|model| @api.get_logisticregression(model["resource"])}
      
      puts "And I create a fusion from a list of models"
      fusion = @api.create_fusion(list_of_models)
      
      puts "And I wait until the fusion is ready"
      assert_equal(BigML::HTTP_CREATED, fusion["code"])
      assert_equal(1, fusion["object"]["status"]["code"])
      assert_equal(@api.ok(fusion), true)
      
      puts "And I create a local fusion"
      local_fusion = BigML::Fusion.new(fusion)
      
      puts "And I create a prediction for <%s>" % JSON.generate(data_input)
      prediction =@api.create_prediction(fusion, data_input)
      assert_equal(BigML::HTTP_CREATED, prediction["code"])
      assert_equal(@api.ok(prediction), true)
      
      puts "And the prediction for <%s> is <%s>" % [objective, prediction_result]
      assert_equal(prediction_result, prediction["object"]["prediction"][objective])
      
      puts "And the probality is <%s>" % probability_result
      assert_equal(probability_result.round(4), prediction["object"]["probability"].round(4))
      
      puts "And I create a local prediction for <%s>" % JSON.generate(data_input)
      local_prediction = local_fusion.predict(data_input, {"full" => true})
      
      puts "Then the local prediction is <%s>" % probability_result

      if local_prediction.is_a?(Array)
        local_probability = local_prediction[1]
        local_prediction = local_prediction[0]
      elsif local_prediction.is_a?(Hash)
        local_probability = local_prediction['probability']
        local_prediction = local_prediction['prediction']
      else
        local_prediction = local_prediction
      end    

      assert_equal(local_prediction, prediction_result)
  
      puts "And the local probality is <%s>" % probability_result
      assert_equal(local_probability.round(4), prediction["object"]["probability"].round(4))
      
    end
  end
  
  #  "Scenario 6: Successfully creating a fusion"
  def test_scenario6
    data = [[File.dirname(__FILE__)+'/data/iris.csv',
             {"tags" => ["my_fusion_6_tag"], "missing_numerics" => true},
             'my_fusion_6_tag',
             {"petal width" => 1.75, "petal length" => 2.45},
             "000004",
             "Iris-setosa",
             0.4727,
             {"tags" =>["my_fusion_6_tag"], "missing_numerics" => false, "balance_fields" => false},
             [1, 2]]]
    puts
    puts "Scenario 6: Successfully creating a fusion from a dataset"

    data.each do |filename, params, tag, data_input, objective, prediction_result, probability_result, params2, weights|
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
      
      
      puts "I create a logistic regression model with objective %s and parms %s" % [objective, JSON.generate(params)]
      logistic_1=@api.create_logisticregression(dataset,  {'objective_field' => objective}.merge(params))
      
      puts "And I wait until the logistic model is ready"
      assert_equal(BigML::HTTP_CREATED, logistic_1["code"])
      assert_equal(1, logistic_1["object"]["status"]["code"])
      assert_equal(@api.ok(logistic_1), true)
      
      puts "I create a logistic regression model with objective %s and parms %s" % [objective, JSON.generate(params2)]
      logistic_2=@api.create_logisticregression(dataset,  {'objective_field' => objective}.merge(params2))
      
      puts "And I wait until the logistic model is ready"
      assert_equal(BigML::HTTP_CREATED, logistic_2["code"])
      assert_equal(1, logistic_2["object"]["status"]["code"])
      assert_equal(@api.ok(logistic_2), true)
      
      puts "And I retrieve a list of remote logistic regression tagged with <%s>" % tag
      list_of_models = @api.list_logisticregressions("tags__in=%s" % tag)['objects'].map {|model| @api.get_logisticregression(model["resource"])}
      
      puts "And I create a fusion from a list of models with weights"
      model_params = [{"id" => logistic_1["resource"], "weight" => weights[0]}, 
                      {"id" => logistic_2["resource"], "weight" => weights[1]}]
      
      fusion = @api.create_fusion(model_params)
      
      puts "And I wait until the fusion is ready"
      assert_equal(BigML::HTTP_CREATED, fusion["code"])
      assert_equal(1, fusion["object"]["status"]["code"])
      assert_equal(@api.ok(fusion), true)
      
      puts "And I create a local fusion"
      local_fusion = BigML::Fusion.new(fusion)
      
      puts "And I create a prediction for <%s>" % JSON.generate(data_input)
      prediction =@api.create_prediction(fusion, data_input)
      assert_equal(BigML::HTTP_CREATED, prediction["code"])
      assert_equal(@api.ok(prediction), true)
      
      puts "And the prediction for <%s> is <%s>" % [objective, prediction_result]
      assert_equal(prediction_result, prediction["object"]["prediction"][objective])
      
      puts "And the probality is <%s>" % probability_result
      assert_equal(probability_result.round(4), prediction["object"]["probability"].round(4))
      
      puts "And I create a local prediction for <%s>" % JSON.generate(data_input)
      local_prediction = local_fusion.predict(data_input, {"full" => true})
      
      puts "Then the local prediction is <%s>" % probability_result

      if local_prediction.is_a?(Array)
        local_probability = local_prediction[1]
        local_prediction = local_prediction[0]
      elsif local_prediction.is_a?(Hash)
        local_probability = local_prediction['probability']
        local_prediction = local_prediction['prediction']
      else
        local_prediction = local_prediction
      end    

      assert_equal(local_prediction, prediction_result)
  
      puts "And the local probality is <%s>" % probability_result
      assert_equal(local_probability.round(4), prediction["object"]["probability"].round(4))
      
    end
  end
  
end