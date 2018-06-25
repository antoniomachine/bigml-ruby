require_relative "../lib/bigml/api"
require_relative "../lib/bigml/model"
require_relative "../lib/bigml/ensemble"
require_relative "../lib/bigml/logistic"
require_relative "../lib/bigml/deepnet"
require_relative "../lib/bigml/cluster"
require_relative "../lib/bigml/anomaly"
require_relative "../lib/bigml/association"
require_relative "../lib/bigml/topicmodel"
require_relative "../lib/bigml/timeseries"

require "test/unit"

class TestLocalFromFileConnection < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  #  "Scenario 1: Successfully creating a local model from an exported file"
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 
             false, 
             File.dirname(__FILE__)+'/tmp/model.json']]
    puts
    puts "Scenario 1: Successfully creating a local model from an exported file"

    data.each do |filename, pmml, exported_file|
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
      
      puts "An I create a model"
      model=@api.create_model(dataset)

      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, model["code"])
      assert_equal(1, model["object"]["status"]["code"])
      assert_equal(@api.ok(model), true)
      
      puts "And I export the <%s> model to <%s>" % [pmml, exported_file]
      @api.export(model["resource"], exported_file)
      
      puts "When I create a local model from the file <%s>" % exported_file
      local_model = BigML::Model.new(exported_file, @api)
      
      puts "Then the model ID and the local model ID match"
      assert_equal(local_model.resource_id, model["resource"])
      
    end
  end
  
  #  "Scenario 2: Successfully creating a fusion from a dataset"
  def test_scenario2
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 
             false, 
             File.dirname(__FILE__)+'/tmp/ensemble.json']]
    puts
    puts "Scenario 2: Successfully creating a local ensemble from an exported file"

    data.each do |filename, pmml, exported_file|
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
      
      puts "An I create a model"
      ensemble = @api.create_ensemble(dataset, {"seed" => 'BigML', 'ensemble_sample'=>{'rate' => 0.7, 'seed' => 'BigML'}})

      puts "And I wait until the ensemble is ready"
      assert_equal(BigML::HTTP_CREATED, ensemble["code"])
      assert_equal(1, ensemble["object"]["status"]["code"])
      assert_equal(@api.ok(ensemble), true)
      
      puts "And I export the <%s> ensemble to <%s>" % [pmml, exported_file]
      @api.export(ensemble["resource"], exported_file)
      
      puts "When I create a local ensemble from the file <%s>" % exported_file
      local_ensemble = BigML::Ensemble.new(exported_file)
      
      puts "Then the ensemble ID and the local ensemble ID match"
      assert_equal(local_ensemble.resource_id, ensemble["resource"])
      
    end
  end
  
  #  "Scenario 3: Successfully creating a local logistic regression from an exported file"
  def test_scenario3
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 
             false, 
             File.dirname(__FILE__)+'/tmp/logistic.json']]
    puts
    puts "Scenario 3: Successfully creating a local logistic regression from an exported file"

    data.each do |filename, pmml, exported_file|
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
      
      puts "An I create a logistic regression"
      logistic_regression = @api.create_logisticregression(dataset)

      puts "And I wait until the logistic_regression is ready"
      assert_equal(BigML::HTTP_CREATED, logistic_regression["code"])
      assert_equal(1, logistic_regression["object"]["status"]["code"])
      assert_equal(@api.ok(logistic_regression), true)
      
      puts "And I export the <%s> logistic regression to <%s>" % [pmml, exported_file]
      @api.export(logistic_regression["resource"], exported_file)
      
      puts "When I create a local logistic regression from the file <%s>" % exported_file
      local_Logistic= BigML::Logistic.new(exported_file)
      
      puts "Then the logistic regression ID and the local logistic regression ID match"
      assert_equal(local_Logistic.resource_id, logistic_regression["resource"])
      
    end
  end
  
  #  "Scenario 4: Successfully creating a local deepnet from an exported file"
  def test_scenario4
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 
             false, 
             File.dirname(__FILE__)+'/tmp/deepnet.json']]
    puts
    puts "Scenario 4: Successfully creating a local deepnet from an exported file"

    data.each do |filename, pmml, exported_file|
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
      
      puts "An I create a deepnet"
      deepnet = @api.create_deepnets(dataset)

      puts "And I wait until the deepnet is ready"
      assert_equal(BigML::HTTP_CREATED, deepnet["code"])
      assert_equal(1, deepnet["object"]["status"]["code"])
      assert_equal(@api.ok(deepnet), true)
      
      puts "And I export the <%s> deepnet to <%s>" % [pmml, exported_file]
      @api.export(deepnet["resource"], exported_file)
      
      puts "When I create a local deepnet from the file <%s>" % exported_file
      local_deepnet= BigML::Deepnet.new(exported_file)
      
      puts "Then the deepnet ID and the local model ID match"
      assert_equal(local_deepnet.resource_id, deepnet["resource"])
      
    end
  end
  
  #  "Scenario 5: Successfully creating a local cluster from an exported file"
  def test_scenario5
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 
             false, 
             File.dirname(__FILE__)+'/tmp/cluster.json']]
    puts
    puts "Scenario 5: Successfully creating a local cluster from an exported file"

    data.each do |filename, pmml, exported_file|
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
      
      puts "An I create a cluster"
      cluster = @api.create_cluster(dataset)

      puts "And I wait until the cluster is ready"
      assert_equal(BigML::HTTP_CREATED, cluster["code"])
      assert_equal(1, cluster["object"]["status"]["code"])
      assert_equal(@api.ok(cluster), true)
      
      puts "And I export the <%s> cluster to <%s>" % [pmml, exported_file]
      @api.export(cluster["resource"], exported_file)
      
      puts "When I create a local cluster from the file <%s>" % exported_file
      local_cluster= BigML::Cluster.new(exported_file)
      
      puts "Then the cluster ID and the local model ID match"
      assert_equal(local_cluster.resource_id, cluster["resource"])
      
    end
  end
  
  #  "Scenario 6: Successfully creating a local anomaly from an exported file"
  def test_scenario6
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 
             false, 
             File.dirname(__FILE__)+'/tmp/anomaly.json']]
    puts
    puts "Scenario 6: Successfully creating a local anomaly from an exported file"

    data.each do |filename, pmml, exported_file|
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
      
      puts "An I create a anomaly"
      anomaly = @api.create_anomaly(dataset)

      puts "And I wait until the anomaly is ready"
      assert_equal(BigML::HTTP_CREATED, anomaly["code"])
      assert_equal(1, anomaly["object"]["status"]["code"])
      assert_equal(@api.ok(anomaly), true)
      
      puts "And I export the <%s> anomaly to <%s>" % [pmml, exported_file]
      @api.export(anomaly["resource"], exported_file)
      
      puts "When I create a local anomaly from the file <%s>" % exported_file
      local_anomaly= BigML::Anomaly.new(exported_file)
      
      puts "Then the anomaly ID and the local model ID match"
      assert_equal(local_anomaly.resource_id, anomaly["resource"])
      
    end
  end
  
  #  "Scenario 7: Successfully creating a local association from an exported file"
  def test_scenario7
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 
             false, 
             File.dirname(__FILE__)+'/tmp/association.json']]
    puts
    puts "Scenario 7: Successfully creating a local association from an exported file"

    data.each do |filename, pmml, exported_file|
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
      
      puts "An I create a association"
      association = @api.create_association(dataset)

      puts "And I wait until the association is ready"
      assert_equal(BigML::HTTP_CREATED, association["code"])
      assert_equal(1, association["object"]["status"]["code"])
      assert_equal(@api.ok(association), true)
      
      puts "And I export the <%s> association to <%s>" % [pmml, exported_file]
      @api.export(association["resource"], exported_file)
      
      puts "When I create a local association from the file <%s>" % exported_file
      local_association= BigML::Association.new(exported_file)
      
      puts "Then the association ID and the local association ID match"
      assert_equal(local_association.resource_id, association["resource"])
      
    end
  end
  
  #  "Scenario 8: Successfully creating a local topic model from an exported file"
  def test_scenario8
    data = [[File.dirname(__FILE__)+'/data/spam.csv', 
             false, 
             File.dirname(__FILE__)+'/tmp/topic_model.json',
             {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive" => true, "stem_words" => true, "use_stopwords" => false, "language" => "en"}}}}]]
    puts
    puts "Scenario 8: Successfully creating a local topic model from an exported file"

    data.each do |filename, pmml, exported_file, options|
      puts
      puts "Given I create a data source uploading a <%s> file" % filename
      source = @api.create_source(filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

      puts "And I wait until the source is ready"
      assert_equal(BigML::HTTP_CREATED, source["code"])
      assert_equal(1, source["object"]["status"]["code"])
      assert_equal(@api.ok(source), true)
      
      puts "And I update the source with params <%s>" % JSON.generate(options)
      source = @api.update_source(source, options)
      assert_equal(BigML::HTTP_ACCEPTED, source["code"])
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
      
      puts "An I create a topic model"
      topic_model = @api.create_topic_model(dataset)

      puts "And I wait until the topic model is ready"
      assert_equal(BigML::HTTP_CREATED, topic_model["code"])
      assert_equal(1, topic_model["object"]["status"]["code"])
      assert_equal(@api.ok(topic_model), true)
      
      puts "And I export the <%s> topic model to <%s>" % [pmml, exported_file]
      @api.export(topic_model["resource"], exported_file)
      
      puts "When I create a local topic model from the file <%s>" % exported_file
      local_topic_model= BigML::TopicModel.new(exported_file)
      
      puts "Then the topic model  ID and the local topic model ID match"
      assert_equal(local_topic_model.resource_id, topic_model["resource"])
      
    end
  end
  
  #  "Scenario 9: Successfully creating a local time series from an exported file"
  def test_scenario9
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 
             false, 
             File.dirname(__FILE__)+'/tmp/time_series.json']]
    puts
    puts "Scenario 9: Successfully creating a local time series from an exported file"

    data.each do |filename, pmml, exported_file|
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
      
      puts "An I create a topic model"
      time_series = @api.create_time_series(dataset)

      puts "And I wait until the time series is ready"
      assert_equal(BigML::HTTP_CREATED, time_series["code"])
      assert_equal(1, time_series["object"]["status"]["code"])
      assert_equal(@api.ok(time_series), true)
      
      puts "And I export the <%s> time series to <%s>" % [pmml, exported_file]
      @api.export(time_series["resource"], exported_file)
      
      puts "When I create a local time series from the file <%s>" % exported_file
      local_time_series= BigML::TimeSeries.new(exported_file)
      
      puts "Then the time_series ID and the local time series ID match"
      assert_equal(local_time_series.resource_id, time_series["resource"])
      
    end
  end
  
end