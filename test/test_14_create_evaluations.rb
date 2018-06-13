require_relative "../lib/bigml/api"
require "test/unit"

class TestCreateEvaluations < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating an evaluation 
  def test_scenario1
    data = [{'filename' => File.dirname(__FILE__)+'/data/iris.csv',
             'measure' => 'average_phi',
             'value' => 1}]

    puts 
    puts "Scenario: Successfully creating an evaluation:"

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

       puts "When I create an evaluation for the model with the dataset"
       evaluation = @api.create_evaluation(model, dataset)
     
       puts "And I wait until the evaluation is ready"
       assert_equal(BigML::HTTP_CREATED, evaluation["code"])
       assert_equal(@api.ok(evaluation), true)

       puts "Then the measured #{item['measure']} is #{item['value']}"
       evaluation = @api.get_evaluation(evaluation)
       assert_equal(item["value"].to_f, evaluation["object"]["result"]["model"][item["measure"]].to_f)

    end

  end

  # Scenario: Successfully creating an evaluation for an ensemble 
  def test_scenario2
    data = [{'filename' => File.dirname(__FILE__)+'/data/iris.csv',
             'number_of_models' => 5,
             'measure' => 'average_phi',
             'value' => '0.98029',
             'params' => {"combiner" => 0},
             'tlp' => 1},
             {'filename' => File.dirname(__FILE__)+'/data/iris.csv',
                          'number_of_models' => 5,
                          'measure' => 'average_phi',
                          'value' => '0.95061',
                          'params' => {"combiner" => 1},
                          'tlp' => 1},
            {'filename' => File.dirname(__FILE__)+'/data/iris.csv',
                         'number_of_models' => 5,
                         'measure' => 'average_phi',
                         'value' => '0.98029',
                         'params' => {"combiner" => 2},
                         'tlp' => 1},
            {'filename' => File.dirname(__FILE__)+'/data/iris.csv',
                          'number_of_models' => 5,
                           'measure' => 'average_phi',
                           'value' => '0.98029',
                           'params' => {"operating_kind" => "votes"},
                           'tlp' => 1},
            {'filename' => File.dirname(__FILE__)+'/data/iris.csv',
                            'number_of_models' => 5,
                            'measure' => 'average_phi',
                            'value' => '0.97064',
                            'params' => {"operating_kind" => "probability"},
                            'tlp' => 1},            
            {'filename' => File.dirname(__FILE__)+'/data/iris.csv',
                            'number_of_models' => 5,
                            'measure' => 'average_phi',
                            'value' => '0.95061',
                            'params' => {"operating_kind" => "confidence"},
                            'tlp' => 1},
           ]
                         
    puts
    puts "Scenario: Successfully creating an evaluation for an ensemble" 

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

       puts "And I create an ensemble of #{item['number_of_models']} models and #{item['tlp']} tlp"
       
       ensemble = @api.create_ensemble(dataset, {"number_of_models"=> item["number_of_models"], 
                                                 "seed" => 'BigML', 
                                                 'ensemble_sample'=>{'rate' => 0.7, 
                                                                     'seed' => 'BigML'}, 
                                                 'missing_splits' => false})
                                                 

       puts "And I wait until the ensemble is ready"
       assert_equal(BigML::HTTP_CREATED, ensemble["code"])
       assert_equal(@api.ok(ensemble), true)

       puts "When I create an evaluation for the ensemble with the dataset"
       evaluation = @api.create_evaluation(ensemble, dataset, item["params"])

       puts "And I wait until the evaluation is ready"
       assert_equal(BigML::HTTP_CREATED, evaluation["code"])
       assert_equal(@api.ok(evaluation), true)

       puts "Then the measured #{item['measure']} is #{item['value']}"
       evaluation = @api.get_evaluation(evaluation)
       assert_equal(item["value"].to_f, evaluation["object"]["result"]["model"][item["measure"]].to_f) 

    end

  end
  
  # Scenario3: Successfully creating an evaluation for a logistic regression: 
  def test_scenario3
    data = [{'filename' => File.dirname(__FILE__)+'/data/iris.csv',
             'measure' => 'average_phi',
             'value' => 0.89054}]

    puts 
    puts "Scenario3: Successfully creating an evaluation for a logistic regression:"

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
       logisticregression=@api.create_logisticregression(dataset)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, logisticregression["code"])
       assert_equal(1, logisticregression["object"]["status"]["code"])
       assert_equal(@api.ok(logisticregression), true)
       
       puts "When I create an evaluation for the ensemble with the dataset"
       evaluation = @api.create_evaluation(logisticregression, dataset)

       puts "And I wait until the evaluation is ready"
       assert_equal(BigML::HTTP_CREATED, evaluation["code"])
       assert_equal(@api.ok(evaluation), true)
       
       puts "Then the measured #{item['measure']} is #{item['value']}"
       evaluation = @api.get_evaluation(evaluation)
       assert_equal(item["value"].to_f, evaluation["object"]["result"]["model"][item["measure"]].to_f)
       
    end
  end
  
  # Scenario4: Successfully creating an evaluation for a deepnet 
  def test_scenario4
    data = [{'filename' => File.dirname(__FILE__)+'/data/iris.csv',
             'measure' => 'average_phi',
             'value' => 0.95007}]

    puts 
    puts "Scenario4: Successfully creating an evaluation for a deepnet"

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
       deepnet=@api.create_deepnets(dataset)

       puts "And I wait until the deepnet is ready"
       assert_equal(BigML::HTTP_CREATED, deepnet["code"])
       assert_equal(1, deepnet["object"]["status"]["code"])
       assert_equal(@api.ok(deepnet), true)
       
       puts "When I create an evaluation for the deepnet with the dataset"
       evaluation = @api.create_evaluation(deepnet, dataset)

       puts "And I wait until the evaluation is ready"
       assert_equal(BigML::HTTP_CREATED, evaluation["code"])
       assert_equal(@api.ok(evaluation), true)
       
       puts "Then the measured #{item['measure']} is #{item['value']}"
       evaluation = @api.get_evaluation(evaluation)
       assert_equal(item["value"].to_f, evaluation["object"]["result"]["model"][item["measure"]].to_f)
       
    end
  end

end

