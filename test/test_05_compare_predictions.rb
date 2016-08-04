require "test/unit"            
require_relative "../lib/bigml/api"
require_relative "../lib/bigml/model"
require_relative "../lib/bigml/cluster"
require_relative "../lib/bigml/anomaly"
require_relative "../lib/bigml/logistic"

class TestComparePrediction < Test::Unit::TestCase
  
  def setup                    
   @api = BigML::Api.new       
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name) 
   @project = @api.create_project({'name' => @test_name})
  end   
        
  def teardown
   #@api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating a prediction:
  def test_scenario1         
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv", 
             "data_input" => {'petal width'=> 0.5},
             "objective" => "000004",           
             "prediction" => "Iris-setosa"},
             {"filename" => File.dirname(__FILE__)+"/data/iris.csv", 
             "data_input" => {'petal length'=> 6, 'petal width'=> 2},
             "objective" => "000004",           
             "prediction" => "Iris-virginica"},
             {"filename" => File.dirname(__FILE__)+"/data/iris.csv", 
             "data_input" => {'petal length' => 4, 'petal width'=> 1.5},
             "objective" => "000004",           
             "prediction" => "Iris-versicolor"}, 
             {"filename" => File.dirname(__FILE__)+"/data/iris_sp_chars.csv",
             "data_input" => {"pétal.length" => 4, "pétal&width\u0000" => 1.5},
             "objective" => "000004",   
             "prediction" => "Iris-versicolor"}
	     ]
        
    puts 
    puts "Scenario: Successfully comparing predictions"     
        
    data.each do |item|
        puts 
        puts "Given I create a data source uploading a <%s> file" % item["filename"]
        source = @api.create_source(item["filename"], {'name'=> 'source_test', 'project'=> @project["resource"]})

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

        puts "And I create a model"
        model=@api.create_model(dataset)

        puts "And I wait until the model is ready"
        assert_equal(BigML::HTTP_CREATED, model["code"])
        assert_equal(1, model["object"]["status"]["code"])
        assert_equal(@api.ok(model), true)

        puts "And I create a local model"
        local_model = BigML::Model.new(model, @api)

        puts "When I create a prediction for <%s>" % JSON.generate(item["data_input"])
        prediction = @api.create_prediction(model, item["data_input"])
        assert_equal(BigML::HTTP_CREATED, prediction["code"])
       
        puts "Then the prediction for <%s> is <%s>" % [item["objective"], item["prediction"]]
        assert_equal(item["prediction"], prediction["object"]["prediction"][item["objective"]])       

        puts "And I create a local prediction for <%s>" % JSON.generate(item["data_input"])
        prediction = local_model.predict(item["data_input"])

        puts "Then the local prediction is <%s>" % item["prediction"]
        assert_equal(prediction, item["prediction"]) 

    end
  end

  def test_scenario2
    data = [
            {"filename" => File.dirname(__FILE__)+"/data/spam.csv", 
             "options" => {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive"=> true, "stem_words" => true, "use_stopwords" => false, "language" => "en"}}}},
             "data_input" => {"Message" => "Mobile call"}, 
             "objective" => "000000",           
             "prediction" => "ham"},
            {"filename" => File.dirname(__FILE__)+"/data/spam.csv",
             "options" => {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive"=> true, "stem_words" => true, "use_stopwords" => false, "language" => "en"}}}},
             "data_input" => {"Message" => "A normal message"},
             "objective" => "000000",
             "prediction" => "ham"},
            {"filename" => File.dirname(__FILE__)+"/data/spam.csv",
             "options" => {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive"=> false, "stem_words" => false, "use_stopwords" => false, "language" => "en"}}}},
             "data_input" => {"Message" => "Mobile calls"},
             "objective" => "000000",
             "prediction" => "spam"},
            {"filename" => File.dirname(__FILE__)+"/data/spam.csv",
             "options" => {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive"=> false, "stem_words" => false, "use_stopwords" => false, "language" => "en"}}}},
             "data_input" => {"Message" => "A normal message"},
             "objective" => "000000",
             "prediction" => "ham"},
            {"filename" => File.dirname(__FILE__)+"/data/spam.csv",
             "options" => {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive"=> false, "stem_words" => false, "use_stopwords" => true, "language" => "en"}}}},
             "data_input" => {"Message" => "A mobile call"},
             "objective" => "000000",
             "prediction" => "spam"},
            {"filename" => File.dirname(__FILE__)+"/data/spam.csv",
             "options" => {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive"=> false, "stem_words" => true, "use_stopwords" => true, "language" => "en"}}}},
             "data_input" => {"Message" => "A normal message"},
             "objective" => "000000",
             "prediction" => "ham"},
            {"filename" => File.dirname(__FILE__)+"/data/spam.csv",
             "options" => {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"token_mode"=> "full_terms_only", "language" => "en"}}}},
             "data_input" => {"Message" => "FREE for 1st week! No1 Nokia tone 4 ur mob every week just txt NOKIA to 87077 Get txting and tell ur mates. zed POBox 36504 W45WQ norm150p/tone 16+"},
             "objective" => "000000",
             "prediction" => "spam"},
            {"filename" => File.dirname(__FILE__)+"/data/spam.csv",
             "options" => {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"token_mode"=> "full_terms_only", "language" => "en"}}}},
             "data_input" => {"Message" => "Ok"},
             "objective" => "000000",
             "prediction" => "ham"},
             {"filename" => File.dirname(__FILE__)+"/data/movies.csv",
             "options" => {"fields" => {"000007" => {"optype" => "items", "item_analysis" => {"separator"=> "$"}}}},
             "data_input" => {"genres" => "Adventure$Action", "timestamp" => 993906291, "occupation" => "K-12 student"}, 
             "objective" => "000009",
             "prediction" => 3.93064},
             {"filename" => File.dirname(__FILE__)+"/data/text_missing.csv",
             "options" => {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"token_mode"=> "all", "language" => "en"}},"000000" => {"optype" => "text", "term_analysis" => {"token_mode" => "all", "language" => "en"}}}}, 
             "data_input" => {},
             "objective" => "000003",
             "prediction" => "swap"}
           ]

    puts 
    puts "Scenario: Successfully comparing predictions with text options"
        
    data.each do |item|
        puts 
        puts "Given I create a data source uploading a <%s> file" % item["filename"]
        source = @api.create_source(item["filename"], {'name'=> 'source_test', 'project'=> @project["resource"]})

        puts "And I wait until the source is ready"
        assert_equal(BigML::HTTP_CREATED, source["code"])
        assert_equal(1, source["object"]["status"]["code"])
        assert_equal(@api.ok(source), true)

        puts "And I update the source with params <%s>" % JSON.generate(item["options"])
        source = @api.update_source(source, item["options"])
        assert_equal(BigML::HTTP_ACCEPTED, source["code"])
        assert_equal(@api.ok(source), true)

        puts "And I create a dataset"
        dataset=@api.create_dataset(source)

        puts "And I wait until the dataset is ready"
        assert_equal(BigML::HTTP_CREATED, dataset["code"])
        assert_equal(1, dataset["object"]["status"]["code"])
        assert_equal(@api.ok(dataset), true)

        puts "And I create a model"
        model=@api.create_model(dataset)

        puts "And I wait until the model is ready"
        assert_equal(BigML::HTTP_CREATED, model["code"])
        assert_equal(1, model["object"]["status"]["code"])
        assert_equal(@api.ok(model), true)

        puts "And I create a local model"
        local_model = BigML::Model.new(model["resource"], @api)

        puts "When I create a prediction for <%s>" % JSON.generate(item["data_input"])
        prediction = @api.create_prediction(model, item["data_input"])
        assert_equal(BigML::HTTP_CREATED, prediction["code"])
 
        puts "Then the prediction for <%s> is <%s>" % [item["objective"], item["prediction"]]
        assert_equal(item["prediction"], prediction["object"]["prediction"][item["objective"]]) 

        puts "And I create a local prediction for <%s>" % JSON.generate(item["data_input"])
        prediction = local_model.predict(item["data_input"])

        puts "Then the local prediction is <%s>" % item["prediction"]
        assert_equal(prediction, item["prediction"]) 
    end
  end

  def test_scenario3
    data = [
           {"filename" => File.dirname(__FILE__)+'/data/iris.csv', 
            "data_input" => {},
            "objective" => '000004',
            "prediction" =>  'Iris-setosa',
            "confidence" => 0.2629},
           {'filename' => File.dirname(__FILE__)+'/data/grades.csv',
            'data_input' => {}, 
            'objective' => '000005',
            'prediction' =>  68.62224,
            'confidence' =>  27.5358},
           {'filename' => File.dirname(__FILE__)+'/data/grades.csv', 
            'data_input' => {"Midterm" => 20}, 
            'objective' => '000005',
            'prediction' => 46.69889, 
            'confidence' => 37.27594297134128},
           {'filename' => File.dirname(__FILE__)+'/data/grades.csv', 
            'data_input' => {"Midterm" => 20, "Tutorial" => 90, "TakeHome" => 100}, 
            'objective' => '000005', 
            'prediction' => 28.06,
            'confidence' => 24.86634}
          ]
    puts
    puts "Scenario: Successfully comparing predictions with proportional missing strategy"

    data.each do |item|
        puts
        puts "Given I create a data source uploading a <%s> file" % item["filename"]
        source = @api.create_source(item["filename"], {'name'=> 'source_test', 'project'=> @project["resource"]})

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

        puts "And I create a model"
        model=@api.create_model(dataset)

        puts "And I wait until the model is ready"
        assert_equal(BigML::HTTP_CREATED, model["code"])
        assert_equal(1, model["object"]["status"]["code"])
        assert_equal(@api.ok(model), true) 

        puts "And I create a local model "
        local_model = BigML::Model.new(model["resource"], @api)        

        puts "When I create a proportional missing strategy prediction for <%s>" % JSON.generate(item["data_input"])
        prediction = @api.create_prediction(model, item["data_input"], {"missing_strategy" => 1})
        assert_equal(BigML::HTTP_CREATED, prediction["code"])

        puts "Then the prediction for <%s> is <%s>" % [item["objective"], item["prediction"]]
        assert_equal(item["prediction"], prediction["object"]["prediction"][item["objective"]])

        puts "And I create a proportional missing strategy local prediction for <%s>" % JSON.generate(item["data_input"])
        local_prediction = local_model.predict(item["data_input"], true, false, $STDOUT, true, BigML::PROPORTIONAL)

        puts "Then the local prediction is <%s>" % item["prediction"]
        if item["prediction"].is_a?(Numeric)
           assert_equal(local_prediction[0].round(4), item["prediction"].round(4))
        else
           assert_equal(local_prediction[0], item["prediction"])
        end
        puts "And the local prediction's confidence is <%s>" % item["confidence"]
        assert_equal(local_prediction[1].round(3), item["confidence"].round(3))
 
    end
  end

  def test_scenario4
    data = [
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype": "text", "term_analysis"=> {"case_sensitive"=> true, "stem_words"=> true, "use_stopwords"=> false, "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "Mobile call"}, 'Cluster 1', 0.5],
           ['data/spam.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive" => true, "stem_words" => true, "use_stopwords" => false}}}}, {"Type" => "ham", "Message" => "A normal message"}, 'Cluster 1', 0.5],
           ['data/spam.csv', {"fields": {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> false, "use_stopwords"=> false, "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "Mobile calls"}, 'Cluster 0', 0.5],
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> false, "use_stopwords"=> false, "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "A normal message"}, 'Cluster 0', 0.5],
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> true, "use_stopwords"=> true, "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "Mobile call"}, 'Cluster 5', 0.41161165235168157],
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> true, "use_stopwords"=> true, "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "A normal message"}, 'Cluster 1', 0.35566243270259357],
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"token_mode"=> "full_terms_only", "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "FREE for 1st week! No1 Nokia tone 4 ur mob every week just txt NOKIA to 87077 Get txting and tell ur mates. zed POBox 36504 W45WQ norm150p/tone 16+"}, 'Cluster 0', 0.5],
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"token_mode"=> "full_terms_only", "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "Ok"}, 'Cluster 0', 0.478833312167],
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> true, "stem_words"=> true, "use_stopwords"=> false, "language"=> "en"}}}}, {"Type"=> "", "Message"=> ""}, 'Cluster 0', 0.707106781187],
           ['data/diabetes.csv', {"fields"=> {}}, {"pregnancies"=> 0, "plasma glucose"=> 118, "blood pressure"=> 84, "triceps skin thickness"=> 47, "insulin"=> 230, "bmi"=> 45.8, "diabetes pedigree"=> 0.551, "age"=> 31, "diabetes"=> "true"}, 'Cluster 3', 0.5033378686559257],
           ['data/iris_sp_chars.csv', {"fields"=> {}}, {"pétal.length"=>1, "pétal&width\u0000"=> 2, "sépal.length"=>1, "sépal&width"=> 2, "spécies"=> "Iris-setosa"}, 'Cluster 7', 0.8752380218327035],
           ['data/movies.csv', {"fields"=> {"000007"=> {"optype"=> "items", "item_analysis"=> {"separator"=> "$"}}}}, {"gender"=> "Female", "age_range"=> "18-24", "genres"=> "Adventure$Action", "timestamp"=> 993906291, "occupation"=> "K-12 student", "zipcode"=> 59583, "rating"=> 3}, 'Cluster 1', 0.7294650227133437]
           ]

    puts
    puts "Scenario: Successfully comparing centroids with or without text options:"
    data.each do |filename, options, data_input, centroid_name, distance|
        puts 
        puts "Given I create a data source uploading a <%s> file" % filename
        source = @api.create_source(File.dirname(__FILE__)+"/"+filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

        puts "And I wait until the source is ready"
        assert_equal(BigML::HTTP_CREATED, source["code"])
        assert_equal(1, source["object"]["status"]["code"])
        assert_equal(@api.ok(source), true)

        puts "And I update the source with params <%s>" % JSON.generate(options)
        source = @api.update_source(source, options)
        assert_equal(BigML::HTTP_ACCEPTED, source["code"])
        assert_equal(@api.ok(source), true)

        puts "And I create a dataset"
        dataset=@api.create_dataset(source)

        puts "And I wait until the dataset is ready"
        assert_equal(BigML::HTTP_CREATED, dataset["code"])
        assert_equal(1, dataset["object"]["status"]["code"])
        assert_equal(@api.ok(dataset), true)

        puts "And I create a cluster"
        cluster=@api.create_cluster(dataset, {'seed'=>'BigML tests','cluster_seed'=> 'BigML', 'k' => 8})
 
        puts "And I wait until the cluster is ready"
        assert_equal(BigML::HTTP_CREATED, cluster["code"])
        assert_equal(1, cluster["object"]["status"]["code"])
        assert_equal(@api.ok(cluster), true)
 
        puts "And I create a local cluster"
        local_cluster = BigML::Cluster.new(cluster["resource"], @api) 

        puts "When I create a centroid for <%s>" % JSON.generate(data_input)
        centroid = @api.create_centroid(cluster, data_input)

        puts "Then the centroid is <%s> with distance <%s>" % [centroid_name, distance]
        assert_equal(distance.round(6), centroid["object"]["distance"].round(6))
        assert_equal(centroid_name, centroid["object"]["centroid_name"])

        puts "And I create a local centroid for <%s>" % JSON.generate(data_input)
        local_centroid = local_cluster.centroid(data_input)

        puts "Then the local centroid is <%s> with distance <%s>" % [centroid_name,  distance]
        assert_equal(centroid_name, local_centroid["centroid_name"]) 
        assert_equal(distance.round(6), local_centroid["distance"].round(6))

    end 
  end

  def test_scenario5
     data = [[File.dirname(__FILE__)+'/data/iris.csv',{"summary_fields" => ["sepal width"], 'seed'=>'BigML tests','cluster_seed'=> 'BigML', 'k' => 8}, {"petal length" => 1, "petal width" => 1, "sepal length" => 1, "species" => "Iris-setosa"}, 'Cluster 2', 1.1643644909783857]]

     puts
     puts "Scenario: Successfully comparing centroids with summary fields:"

     data.each do |filename, options, data_input, centroid_name, distance|
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

        puts "And I create a cluster with options %s " % JSON.generate(options)
        cluster=@api.create_cluster(dataset, options)

        puts "And I wait until the cluster is ready"
        assert_equal(BigML::HTTP_CREATED, cluster["code"])
        assert_equal(1, cluster["object"]["status"]["code"])
        assert_equal(@api.ok(cluster), true)       

        puts "And I create a local cluster"
        local_cluster = BigML::Cluster.new(cluster["resource"], @api) 

        puts "When I create a centroid for <%s>" % JSON.generate(data_input)
        centroid = @api.create_centroid(cluster, data_input)

        puts "Then the centroid is <%s> with distance <%s>" % [centroid_name, distance]
        assert_equal(distance.round(6), centroid["object"]["distance"].round(6))
        assert_equal(centroid_name, centroid["object"]["centroid_name"])

        puts "And I create a local centroid for <%s>" % JSON.generate(data_input)
        local_centroid = local_cluster.centroid(data_input)

        puts "Then the local centroid is <%s> with distance <%s>" % [centroid_name,  distance]
        assert_equal(centroid_name, local_centroid["centroid_name"]) 
        assert_equal(distance.round(6), local_centroid["distance"].round(6)) 
 
     end
  end

  def test_scenario6
     data = [[File.dirname(__FILE__)+'/data/iris_missing2.csv', {"petal width" => 1}, '000004', 'Iris-setosa', 0.8064],
             [File.dirname(__FILE__)+'/data/iris_missing2.csv', {"petal width" => 1, "petal length"=> 4}, '000004', 'Iris-versicolor', 0.7847]]

     puts
     puts "Scenario: Successfully comparing predictions with proportional missing strategy for missing_splits models"

     data.each do |filename, data_input, objective, prediction_value, confidence|
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

        puts "And I create a model with missing splits"
        model=@api.create_model(dataset, {"missing_splits" => true})

        puts "And I wait until the model is ready"
        assert_equal(BigML::HTTP_CREATED, model["code"])
        assert_equal(1, model["object"]["status"]["code"])
        assert_equal(@api.ok(model), true)

        puts "And I create a local model"

        local_model = BigML::Model.new(model, @api)

        puts "When I create a proportional missing strategy prediction for <%s>" % JSON.generate(data_input)
        prediction = @api.create_prediction(model, data_input, {'missing_strategy' => 1})
        assert_equal(BigML::HTTP_CREATED, prediction["code"]);
        assert_equal(@api.ok(prediction), true)
 
        puts "Then the prediction for <%s> is <%s>" % [objective, prediction_value]
        assert_equal(prediction_value, prediction["object"]["prediction"][objective])

        puts "And the confidence for the prediction is <%s>" % confidence
        assert_equal(confidence.round(4), prediction["object"]["confidence"].round(4))

        puts "And I create a proportional missing strategy local prediction for <%s>" % JSON.generate(data_input)
        local_prediction = local_model.predict(data_input, true, false, $STDOUT, true, 1)

        puts "Then the local prediction is <%s>" % prediction_value

        if prediction_value.is_a?(Numeric)
           assert_equal(local_prediction[0].round(4), prediction_value.round(4))
        else
           assert_equal(local_prediction[0], prediction_value)
        end

        puts "And the local prediction's confidence is <%s>" % confidence
        assert_equal(local_prediction[1].round(3), confidence.round(3))
     end
  end

  def test_scenario7
     data = [[File.dirname(__FILE__)+'/data/tiny_kdd.csv', {"000020" => 255.0, "000004" => 183.0, "000016" => 4.0, "000024" => 0.04, "000025" => 0.01, "000026" => 0.0, "000019" => 0.25, "000017" => 4.0, "000018" => 0.25, "00001e" => 0.0, "000005" => 8654.0, "000009" => "0", "000023" => 0.01, "00001f" => 123.0}, 0.69802]]
     puts
     puts "Scenario: Successfully comparing scores from anomaly detectors"

     data.each do |filename, data_input, score|
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

        puts "And I create an anomaly detector"
        anomaly = @api.create_anomaly(dataset)

        puts "And I wait until the anomaly detector is ready"
        assert_equal(BigML::HTTP_CREATED, anomaly["code"])
        assert_equal(1, anomaly["object"]["status"]["code"])
        assert_equal(@api.ok(anomaly), true)

        puts "And I create a local anomaly detector"
        anomaly_local = BigML::Anomaly.new(anomaly, @api)

        puts "When I create an anomaly score for <%s>" % JSON.generate(data_input)
        anomaly_score = @api.create_anomaly_score(anomaly, data_input)
        assert_equal(BigML::HTTP_CREATED, anomaly_score["code"])          

        puts "Then the anomaly score is <score>" % score
        assert_equal(score.round(5), anomaly_score["object"]["score"].round(5))

        puts "And I create a local anomaly score for <%s>" % JSON.generate(data_input)
        local_anomaly_score = anomaly_local.anomaly_score(data_input, false)

        puts "Then the local anomaly score is <score>" % score
        assert_equal(score.round(5), local_anomaly_score.round(5))
     end
  end

  def test_scenario8
     data = [['data/iris.csv',{"petal width" => 0.5, "petal length" => 0.5, "sepal width" => 0.5, "sepal length" => 0.5}, 'Iris-virginica'],
             ['data/iris.csv',{"petal width" => 2, "petal length" => 6, "sepal width" => 0.5, "sepal length" => 0.5}, 'Iris-virginica'],
             ['data/iris.csv',{"petal width" => 1.5, "petal length" => 4, "sepal width" => 0.5, "sepal length" => 0.5}, 'Iris-virginica'],
             ['data/iris.csv',{"petal length" => 1}, 'Iris-virginica'],
             ['data/iris_sp_chars.csv', {"pétal.length" => 4, "pétal&width\u0000" => 1.5, "sépal&width" => 0.5, "sépal.length" => 0.5}, 'Iris-virginica'],
             ['data/price.csv', {"Price" => 1200}, 'Product2']
            ]
     puts
     puts "Scenario: Successfully comparing logistic regression predictions"

     data.each do |filename, data_input, prediction_result|
        puts
        puts "Given I create a data source uploading a <%s> file" % filename
        source = @api.create_source(File.dirname(__FILE__)+"/"+filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

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

        puts "And I create a logistic regression model"
        logistic_regression = @api.create_logisticregression(dataset)
        
        puts "And I wait until the logistic regression model is ready"
        assert_equal(BigML::HTTP_CREATED, logistic_regression["code"])
        assert_equal(@api.ok(logistic_regression), true)

        puts "And I create a local logistic regression model"
        localLogisticRegression = BigML::Logistic.new(logistic_regression)

        puts "When I create a logistic regression prediction for <%s>" % JSON.generate(data_input)
        prediction = @api.create_prediction(logistic_regression, data_input)
        assert_equal(BigML::HTTP_CREATED, prediction["code"])

        puts "Then the logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, prediction["object"]["output"])

        puts "And I create a local logistic regression prediction for <%s>" % JSON.generate(data_input)
        local_prediction = localLogisticRegression.predict(data_input)

        puts "Then the local logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, local_prediction["prediction"])

     end
  end

  def test_scenario9
     data = [['data/spam.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive" => true, "stem_words" => true, "use_stopwords" => false, "language" => "en"}}}}, {"Message" => "Mobile call"}, 'spam'],
             ['data/spam.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive" => true, "stem_words" => true, "use_stopwords"=> false, "language"=> "en"}}}}, {"Message"=> "A normal message"}, 'spam'],
             ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> false, "use_stopwords"=> false, "language"=> "en"}}}}, {"Message"=> "Mobile calls"}, 'spam'],
             ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> false, "use_stopwords"=> false, "language"=> "en"}}}}, {"Message"=> "A normal message"}, 'ham'],
             ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> true, "use_stopwords"=> true, "language"=> "en"}}}}, {"Message"=> "Mobile call"}, 'spam'],
             ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> true, "use_stopwords"=> true, "language"=> "en"}}}}, {"Message"=> "A normal message"}, 'spam'],
             ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"token_mode"=> "full_terms_only", "language"=> "en"}}}}, {"Message"=> "FREE for 1st week! No1 Nokia tone 4 ur mob every week just txt NOKIA to 87077 Get txting and tell ur mates. zed POBox 36504 W45WQ norm150p/tone 16+"}, 'spam'],
             ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"token_mode"=> "full_terms_only", "language"=> "en"}}}}, {"Message"=> "Ok"}, 'ham']
]

     puts
     puts "Successfully comparing predictions with text options"

     data.each do |filename, options, data_input, prediction_result|
        puts
        puts "Given I create a data source uploading a <%s> file" % filename
        source = @api.create_source(File.dirname(__FILE__)+"/"+filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

        puts "And I wait until the source is ready"
        assert_equal(BigML::HTTP_CREATED, source["code"])
        assert_equal(1, source["object"]["status"]["code"])
        assert_equal(@api.ok(source), true)

        puts "And I update the source with params <%s>" % JSON.generate(options)
        source = @api.update_source(source, options)
        assert_equal(BigML::HTTP_ACCEPTED, source["code"])
        assert_equal(@api.ok(source), true)

        puts "And I create a dataset"
        dataset=@api.create_dataset(source)

        puts "And I wait until the dataset is ready"
        assert_equal(BigML::HTTP_CREATED, dataset["code"])
        assert_equal(1, dataset["object"]["status"]["code"])
        assert_equal(@api.ok(dataset), true)

        puts "And I create a logistic regression model"
        logistic_regression = @api.create_logisticregression(dataset)
        
        puts "And I wait until the logistic regression model is ready"
        assert_equal(BigML::HTTP_CREATED, logistic_regression["code"])
        assert_equal(@api.ok(logistic_regression), true)
        puts "And I create a local logistic regression model"
        localLogisticRegression = BigML::Logistic.new(logistic_regression)

        puts "When I create a logistic regression prediction for <%s>" % JSON.generate(data_input)
        prediction = @api.create_prediction(logistic_regression, data_input)
        assert_equal(BigML::HTTP_CREATED, prediction["code"])

        puts "Then the logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, prediction["object"]["output"])

        puts "And I create a local logistic regression prediction for <%s>" % JSON.generate(data_input)
        local_prediction = localLogisticRegression.predict(data_input)

        puts "Then the local logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, local_prediction["prediction"])

     end
  end

  def test_scenario10
     data = [
            ['data/spam.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"token_mode" => "full_terms_only", "language" => "en"}}}}, {"Message" => "A normal message"}, 'ham', 0.7645, "000000"],
            ['data/spam.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"token_mode" => "all", "language" => "en"}}}}, {"Message" => "mobile"}, 'spam', 0.7174, "000000"],
            ['data/movies.csv', {"fields" => {"000007" => {"optype" => "items", "item_analysis" => {"separator" => "$"}}}}, {"gender" => "Female", "genres" => "Adventure$Action", "timestamp" => 993906291, "occupation" => "K-12 student", "zipcode" => 59583, "rating" => 3}, '25-34', 0.4135, '000002']
            ]

     puts ""
     puts "Scenario: Successfully comparing predictions with text options"

     data.each do |filename, options, data_input, prediction_result, probability, objective|
        puts
        puts "Given I create a data source uploading a <%s> file" % filename

        source = @api.create_source(File.dirname(__FILE__)+"/"+filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

        puts "And I wait until the source is ready"
        assert_equal(BigML::HTTP_CREATED, source["code"])
        assert_equal(1, source["object"]["status"]["code"])
        assert_equal(@api.ok(source), true)

        puts "And I update the source with params <%s>" % JSON.generate(options)
        source = @api.update_source(source, options)
        assert_equal(BigML::HTTP_ACCEPTED, source["code"])
        assert_equal(@api.ok(source), true)

        puts "And I create a dataset"
        dataset=@api.create_dataset(source)

        puts "And I wait until the dataset is ready"
        assert_equal(BigML::HTTP_CREATED, dataset["code"])
        assert_equal(1, dataset["object"]["status"]["code"])
        assert_equal(@api.ok(dataset), true)
        puts "And I create a logistic regression model with objective <%s>" % objective
        logistic_regression = @api.create_logisticregression(dataset, {'objective_field' => objective})
        
        puts "And I wait until the logistic regression model is ready"
        assert_equal(BigML::HTTP_CREATED, logistic_regression["code"])
        assert_equal(@api.ok(logistic_regression), true)

        puts "And I create a local logistic regression model"
        localLogisticRegression = BigML::Logistic.new(logistic_regression)

        puts "When I create a logistic regression prediction for <%s>" % JSON.generate(data_input)
        prediction = @api.create_prediction(logistic_regression, data_input)
        assert_equal(BigML::HTTP_CREATED, prediction["code"])

        puts "Then the logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, prediction["object"]["output"])

        puts "And the logistic regression probability for the prediction is <%s>" % probability

        prediction["object"]["probabilities"].each do |prediction_value, remote_probability|
           if prediction_value == prediction["object"]["output"]
              assert_equal(remote_probability.to_f.round(2),probability.round(2))
              break
           end
        end

        puts "And I create a local logistic regression prediction for <%s>" % JSON.generate(data_input)
        local_prediction = localLogisticRegression.predict(data_input)

        puts "Then the local logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, local_prediction["prediction"])

        puts "And the local logistic regression probability for the prediction is <%s>" % probability
        assert_equal(probability.round(4), local_prediction["probability"].round(4))

     end
  end

  def test_scenario11
     data = [
             ['data/text_missing.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"token_mode" => "all", "language" => "en"}}, "000000" => {"optype" => "text", "term_analysis" => {"token_mode" => "all", "language" => "en"}}}}, {}, "000003",'swap'],
             ['data/text_missing.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"token_mode" => "all", "language" => "en"}}, "000000" => {"optype" => "text", "term_analysis" => {"token_mode" => "all", "language" => "en"}}}}, {"category1" => "a"}, "000003",'paperwork']
            ]

     puts 
     puts "Scenario: Successfully comparing predictions with text options and proportional missing strategy"

     data.each do |filename, options, data_input, objective, prediction_result|
        puts
        puts "Given I create a data source uploading a <%s> file" % filename

        source = @api.create_source(File.dirname(__FILE__)+"/"+filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

        puts "And I wait until the source is ready"
        assert_equal(BigML::HTTP_CREATED, source["code"])
        assert_equal(1, source["object"]["status"]["code"])
        assert_equal(@api.ok(source), true)

        puts "And I update the source with params <%s>" % JSON.generate(options)
        source = @api.update_source(source, options)
        assert_equal(BigML::HTTP_ACCEPTED, source["code"])
        assert_equal(@api.ok(source), true)

        puts "And I create a dataset"
        dataset=@api.create_dataset(source)

        puts "And I wait until the dataset is ready"
        assert_equal(BigML::HTTP_CREATED, dataset["code"])
        assert_equal(1, dataset["object"]["status"]["code"])
        assert_equal(@api.ok(dataset), true)

        puts "And I create a model"
        model=@api.create_model(dataset)

        puts "And I wait until the model is ready"
        assert_equal(BigML::HTTP_CREATED, model["code"])
        assert_equal(1, model["object"]["status"]["code"])
        assert_equal(@api.ok(model), true)

        puts "And I create a local model"
        local_model = BigML::Model.new(model, @api)

        puts "When I create a proportional missing strategy prediction for <%s>" % JSON.generate(data_input)
        prediction = @api.create_prediction(model, data_input, {"missing_strategy" => 1})
        assert_equal(BigML::HTTP_CREATED, prediction["code"])

        puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
        assert_equal(prediction_result, prediction["object"]["prediction"][objective])

        puts "And I create a proportional missing strategy local prediction for <%s>" % JSON.generate(data_input)
        local_prediction = local_model.predict(data_input, true, false, $STDOUT, true, 1)

        puts "Then the local prediction is <%s>" % prediction_result
        assert_equal(prediction_result, local_prediction[0])

     end
  end

  def test_scenario12
     data = [
            ['data/iris.csv', {"fields" => {"000000" => {"optype" => "categorical"}}}, {"species" => "Iris-setosa"}, 5.0, 0.02857, "000000", {"field_codings" => [{"field" => "species", "coding" => "dummy", "dummy_class" => "Iris-setosa"}]}],
            ['data/iris.csv', {"fields" => {"000000" => {"optype" => "categorical"}}}, {"species" => "Iris-setosa"}, 5.5, 0.04293, "000000", {"field_codings" => [{"field" => "species", "coding" => "contrast", "coefficients" => [[1, 2, -1, -2]]}]}],
            ['data/iris.csv', {"fields" => {"000000" => {"optype" => "categorical"}}}, {"species" => "Iris-setosa"}, 5.5, 0.04293, "000000", {"field_codings" => [{"field" => "species", "coding" => "other", "coefficients" => [[1, 2, -1, -2]]}]}]
            ]

     puts
     puts "Scenario: Successfully comparing predictions with text options:"
     data.each do |filename, options, data_input, prediction_result, probability, objective, params|
        puts
        puts "Given I create a data source uploading a <%s> file" % filename

        source = @api.create_source(File.dirname(__FILE__)+"/"+filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

        puts "And I wait until the source is ready"
        assert_equal(BigML::HTTP_CREATED, source["code"])
        assert_equal(1, source["object"]["status"]["code"])
        assert_equal(@api.ok(source), true)

        puts "And I update the source with params <%s>" % JSON.generate(options)
        source = @api.update_source(source, options)
        assert_equal(BigML::HTTP_ACCEPTED, source["code"])
        assert_equal(@api.ok(source), true)        

        puts "And I create a dataset"
        dataset=@api.create_dataset(source)

        puts "And I wait until the dataset is ready"
        assert_equal(BigML::HTTP_CREATED, dataset["code"])
        assert_equal(1, dataset["object"]["status"]["code"])
        assert_equal(@api.ok(dataset), true)

        puts "And I create a logistic regression model with 
              objective <objective> and params <%s>" % [objective, JSON.generate(params)]
        logistic_regression = @api.create_logisticregression(dataset, params.merge({'objective_field' => objective}))
        
        puts "And I wait until the logistic regression model is ready"
        assert_equal(BigML::HTTP_CREATED, logistic_regression["code"])
        assert_equal(@api.ok(logistic_regression), true)

        puts "And I create a local logistic regression model"
        localLogisticRegression = BigML::Logistic.new(logistic_regression)

        puts "When I create a logistic regression prediction for <%s>" % JSON.generate(data_input)
        prediction = @api.create_prediction(logistic_regression, data_input)
        assert_equal(BigML::HTTP_CREATED, prediction["code"])

        puts "Then the logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, prediction["object"]["output"].to_f)

        puts "And the logistic regression probability for the prediction is <%s>" % probability
        prediction["object"]["probabilities"].each do |prediction_value, remote_probability|
           if prediction_value == prediction["object"]["output"]
              assert_equal(remote_probability.to_f.round(2),probability.round(2))
              break
           end
        end

        puts "And I create a local logistic regression prediction for <%s>" % JSON.generate(data_input)
        local_prediction = localLogisticRegression.predict(data_input)

        puts "Then the local logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, local_prediction["prediction"].to_f)

        puts "And the local logistic regression probability for the prediction is <%s>" % probability
        assert_equal(probability.round(4), local_prediction["probability"].round(4))
     end
  end

  def test_scenario13
     data = [['data/iris_unbalanced.csv', {}, '000004', 'Iris-setosa', 0.25284],
             ['data/iris_unbalanced.csv', {"petal length" => 1, "sepal length" => 1, "petal width" => 1, "sepal width" => 1}, '000004', 'Iris-setosa', 0.7575]]

     puts
     puts "Scenario: Successfully comparing predictions with proportional missing strategy and balanced models"

     data.each do |filename, data_input, objective, prediction_result, confidence|
        puts
        puts "Given I create a data source uploading a <%s> file" % filename

        source = @api.create_source(File.dirname(__FILE__)+"/"+filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

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

        puts "And I create a balanced model"
        model=@api.create_model(dataset, {"missing_splits" => false, "balance_objective" => true})

        puts "And I wait until the model is ready"
        assert_equal(BigML::HTTP_CREATED, model["code"])
        assert_equal(1, model["object"]["status"]["code"])
        assert_equal(@api.ok(model), true)
 
        puts "And I create a local model"
        local_model = BigML::Model.new(model, @api)

        puts "When I create a proportional missing strategy prediction for <%s>" % JSON.generate(data_input)
        prediction = @api.create_prediction(model, data_input, {"missing_strategy" => 1})
        assert_equal(BigML::HTTP_CREATED, prediction["code"])

        puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
        assert_equal(prediction_result, prediction["object"]["prediction"][objective])

        puts "And the confidence for the prediction is <%s>" % confidence
        assert_equal(confidence.round(4), prediction["object"]["confidence"].round(4))

        puts "And I create a proportional missing strategy local prediction for <%s>" % JSON.generate(data_input)
        local_prediction = local_model.predict(data_input, true, false, $STDOUT, true, BigML::PROPORTIONAL)

        puts "Then the local prediction is <%s>" % prediction_result

        if prediction_result.is_a?(Numeric)
           assert_equal(local_prediction[0].round(4), prediction_result.round(4))
        else
           assert_equal(local_prediction[0], prediction_result)
        end
        puts "And the local prediction's confidence is <%s>" % confidence
        assert_equal(local_prediction[1].round(2), confidence.round(2))

     end
  end

end

