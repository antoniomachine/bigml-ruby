require "test/unit"
require_relative "../lib/bigml/api"

class TestPredicction < Test::Unit::TestCase

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
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv", 
             "data_input" => {'petal width'=> 0.5},
	     "objective" => "000004",
	     "prediction" => "Iris-setosa"},
	     {"filename" => File.dirname(__FILE__)+"/data/iris_sp_chars.csv",
	     "data_input" => {'pétal&width'=> 0.5},
	     "objective" => "000004",
	     "prediction" => "Iris-setosa"}]

    puts 
    puts "Scenario: Successfully creating a prediction:"
  
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

       puts "When I create a prediction for "  + JSON.generate(item["data_input"])
       prediction = @api.create_prediction(model, item["data_input"])
       assert_equal(BigML::HTTP_CREATED, prediction["code"])

       puts "Then the prediction for " + item["objective"] + " is " + item["prediction"]
       assert_equal(item["prediction"], prediction["object"]["prediction"][item["objective"]])

    end

  end

  # Scenario: Successfully creating a prediction from a source in a remote location 
  def test_scenario2
    data = [ {"filename" => "s3://bigml-public/csv/iris.csv",
             "data_input" => {'petal width'=> 0.5},
             "objective" => "000004",
             "prediction" => "Iris-setosa"}
           ]

    puts
    puts "Scenario: Successfully creating a prediction from a source in a remote location:"

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

       puts "When I create a prediction for "  + JSON.generate(item["data_input"])
       prediction = @api.create_prediction(model, item["data_input"])
       assert_equal(BigML::HTTP_CREATED, prediction["code"])

       puts "Then the prediction for " + item["objective"] + " is " + item["prediction"]
       assert_equal(item["prediction"], prediction["object"]["prediction"][item["objective"]])
    end
  end

  # Scenario: Successfully creating a centroid and the associated dataset
  def test_scenario5
    data = [ {"filename" => File.dirname(__FILE__)+"/data/diabetes.csv",
             "data_input" => {"pregnancies" => 0, "plasma glucose" => 118, "blood pressure" => 84, "triceps skin thickness" => 47, "insulin" => 230, "bmi" => 45.8, "diabetes pedigree" => 0.551, "age" => 31, "diabetes" => "true"}, 
             "centroid" => "Cluster 3"}
           ]

    puts
    puts "Scenario: Successfully creating a centroid and the associated dataset"
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

       puts "And I create cluster"
       cluster=@api.create_cluster(dataset, {'seed'=>'BigML tests', 'k' =>  8, 'cluster_seed' => 'BigML'})

       puts "And I wait until the cluster is ready"
       assert_equal(BigML::HTTP_CREATED, cluster["code"])
       assert_equal(1, cluster["object"]["status"]["code"])
       assert_equal(@api.ok(cluster), true)

       puts " When I create a centroid for #{item["data_input"]}"
       centroid = @api.create_centroid(cluster["resource"], item["data_input"])

       puts " And I check the centroid is ok "
       assert_equal(BigML::HTTP_CREATED, centroid["code"])
       assert_equal(@api.ok(centroid), true)

       puts "Then the centroid is " + item["centroid"]
       assert_equal(item["centroid"], centroid["object"]["centroid_name"])
    end

  end

  # Scenario: Successfully creating an anomaly score
  def test_scenario6 
    data = [ {"filename" => File.dirname(__FILE__)+"/data/tiny_kdd.csv",
              "data_input" => {"src_bytes" => 350}, 
              "score" => 0.92846 },
             {"filename" => File.dirname(__FILE__)+"/data/iris_sp_chars.csv",
              "data_input" => {"pétal&width\u0000" => 300},
              "score" =>  0.89313} 
           ]
    puts
    puts "\nScenario: Successfully creating an anomaly score\n"

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

       puts "And I create an anomaly detector from a dataset" 
       anomaly = @api.create_anomaly(dataset)

       puts "And I wait until the anomaly detector is ready"
       assert_equal(BigML::HTTP_CREATED, anomaly["code"])
       assert_equal(@api.ok(anomaly), true)

       puts "When I create an anomaly score for " + JSON.generate(item["data_input"])
       anomaly_score = @api.create_anomaly_score(anomaly, item["data_input"])

       puts "Then the anomaly score is #{item['score']}" 
       assert_equal(anomaly_score["object"]["score"], item["score"])

    end
  end

  # Scenario: Successfully creating an Topic Model 
  def test_scenario7

    data = [[File.dirname(__FILE__)+'/data/movies.csv', {"fields" => {"000007" => {"optype" => "items", "item_analysis" => {"separator" => "$"}}, "000006" => {"optype"=> "text"}}}]]
    puts
    puts "Scenario: Successfully creating an Topic Model"

    data.each do |filename, params|
       puts "Given I create a data source uploading a %s file" % filename
       source = @api.create_source(filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

       puts "And I wait until the source is ready"
       assert_equal(BigML::HTTP_CREATED, source["code"])
       assert_equal(1, source["object"]["status"]["code"])
       assert_equal(@api.ok(source), true) 

       puts "And I update the source with params <%s>" % JSON.generate(params)
       source = @api.update_source(source, params)
       assert_equal(BigML::HTTP_ACCEPTED, source["code"])
       assert_equal(@api.ok(source), true)

       puts "And I create dataset"
       dataset=@api.create_dataset(source)
    
       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)

       puts "When I create an topic model from a dataset"
       lda = @api.create_topic_model(dataset)
       puts "Then I wait until the topic model is ready"
       assert_equal(BigML::HTTP_CREATED, lda["code"])
       assert_equal(1, lda["object"]["status"]["code"])
       assert_equal(@api.ok(lda), true)

    end 

  end

end

