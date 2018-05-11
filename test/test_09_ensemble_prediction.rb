require_relative "../lib/bigml/api"
require "test/unit"

class TestEnsemblePredicction < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new(nil, nil, true)
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating a prediction from an ensemble
  def test_scenario1
    data = [
         {"filename" => File.dirname(__FILE__)+'/data/iris.csv',
             "number_of_models" => 5,
             "tlp" => 1,
             "data_input" => {"petal width" => 0.5},
             "objective" => "000004",
             "prediction" => "Iris-versicolor"},
            {"filename" => File.dirname(__FILE__)+'/data/iris_sp_chars.csv',
             "number_of_models" => 5,
             "tlp" => 1,
             "data_input" => {"pétal&width" => 0.5},
             "objective" => "000004",
             "prediction" => "Iris-versicolor"},
            {"filename" => File.dirname(__FILE__)+'/data/grades.csv',
             "number_of_models" => 10,
             "tlp" => 1,
             "data_input" => {"Assignment" => 81.22,  "Tutorial"=> 91.95, "Midterm"=> 79.38, "TakeHome"=> 105.93},
             "objective" => "000005",
             "prediction" => 84.556},
            {"filename" => File.dirname(__FILE__)+'/data/grades.csv',
             "number_of_models" => 10,
             "tlp" => 1,
             "data_input" => {"Assignment" => 97.33,  "Tutorial"=> 106.74, "Midterm"=> 76.88, "TakeHome"=> 108.89},
             "objective" => "000005",
             "prediction" => 73.13558}
           ]

    puts
    puts "Scenario: Successfully creating a prediction from an ensemble"
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

       puts "When I create an ensemble prediction for #{item['data_input']}"
       prediction = @api.create_prediction(ensemble, item["data_input"])

       puts "And I wait until the prediction is ready"
       assert_equal(BigML::HTTP_CREATED, prediction["code"]) 
       assert_equal(@api.ok(prediction), true)

       puts "Then the prediction for #{item['objective']} is #{item['prediction']}"
       assert_equal(item["prediction"], prediction["object"]["prediction"][item["objective"]].is_a?(Float) ? 
						('%.5f' % prediction["object"]["prediction"][item["objective"]]).to_f : 
						prediction["object"]["prediction"][item["objective"]])

    end

  end

end

