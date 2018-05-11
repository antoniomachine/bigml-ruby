require "test/unit"
require_relative "../lib/bigml/api"
require_relative "../lib/bigml/ensemble"

class TestEnsemblePrediction < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating a prediction:
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 5, 1, {"petal width" => 0.5}, 'Iris-versicolor', 0.415, [0.3403, 0.4150, 0.2447]]]

    puts  
    puts "Scenario: Successfully creating a local prediction from an Ensemble"

    data.each do |filename, number_of_models, tlp, data_input, prediction_result, confidence, probabilities_result|
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

       puts "And I create an ensemble of <%s> models and <%s> tlp" % [number_of_models, tlp]
       
       ensemble = @api.create_ensemble(dataset, {"number_of_models"=> number_of_models, 
                                                 "seed" => 'BigML', 
                                                 'ensemble_sample'=>{'rate' => 0.7, 
                                                                     'seed' => 'BigML'}, 
                                                 'missing_splits' => false})
       puts "And I wait until the ensemble is ready"
       assert_equal(BigML::HTTP_CREATED, ensemble["code"])
       assert_equal(1, ensemble["object"]["status"]["code"])
       assert_equal(@api.ok(ensemble), true)

       puts "And I create a local Ensemble"
       local_ensemble = BigML::Ensemble.new(ensemble, @api)
       puts "When I create a local ensemble prediction with confidence for <%s>" % JSON.generate(data_input)

       prediction = local_ensemble.predict(data_input, {'full' => true}) 

       puts "Then the local prediction is <%s>" % prediction_result
       assert_equal(prediction_result, prediction["prediction"])

       puts "And the local prediction's confidence is <%s>" % confidence
       assert_equal(confidence, prediction.key?("confidence") ? 
                                    prediction["confidence"].round(4) : 
                                    prediction["probability"].round(4))

       probabilities = local_ensemble.predict_probability(data_input, BigML::LAST_PREDICTION, true)
       
       puts "And the local probabilities are <%s>" % JSON.generate(probabilities_result)
       assert_equal(probabilities.map{|it| it.round(4)},probabilities_result.map{|it| it.round(4)})

    end

  end

  def test_scenario2

    data = [
            [File.dirname(__FILE__)+'/data/iris.csv', {"input_fields" => ["000000", "000001","000003", "000004"]}, {"input_fields" => ["000000", "000001","000002", "000004"]}, {"input_fields" => ["000000", "000001","000002", "000003", "000004"]}, 3, [["000002", 0.5269933333333333], ["000003", 0.38936], ["000000", 0.04662333333333333], ["000001", 0.037026666666666666]]]
           ]

    puts
    puts "Scenario: Successfully obtaining field importance from an Ensemble" 

    data.each do |filename, parms1, parms2, parms3, number_of_models, field_importance|
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

       puts "And I create a model with <%s>" % JSON.generate(parms1)
       model_1 = @api.create_model(dataset, parms1)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model_1["code"])
       assert_equal(1, model_1["object"]["status"]["code"])
       assert_equal(@api.ok(model_1), true)

       puts "And I create a model with <%s>" % JSON.generate(parms2)
       model_2 = @api.create_model(dataset, parms2)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model_2["code"])
       assert_equal(1, model_2["object"]["status"]["code"])
       assert_equal(@api.ok(model_2), true)

       puts "And I create a model with <%s>" % JSON.generate(parms3)
       model_3 = @api.create_model(dataset, parms3)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model_3["code"])
       assert_equal(1, model_3["object"]["status"]["code"])
       assert_equal(@api.ok(model_3), true)

       puts "When I create a local Ensemble with the last <%s> models" % number_of_models

       local_ensemble = BigML::Ensemble.new([model_1, model_2, model_3], @api, number_of_models)

       puts "Then the field importance text is <%s>" % JSON.generate(field_importance)
       field_importance_data = local_ensemble.field_importance_data()

       assert_equal(field_importance, field_importance_data[0])

    end

  end

  def test_scenario3
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 5, 1, {"petal width" => 0.5}, 'Iris-versicolor', 0.415]]

    puts
    puts "Scenario: Successfully creating a local prediction from an Ensemble adding confidence" 

    data.each do |filename, number_of_models, tlp, data_input, prediction_result, confidence|
       puts
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

       puts "And I create an ensemble of <%s> models and <%s> tlp" % [number_of_models, tlp]
       ensemble = @api.create_ensemble(dataset, {"number_of_models"=> number_of_models, 
                                                 "seed" => 'BigML', 
                                                 'ensemble_sample'=>{'rate' => 0.7, 
                                                                     'seed' => 'BigML'}, 
                                                 'missing_splits' => false})

       puts "And I wait until the ensemble is ready"
       assert_equal(BigML::HTTP_CREATED, ensemble["code"])
       assert_equal(1, ensemble["object"]["status"]["code"])
       assert_equal(@api.ok(ensemble), true)
     
       puts "And I create a local Ensemble"
       local_ensemble = BigML::Ensemble.new(ensemble, @api)

       puts "When I create a local ensemble prediction for <%s> in JSON adding confidence" % JSON.generate(data_input)

       prediction = local_ensemble.predict(data_input, {'full' => true})

       puts "Then the local prediction is <%s>" % prediction_result
       assert_equal(prediction_result, prediction['prediction'])
 
       puts "And the local prediction's confidence is <%s>" % confidence
       assert_equal(confidence, prediction.key?("confidence") ? 
                        prediction['confidence'].round(4) : prediction['probability'].round(4))
    end

  end

  def test_scenario4
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"input_fields" => ["000000", "000001","000003", "000004"]},  {"input_fields" => ["000000", "000001","000002", "000004"]}, {"input_fields" => ["000000", "000001","000002", "000003", "000004"]}, 3, [["000002", 0.5269933333333333], ["000003", 0.38936], ["000000", 0.04662333333333333], ["000001", 0.037026666666666666]]]]

    puts
    puts "Scenario: Successfully obtaining field importance from an Ensemble created from local models" 

    data.each do |filename,parms1,parms2,parms3,number_of_models,field_importance|
       puts
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

       puts "And I create a model with <%s>" % JSON.generate(parms1)
       model_1 = @api.create_model(dataset, parms1)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model_1["code"])
       assert_equal(1, model_1["object"]["status"]["code"])
       assert_equal(@api.ok(model_1), true)

       puts "And I create a model with <%s>" % JSON.generate(parms2)
       model_2 = @api.create_model(dataset, parms2)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model_2["code"])
       assert_equal(1, model_2["object"]["status"]["code"])
       assert_equal(@api.ok(model_2), true)

       puts "And I create a model with <%s>" % JSON.generate(parms3)
       model_3 = @api.create_model(dataset, parms3)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model_3["code"])
       assert_equal(1, model_3["object"]["status"]["code"])
       assert_equal(@api.ok(model_3), true)

       puts "When I create a local Ensemble with the last <%s> local models" % number_of_models
       local_ensemble = BigML::Ensemble.new([model_1, model_2, model_3], @api) 
       
       puts "Then the field importance text is <%s>" % JSON.generate(field_importance)
       field_importance_data = local_ensemble.field_importance_data()
       assert_equal(field_importance, field_importance_data[0])

    end

  end

  def test_scenario5
    data = [[File.dirname(__FILE__)+'/data/grades.csv', 2, 1, {}, 69.0934]]

    puts
    puts "Scenario: Successfully creating a local prediction from an Ensemble" 

    data.each do |filename, number_of_models, tlp, data_input, prediction_result|
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

       ensemble = @api.create_ensemble(dataset, {"number_of_models"=> number_of_models, 
                                                 "seed" => 'BigML', 
                                                 'ensemble_sample'=>{'rate' => 0.7, 
                                                                     'seed' => 'BigML'}, 
                                                 'missing_splits' => false})

       puts "And I wait until the ensemble is ready"
       assert_equal(BigML::HTTP_CREATED, ensemble["code"])
       assert_equal(1, ensemble["object"]["status"]["code"])
       assert_equal(@api.ok(ensemble), true)

       puts "And I create a local Ensemble"
       local_ensemble = BigML::Ensemble.new(ensemble, @api)

       puts "When I create a local ensemble prediction using median with confidence for <%s>" % data_input
       prediction = local_ensemble.predict(data_input, {'full' => true})

       puts "Then the local prediction is <%s>" % prediction_result
       assert_equal(prediction_result, prediction["prediction"].round(4))

    end

  end

end

