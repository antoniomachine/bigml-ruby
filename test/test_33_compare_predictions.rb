require_relative "../lib/bigml/api"
require_relative "../lib/bigml/cluster"
require_relative "../lib/bigml/anomaly"
require_relative "../lib/bigml/topicmodel"
require_relative "../lib/bigml/association"
require_relative "../lib/bigml/ensemble"
require_relative "../lib/bigml/model"
require_relative "../lib/bigml/multimodel"
require_relative "../lib/bigml/ensemblepredictor"
require_relative "../lib/bigml/supervised"
require_relative "../lib/bigml/fusion"

require "test/unit"

class Test33ComparePredictions < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  #  "Scenario: Successfully comparing centroids with or without text options:"
  def test_scenario1
    
    data = [
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype": "text", "term_analysis"=> {"case_sensitive"=> true, "stem_words"=> true, "use_stopwords"=> false, "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "Mobile call"}, 'Cluster 0', 0.25],
           ['data/spam.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive" => true, "stem_words" => true, "use_stopwords" => false}}}}, {"Type" => "ham", "Message" => "A normal message"}, 'Cluster 0', 0.5],
           ['data/spam.csv', {"fields": {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> false, "use_stopwords"=> false, "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "Mobile calls"}, 'Cluster 0', 0.5],
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> false, "use_stopwords"=> false, "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "A normal message"}, 'Cluster 0', 0.5],
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> true, "use_stopwords"=> true, "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "Mobile call"}, 'Cluster 0', 0.5],
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> true, "use_stopwords"=> true, "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "A normal message"}, 'Cluster 1', 0.36637],
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"token_mode"=> "full_terms_only", "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "FREE for 1st week! No1 Nokia tone 4 ur mob every week just txt NOKIA to 87077 Get txting and tell ur mates. zed POBox 36504 W45WQ norm150p/tone 16+"}, 'Cluster 0', 0.5],
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"token_mode"=> "full_terms_only", "language"=> "en"}}}}, {"Type"=> "ham", "Message"=> "Ok"}, 'Cluster 0', 0.478833312167],
           ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> true, "stem_words"=> true, "use_stopwords"=> false, "language"=> "en"}}}}, {"Type"=> "", "Message"=> ""}, 'Cluster 6', 0.5],
           ['data/diabetes.csv', {"fields"=> {}}, {"pregnancies"=> 0, "plasma glucose"=> 118, "blood pressure"=> 84, "triceps skin thickness"=> 47, "insulin"=> 230, "bmi"=> 45.8, "diabetes pedigree"=> 0.551, "age"=> 31, "diabetes"=> true}, 'Cluster 3', 0.5033378686559257],
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
        assert_equal(distance.round(5), centroid["object"]["distance"].round(5))
        assert_equal(centroid_name, centroid["object"]["centroid_name"])

        puts "And I create a local centroid for <%s>" % JSON.generate(data_input)
        local_centroid = local_cluster.centroid(data_input)

        puts "Then the local centroid is <%s> with distance <%s>" % [centroid_name,  distance]
        assert_equal(centroid_name, local_centroid["centroid_name"])
        assert_equal(distance.round(5), local_centroid["distance"].round(5))

    end 
  end
  
  # Scenario: Successfully comparing centroids with configuration options:
  def test_scenario2

     data = [[File.dirname(__FILE__)+'/data/iris.csv',{"summary_fields" => ["sepal width"], 'seed'=>'BigML tests','cluster_seed'=> 'BigML', 'k' => 8}, {"petal length" => 1, "petal width" => 1, "sepal length" => 1, "species" => "Iris-setosa"}, 'Cluster 2', 1.16436, {"petal length" => 1, "petal width" => 1, "sepal length" => 1, "species" => "Iris-setosa"}],
             [File.dirname(__FILE__)+'/data/iris.csv', {"default_numeric_value" => "zero"}, {"petal length" => 1}, 'Cluster 1', 1.56481, {"petal length" => 1, "petal width" => 0, "sepal length" => 0, "sepal width" => 0, "species" => ""}]]

     puts
     puts "Scenario: Successfully comparing centroids with configuration options:"

     data.each do |filename, options, data_input, centroid_name, distance, full_data_input|
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

        puts "When I create a centroid for <%s>" % JSON.generate(full_data_input)
        centroid = @api.create_centroid(cluster, full_data_input)

        puts "Then the centroid is <%s> with distance <%s>" % [centroid_name, distance]
        assert_equal(distance.round(5), centroid["object"]["distance"].round(5))
        assert_equal(centroid_name, centroid["object"]["centroid_name"])

        puts "And I create a local centroid for <%s>" % JSON.generate(data_input)
        local_centroid = local_cluster.centroid(data_input)

        puts "Then the local centroid is <%s> with distance <%s>" % [centroid_name,  distance]
        assert_equal(centroid_name, local_centroid["centroid_name"]) 
        assert_equal(distance.round(5), local_centroid["distance"].round(5))

     end
  end
  
  # Scenario: Successfully comparing scores from anomaly detectors
  def test_scenario3
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
        local_anomaly_score = anomaly_local.anomaly_score(data_input)

        puts "Then the local anomaly score is <score>" % score
        assert_equal(score.round(5), local_anomaly_score.round(5))
     end
  end
  
  # Scenario: Successfully comparing topic distributions:
  def test_scenario4
    
     data = [[File.dirname(__FILE__)+'/data/spam.csv', {"fields" => {"000001" => {"optype": "text", "term_analysis" => {"case_sensitive" => true, "stem_words" => true, "use_stopwords" => false, "language" => "en"}}}}, {"Type" => "ham", "Message" => "Mobile call"}, [0.51133, 0.00388, 0.00574, 0.00388, 0.00388, 0.00388, 0.00388, 0.00388, 0.00388, 0.00388, 0.00388, 0.44801]],
             [File.dirname(__FILE__)+'/data/spam.csv', {"fields" => {"000001" => {"optype": "text", "term_analysis" => {"case_sensitive" => true, "stem_words" => true, "use_stopwords" => false, "language" => "en"}}}}, {"Type" => "ham", "Message" => "Go until jurong point, crazy.. Available only in bugis n great world la e buffet... Cine there got amore wat..."}, [0.39188, 0.00643, 0.00264, 0.00643, 0.08112, 0.00264, 0.37352, 0.0115, 0.00707, 0.00327, 0.00264, 0.11086]]
            ]
     puts
     puts "Scenario: Successfully comparing topic distributions:"

     data.each do |filename, options, data_input, topic_distribution_result|
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
        
        puts "And I create a dataset"
        dataset=@api.create_dataset(source)

        puts "And I wait until the dataset is ready"
        assert_equal(BigML::HTTP_CREATED, dataset["code"])
        assert_equal(1, dataset["object"]["status"]["code"])
        assert_equal(@api.ok(dataset), true)
        
        puts "And I create a topic model"
        topic_model=@api.create_topic_model(dataset, {'seed' => 'BigML', 'topicmodel_seed' => 'BigML'})
        puts "And I wait until the topic model is ready"
        assert_equal(BigML::HTTP_CREATED, topic_model["code"])
        assert_equal(1, topic_model["object"]["status"]["code"])
        assert_equal(@api.ok(topic_model), true)
        
        puts "And I create a local topic model"
        local_topic_model = BigML::TopicModel.new(topic_model)
        
        puts "And I create a local topic distribution for <%s>" % JSON.generate(data_input)
        topic_distribution = @api.create_topic_distribution(topic_model, data_input)
        assert_equal(BigML::HTTP_CREATED, topic_distribution["code"])
        assert_equal(@api.ok(topic_distribution), true)
        
        puts "Then the local topic distribution is <%s>" %  JSON.generate(topic_distribution_result)
        assert_equal(topic_distribution_result, topic_distribution['object']['topic_distribution']['result'])
        
        puts "When I create a topic distribution for '<%s>" % JSON.generate(data_input)
        local_topic_distribution = local_topic_model.distribution(data_input)
        
        puts "Then the topic distribution is <%s>" % JSON.generate(topic_distribution_result)
        local_topic_distribution.each_with_index do |topic_dist, index|
          assert_equal(topic_dist["probability"].round(5), topic_distribution_result[index].round(5))
        end  
        
      
    end
    
  end
  
  # Scenario: Successfully comparing topic distributions:
  def test_scenario5
    
     data = [[File.dirname(__FILE__)+'/data/groceries.csv', 
             {"fields" => {"00000" => {"optype" => "text", 
                                       "term_analysis" => {"token_mode" => "all", 
                                                           "language" => "en"}}}},
              File.dirname(__FILE__)+'/data/associations/association_set.json',
              {"field1" => "cat food"}
              ]
            ]
     puts
     puts "Scenario: Successfully comparing topic distributions:"

     data.each do |filename, options, association_set_file, data_input|
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
        
        puts "And I create a dataset"
        dataset=@api.create_dataset(source)

        puts "And I wait until the dataset is ready"
        assert_equal(BigML::HTTP_CREATED, dataset["code"])
        assert_equal(1, dataset["object"]["status"]["code"])
        assert_equal(@api.ok(dataset), true)
        
        puts "And I create an_association from dataset"
        association=@api.create_association(dataset, {'name' => 'new_association'})

        puts "And I wait until the association is ready"
        assert_equal(BigML::HTTP_CREATED, association["code"])
        assert_equal(1, association["object"]["status"]["code"])
        assert_equal(@api.ok(association), true)
        
        puts "And I create a local association"
        local_association = BigML::Association.new(association)
        
        puts "And I create a association set %s" % JSON.generate(data_input)
        association_set=@api.create_association_set(association, data_input)
        
        puts "And I wait until the association is ready"
        assert_equal(BigML::HTTP_CREATED, association_set["code"])
        assert_equal(@api.ok(association_set), true)
        
        puts "Then the association set is like the contents of <%s>" % association_set_file
        result = association_set["object"].fetch("association_set",{}).fetch("result", [])
        
        assert_equal(result, JSON.parse(File.read(association_set_file)))
        
        puts "And I create a local association set for <%s>" % JSON.generate(data_input)
        local_association_set = local_association.association_set(data_input)
        
        puts "Then the local association set is like the contents of <%s>" %  association_set_file
        assert_equal(local_association_set,JSON.parse(File.read(association_set_file)))
        
      end
   end  
   
   # Successfully comparing predictions for ensembles
   def test_scenario6
    
      data = [[File.dirname(__FILE__)+'/data/iris_unbalanced.csv', 
               {"petal width" => 4},
               '000004',
               'Iris-virginica',
               {"boosting" => {"iterations" => 5}, "number_of_models" => 5}
               ],
               [File.dirname(__FILE__)+'/data/grades.csv', 
                 {"Midterm" => 20},
                  '000005',
                  61.61036, #TODO
                  {"boosting" => {"iterations" => 5}, "number_of_models" => 5}
                ]
             ]
      puts
      puts "Successfully comparing predictions for ensembles:"

      data.each do |filename, data_input, objective, prediction_result, params|
        
         extra_params={'seed' => 'BigML', 'ensemble_sample' => {"rate" => 0.7, "seed" => 'BigML'}}
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
         
         puts "And I create an ensemble with <%s>" % JSON.generate(params)
              
         ensemble = @api.create_ensemble(dataset, params.merge(extra_params))
         
         puts "And I wait until the ensemble is ready"
         assert_equal(BigML::HTTP_CREATED, ensemble["code"])
         assert_equal(1, ensemble["object"]["status"]["code"])
         assert_equal(@api.ok(ensemble), true)
         
         puts "And I create a local ensemble"
         local_ensemble = BigML::Ensemble.new(ensemble, @api)
         local_model = BigML::Model.new(local_ensemble.model_ids[0], @api)
         
         puts "When I create a prediction for <%s>" % JSON.generate(data_input)
         prediction = @api.create_prediction(ensemble, data_input)
         
         assert_equal(BigML::HTTP_CREATED, prediction["code"])
         assert_equal(@api.ok(prediction), true)
         
         puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
         assert_equal(prediction['object']['prediction'][objective], prediction_result)
         
         puts "And I create a local prediction for <%s>" % JSON.generate(data_input)
         local_prediction = local_ensemble.predict(data_input, {"full" => true})
         
         puts "Then the local prediction is <%s>" %  prediction_result
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
           if prediction_result.is_a?(Float)
             assert_equal(local_prediction.round(5), prediction_result.round(5)) 
           else
             assert_equal(local_prediction, prediction_result) 
           end    
         end    
                 
      end
      
    end  
    
    # Scenario: Successfully comparing predictions for ensembles with proportional missing strategy
    def test_scenario7
       data = [
               [File.dirname(__FILE__)+'/data/iris.csv', 
                {},
                '000004',
                'Iris-virginica',
                 0.33784,
                {"boosting" => {"iterations" => 5}},
                {}
                ],
                [File.dirname(__FILE__)+'/data/iris.csv', 
                {},
                '000004',
                'Iris-versicolor',
                0.2923,#0.27261,
                {"number_of_models" =>  5},
                {"operating_kind" => "confidence"}
                 ],
                 [File.dirname(__FILE__)+'/data/grades.csv', 
                 {},
                 '000005',
                 70.505792,
                 30.7161,
                 {"number_of_models" => 5},
                 {}
                  ],
                 [File.dirname(__FILE__)+'/data/grades.csv', 
                  {"Midterm" => 20},
                  '000005',
                  54.82214,
                  25.89672,
                  {"number_of_models" => 5},
                  {"operating_kind" => "confidence"}
                   ],
                 [File.dirname(__FILE__)+'/data/grades.csv', 
                  {"Midterm" => 20},
                  '000005',
                  45.4573,
                  29.58403,
                  {"number_of_models" => 5},
                  {}
                   ],
                 [File.dirname(__FILE__)+'/data/grades.csv', 
                  {"Midterm" => 20, "Tutorial" => 90, "TakeHome" => 100},
                  '000005',
                  42.814,
                  31.51804,
                  {"number_of_models" => 5},
                  {}
                   ]
              ]
       puts
       puts "Scenario: Successfully comparing predictions for ensembles with proportional missing strategy"

       data.each do |filename, data_input, objective, prediction_result, confidence, params, args|
          params.merge!({'seed' =>  'BigML', 'ensemble_sample' => {"rate" => 0.7, "seed"=> 'BigML'}})
          
          args.merge!({"missing_strategy" => 1})
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
         
          puts "And I create an ensemble with <%s>" % JSON.generate(params)
          ensemble = @api.create_ensemble(dataset, params)
         
          puts "And I wait until the ensemble is ready"
          assert_equal(BigML::HTTP_CREATED, ensemble["code"])
          assert_equal(1, ensemble["object"]["status"]["code"])
          assert_equal(@api.ok(ensemble), true)
          
          puts "And I create a local ensemble"
          local_ensemble = BigML::Ensemble.new(ensemble, @api)
          local_model = BigML::Model.new(local_ensemble.model_ids[0], @api)
          
          puts "When I create a proportional missing strategy prediction for <%s>" % JSON.generate(data_input)
          
          prediction = @api.create_prediction(ensemble, data_input, args)
         
          assert_equal(BigML::HTTP_CREATED, prediction["code"])
          assert_equal(@api.ok(prediction), true)
          
          puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
          assert_equal(prediction['object']['prediction'][objective].to_f.round(4), prediction_result.to_f.round(4))
          
          puts "And the confidence for the prediction is <%s>" % confidence
          
          local_confidence = prediction['object'].key?('confidence') ? 
                                   prediction['object']['confidence'] : 
                                   prediction['object']['probability']
          
          assert_equal(local_confidence.to_f.round(4), confidence.round(4))
          
          puts "And I create a proportional missing strategy local prediction for <%s>" %  JSON.generate(data_input)
          local_prediction = local_ensemble.predict(data_input, args.merge({"full" => true, "missing_strategy"=> 1}))
          
          puts "Then the local prediction is <%s>" %  prediction_result
                 
          if local_prediction.is_a?(Array)
            prediction = local_prediction[0]
          elsif local_prediction.is_a?(Hash)
             prediction = local_prediction['prediction']
          else
             prediction = local_prediction
          end    

          if (local_ensemble.regression)# or 
            #(local_model.is_a?(BigML::MultiModel) and local_model.models[0].regression)
            assert_equal(prediction.to_f.round(4), prediction_result.to_f.round(4))
          else
            assert_equal(prediction, prediction_result) 
          end
                   
          puts "And the local prediction's confidence is <%s>" % confidence
          if local_prediction.is_a?(Array)
            local_confidence = local_prediction[1]
          elsif local_prediction.is_a?(Hash)
            local_confidence = local_prediction.key?('confidence') ? 
                                   local_prediction['confidence'] : 
                                   local_prediction['probability'] 
          else
             local_confidence = local_prediction
          end    
          
          assert_equal(local_confidence.to_f.round(3), confidence.round(3))
       end
     end 
     
     # Scenario: Successfully comparing predictions for ensembles
     def test_scenario8
       data = [['ensemble.json', 
                File.dirname(__FILE__)+'/data/ensemble_predictor/',
                {"petal width" => 4},
                68.1258030739]
               ]
       # TODO
     end  

     # Scenario: Successfully comparing predictions for ensembles with proportional missing strategy in a supervised model:
     def test_scenario9
        data = [[File.dirname(__FILE__)+'/data/iris.csv', {}, '000004', 
                'Iris-virginica', 0.33784, {"boosting" => {"iterations" => 5}}, {}],
                #[File.dirname(__FILE__)+'/data/iris.csv', {}, '000004', 
                #'Iris-versicolor', 0.27261, {"number_of_models" => 5}, {"operating_kind" => "confidence"}]
                ]
        
        puts
        puts "Scenario: Successfully comparing predictions for ensembles with proportional missing strategy in a supervised model"
                
        data.each do |filename, data_input, objective, prediction_result, confidence, params, args|
          
          extra_params = {'seed' =>  'BigML', 'ensemble_sample' => {"rate" => 0.7, "seed"=> 'BigML'}}
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
          
          puts "And I create an ensemble with <%s>" % JSON.generate(params)
          ensemble = @api.create_ensemble(dataset, params.merge(extra_params))
         
          puts "And I wait until the ensemble is ready"
          assert_equal(BigML::HTTP_CREATED, ensemble["code"])
          assert_equal(1, ensemble["object"]["status"]["code"])
          assert_equal(@api.ok(ensemble), true)
          
          puts "And I create local supervised ensemble"
          local_ensemble = BigML::SupervisedModel.new(ensemble["resource"], @api)
          
          puts "When I create a proportional missing strategy prediction for <%s>" % JSON.generate(data_input)
          
          prediction = @api.create_prediction(ensemble, data_input, args.merge({"missing_strategy" => 1}))
         
          assert_equal(BigML::HTTP_CREATED, prediction["code"])
          assert_equal(@api.ok(prediction), true)
          
          puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
          assert_equal(prediction['object']['prediction'][objective].to_f.round(4), prediction_result.to_f.round(4))
          
          puts "And the confidence for the prediction is <%s>" % confidence
          
          local_confidence = prediction['object'].key?('confidence') ? 
                                   prediction['object']['confidence'] : 
                                   prediction['object']['probability']
          
          assert_equal(local_confidence.to_f.round(4), confidence.round(4))
          
          puts "And I create a proportional missing strategy local prediction for <%s>" %  JSON.generate(data_input)
          local_prediction = local_ensemble.predict(data_input, args.merge({"full" => true, "missing_strategy"=> 1}))
          
          puts "Then the local prediction is <%s>" %  prediction_result
                 
          if local_prediction.is_a?(Array)
            prediction = local_prediction[0]
          elsif local_prediction.is_a?(Hash)
             prediction = local_prediction['prediction']
          else
             prediction = local_prediction
          end    

          if (local_ensemble.regression)
            assert_equal(prediction.to_f.round(4), prediction_result.to_f.round(4))
          else
            assert_equal(prediction, prediction_result) 
          end
                   
          puts "And the local prediction's confidence is <%s>" % confidence
          if local_prediction.is_a?(Array)
            local_confidence = local_prediction[1]
          elsif local_prediction.is_a?(Hash)
            local_confidence = local_prediction.key?('confidence') ? 
                                   local_prediction['confidence'] : 
                                   local_prediction['probability'] 
          else
             local_confidence = local_prediction
          end    
          
          assert_equal(local_confidence.to_f.round(3), confidence.round(3))
          
        end  
     end
     
     # Scenario: Successfully comparing predictions for fusions:
     def test_scenario10
        data = [[File.dirname(__FILE__)+'/data/iris_unbalanced.csv', 
                 {"tags" => ["my_fusion_tag"]}, 
                 'my_fusion_tag', 
                 {"petal width" => 4},
                 '000004',
                 'Iris-virginica'],
                [File.dirname(__FILE__)+'/data/grades.csv', 
                 {"tags" => ["my_fusion_tag_reg"]}, 
                 'my_fusion_tag_reg', 
                 {"Midterm" => 20},
                 '000005',
                 43.65286]
               ]
        
        puts
        puts "Scenario: Successfully comparing predictions for fusions:"
                
        data.each do |filename, params, tag, data_input, objective, prediction_result|
          
          extra_params = {'seed' =>  'BigML', 'ensemble_sample' => {"rate" => 0.7, "seed"=> 'BigML'}}
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
          
          puts "And I create a fusion from a list of models"
          fusion = @api.create_fusion(list_of_models)
          
          puts "And I wait until the fusion is ready"
          assert_equal(BigML::HTTP_CREATED, fusion["code"])
          assert_equal(1, fusion["object"]["status"]["code"])
          assert_equal(@api.ok(fusion), true)
          
          puts "And I create a local fusion"
          local_fusion = BigML::Fusion.new(fusion)
          
          puts "When I create a prediction for <%s>" % JSON.generate(data_input)
          prediction = @api.create_prediction(fusion, data_input)
          
          puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
          assert_equal(prediction['object']['prediction'][objective], prediction_result)
          
          puts "And I create a local prediction for <%s>" % JSON.generate(data_input)
          local_prediction = local_fusion.predict(data_input, {"full" => true})

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
     
     # Scenario:  Successfully comparing predictions in operating points for fusion:
     def test_scenario11
        data = [[File.dirname(__FILE__)+'/data/iris_unbalanced.csv', 
                 {"tags" => ["my_fusion_tag_11"]}, 
                 'my_fusion_tag_11', 
                 {"petal width" => 4},
                 '000004',
                 'Iris-virginica',
                 {"kind" => "probability", "threshold" => 0.1, "positive_class" => "Iris-setosa"}],
                [File.dirname(__FILE__)+'/data/iris_unbalanced.csv', 
                 {"tags" => ["my_fusion_tag_11_b"]}, 
                 'my_fusion_tag_11_b', 
                 {"petal width" => 4},
                 '000004',
                 'Iris-virginica',
                 {"kind" => "probability", "threshold" => 0.9, "positive_class" => "Iris-setosa"}]
               ]
        
        puts
        puts " Successfully comparing predictions in operating points for fusion"
                
        data.each do |filename, params, tag, data_input, objective, prediction_result, operating_point|
          
          extra_params = {'seed' =>  'BigML', 'ensemble_sample' => {"rate" => 0.7, "seed"=> 'BigML'}}
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
          
          puts "And I create a fusion from a list of models"
          fusion = @api.create_fusion(list_of_models)
          
          puts "And I wait until the fusion is ready"
          assert_equal(BigML::HTTP_CREATED, fusion["code"])
          assert_equal(1, fusion["object"]["status"]["code"])
          assert_equal(@api.ok(fusion), true)
          
          puts "And I create a local fusion"
          local_fusion = BigML::Fusion.new(fusion)
          
          puts "When I create a prediction for <%s> in <%s>" % [JSON.generate(data_input), JSON.generate(operating_point)]
          prediction = @api.create_prediction(fusion, data_input, {"operating_point" => operating_point})
          
          puts "Then the prediction for <%s> is <%s>" % [objective, prediction_result]
          assert_equal(prediction['object']['prediction'][objective], prediction_result)
          
          puts "And I create a local prediction for <%s> in <%s>" % [JSON.generate(data_input), JSON.generate(operating_point)]
          local_prediction = local_fusion.predict(data_input, {"operating_point" => operating_point})

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
