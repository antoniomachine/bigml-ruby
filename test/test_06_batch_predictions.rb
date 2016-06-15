require_relative "../lib/bigml/api"
require "test/unit"

class TestBatchPredicctions < Test::Unit::TestCase

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
    data = [{'filename' => File.dirname(__FILE__)+'/data/iris.csv', 
             'local_file' => File.dirname(__FILE__)+'/tmp/batch_predictions.csv', 
	     'predictions_file' => File.dirname(__FILE__)+'/data/batch_predictions.csv'}]

    puts 
    puts "Scenario: Successfully creating a prediction:"

    data.each do |item|
       puts 
       puts "Given I create a data source uploading a #{item['filename']} file"
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

       puts "And I create a batch prediction";
       batch_prediction=@api.create_batch_prediction(model,dataset)

       puts "And I wait until the batch prediction is ready"
       assert_equal(BigML::HTTP_CREATED, batch_prediction["code"])
       assert_equal(@api.ok(batch_prediction), true)

       puts "And I download the created predictions file to #{item['local_file']}"
       filename = @api.download_batch_prediction(batch_prediction, item["local_file"])
       assert_not_nil(filename)

       puts "Then the batch prediction file is like #{item['predictions_file']}"
       assert_equal(FileUtils.compare_file(item["local_file"], item["predictions_file"]), true)

    end

  end

  # Scenario: Successfully creating a batch prediction for an ensemble
  def test_scenario2
    data = [{'filename' => File.dirname(__FILE__)+'/data/iris.csv',
             'number_of_models' => 5,
             'tlp' => 1,
             'local_file' => File.dirname(__FILE__)+'/tmp/batch_predictions.csv',
             'predictions_file' => File.dirname(__FILE__)+'/data/batch_predictions_e.csv'}]

    puts
    puts "Scenario: Successfully creating a batch prediction for an ensemble"

    data.each do |item|
       puts
       puts "Given I create a data source uploading a #{item['filename']} file"
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
       ensemble = @api.create_ensemble(dataset, {"number_of_models"=> item["number_of_models"], "tlp"=> item["tlp"], "seed" => 'BigML', 'sample_rate'=> 0.70})

       puts "And I wait until the ensemble is ready"
       assert_equal(BigML::HTTP_CREATED, ensemble["code"])
       assert_equal(@api.ok(ensemble), true)

       puts "When I create a batch prediction for the dataset with the ensemble"
       batch_prediction = @api.create_batch_prediction(ensemble, dataset)

       puts "And I wait until the batch prediction is ready"
       assert_equal(BigML::HTTP_CREATED, batch_prediction["code"])
       assert_equal(@api.ok(batch_prediction), true) 

       puts "And I download the created predictions file to #{item['local_file']}"
       filename = @api.download_batch_prediction(batch_prediction, item["local_file"])
       assert_not_nil(filename)

       puts "Then the batch prediction file is like #{item['predictions_file']}"
       assert_equal(FileUtils.compare_file(item["local_file"], item["predictions_file"]), true)


    end

  end

  # Scenario: Successfully creating a batch centroid from a cluster 
  def test_scenario3
    data = [{'filename' => File.dirname(__FILE__)+'/data/diabetes.csv',
             'local_file' => File.dirname(__FILE__)+'/tmp/batch_predictions_c.csv',
             'predictions_file' => File.dirname(__FILE__)+'/data/batch_predictions_c.csv'}]

    puts 
    puts "Scenario: Successfully creating a batch prediction for an ensemble"

    data.each do |item|
       puts
       puts "Given I create a data source uploading a #{item['filename']} file"
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

       puts "And I create cluster"
       cluster=@api.create_cluster(dataset, {'seed'=>'BigML tests', 'k' =>  8, 'cluster_seed' => 'BigML'})
  
       puts "And I wait until the cluster is ready"
       assert_equal(BigML::HTTP_CREATED, cluster["code"])
       assert_equal(1, cluster["object"]["status"]["code"])
       assert_equal(@api.ok(cluster), true)

       puts "When I create a batch centroid for the dataset"
       batch_prediction = @api.create_batch_centroid(cluster, dataset)

       puts "And I wait until the batch centroid is ready"
       assert_equal(BigML::HTTP_CREATED, batch_prediction["code"])
       assert_equal(@api.ok(batch_prediction), true)
               
       puts "And I download the created centroid file to #{item['local_file']}"
       filename = @api.download_batch_centroid(batch_prediction, item["local_file"])
       assert_not_nil(filename)

       puts "Then the batch centroid file is like #{item['predictions_file']}"
       assert_equal(FileUtils.compare_file(item["local_file"], item["predictions_file"]), true)


    end
  end

end

