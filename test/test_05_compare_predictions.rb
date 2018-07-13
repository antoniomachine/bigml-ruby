require "test/unit"            
require_relative "../lib/bigml/api"
require_relative "../lib/bigml/model"
require_relative "../lib/bigml/cluster"
require_relative "../lib/bigml/anomaly"
require_relative "../lib/bigml/logistic"
require_relative "../lib/bigml/supervised"

class TestComparePrediction < Test::Unit::TestCase
  
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
             "prediction" => "spam"},
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
             "options" => {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive"=> false, "stem_words" => true, "use_stopwords" => true, "language" => "en"}}}},
             "data_input" => {"Message" => "mobile call"},
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
            'prediction' => 40.46667, 
            'confidence' => 54.89713},
           {'filename' => File.dirname(__FILE__)+'/data/grades.csv', 
            'data_input' => {"Midterm" => 20, "Tutorial" => 90, "TakeHome" => 100}, 
            'objective' => '000005', 
            'prediction' => 28.06,
            'confidence' => 25.65806}
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

        local_prediction = local_model.predict(item["data_input"], {'full' => true, 
                                                                    'missing_strategy' => BigML::PROPORTIONAL}) 
        
        if local_prediction.is_a?(Array)
          prediction_value = local_prediction[0]
        elsif local_prediction.is_a?(Hash)
          prediction_value = local_prediction['prediction']
        else
          prediction_value = local_prediction
        end
     
        puts "Then the local prediction is <%s>" % item["prediction"]
        if item["prediction"].is_a?(Numeric)
           assert_equal(prediction_value.round(4), item["prediction"].round(4))
        else
           assert_equal(prediction_value, item["prediction"])
        end
        puts "And the local prediction's confidence is <%s>" % item["confidence"]
        assert_equal(local_prediction["confidence"].round(3), item["confidence"].round(3))
 
    end
  end

  def test_scenario4
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

        local_prediction = local_model.predict(data_input, {'full' => true, 
                                                            'missing_strategy' => BigML::PROPORTIONAL})

        puts "Then the local prediction is <%s>" % prediction_value

        if prediction_value.is_a?(Numeric)
           assert_equal(local_prediction["prediction"].round(4), prediction_value.round(4))
        else
           assert_equal(local_prediction["prediction"], prediction_value)
        end

        puts "And the local prediction's confidence is <%s>" % confidence
        assert_equal(local_prediction["confidence"].round(3), confidence.round(3))
     end
  end

  def test_scenario5
     data = [['data/iris.csv',{"petal width" => 0.5, "petal length" => 0.5, "sepal width" => 0.5, "sepal length" => 0.5}, 'Iris-versicolor'],
             ['data/iris.csv',{"petal width" => 2, "petal length" => 6, "sepal width" => 0.5, "sepal length" => 0.5}, 'Iris-versicolor'],
             ['data/iris.csv',{"petal width" => 1.5, "petal length" => 4, "sepal width" => 0.5, "sepal length" => 0.5}, 'Iris-versicolor'],
             ['data/iris.csv',{"petal length" => 1}, 'Iris-setosa'],
             ['data/iris_sp_chars.csv', {"pétal.length" => 4, "pétal&width\u0000" => 1.5, "sépal&width" => 0.5, "sépal.length" => 0.5}, 'Iris-versicolor'],
             ['data/price.csv', {"Price" => 1200}, 'Product1']
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
        local_prediction = localLogisticRegression.predict(data_input, {"full" => true})

        puts "Then the local logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, local_prediction["prediction"])

     end
  end

  def test_scenario6
     data = [['data/spam.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive" => true, "stem_words" => true, "use_stopwords" => false, "language" => "en"}}}}, {"Message" => "Mobile call"}, 'ham'],
             ['data/spam.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"case_sensitive" => true, "stem_words" => true, "use_stopwords"=> false, "language"=> "en"}}}}, {"Message"=> "A normal message"}, 'ham'],
             ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> false, "use_stopwords"=> false, "language"=> "en"}}}}, {"Message"=> "Mobile calls"}, 'ham'],
             ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> false, "use_stopwords"=> false, "language"=> "en"}}}}, {"Message"=> "A normal message"}, 'ham'],
             ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> true, "use_stopwords"=> true, "language"=> "en"}}}}, {"Message"=> "Mobile call"}, 'ham'],
             ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> true, "use_stopwords"=> true, "language"=> "en"}}}}, {"Message"=> "A normal message"}, 'ham'],
             ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"token_mode"=> "full_terms_only", "language"=> "en"}}}}, {"Message"=> "FREE for 1st week! No1 Nokia tone 4 ur mob every week just txt NOKIA to 87077 Get txting and tell ur mates. zed POBox 36504 W45WQ norm150p/tone 16+"}, 'ham'],
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
        local_prediction = localLogisticRegression.predict(data_input, {"full" => true})

        puts "Then the local logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, local_prediction["prediction"])

     end
  end

  def test_scenario7
     data = [
            ['data/spam.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"token_mode" => "full_terms_only", "language" => "en"}}}}, {"Message" => "A normal message"}, 'ham', 0.9169, "000000"],
            ['data/spam.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis" => {"token_mode" => "all", "language" => "en"}}}}, {"Message" => "mobile"}, 'ham', 0.8057, "000000"],
            ['data/movies.csv', {"fields" => {"000007" => {"optype" => "items", "item_analysis" => {"separator" => "$"}}}}, {"gender" => "Female", "genres" => "Adventure$Action", "timestamp" => 993906291, "occupation" => "K-12 student", "zipcode" => 59583, "rating" => 3}, 'Under 18', 0.8393, '000002']
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
              assert_equal(remote_probability.to_f.round(3),probability.round(3))
              break
           end
        end

        puts "And I create a local logistic regression prediction for <%s>" % JSON.generate(data_input)
        local_prediction = localLogisticRegression.predict(data_input, {"full" => true})

        puts "Then the local logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, local_prediction["prediction"])

        puts "And the local logistic regression probability for the prediction is <%s>" % probability
        assert_equal(probability.round(4), local_prediction["probability"].round(4))

     end
  end

  def test_scenario8
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

        local_prediction = local_model.predict(data_input, {'full' => true,
                                                            'missing_strategy' => BigML::PROPORTIONAL})
        puts "Then the local prediction is <%s>" % prediction_result
        assert_equal(prediction_result, local_prediction["prediction"])

     end
  end

  def test_scenario9
     data = [
            ['data/iris.csv', {"fields" => {"000000" => {"optype" => "categorical"}}}, {"species" => "Iris-setosa"}, 5.0, 0.0394, "000000", {"field_codings" => [{"field" => "species", "coding" => "dummy", "dummy_class" => "Iris-setosa"}]}],
            ['data/iris.csv', {"fields" => {"000000" => {"optype" => "categorical"}}}, {"species" => "Iris-setosa"}, 5.0, 0.051, "000000", {"balance_fields" => false, "field_codings" => [{"field" => "species", "coding" => "contrast", "coefficients" => [[1, 2, -1, -2]]}]}],
            ['data/iris.csv', {"fields" => {"000000" => {"optype" => "categorical"}}}, {"species" => "Iris-setosa"}, 5.0, 0.051, "000000", {"balance_fields" => false, "field_codings" => [{"field" => "species", "coding" => "other", "coefficients" => [[1, 2, -1, -2]]}]}],
	          ['data/iris.csv', {"fields" => {"000000" => {"optype" => "categorical"}}}, {"species" => "Iris-setosa"}, 5.0, 0.0417, "000000", {"bias" => false}],
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
        local_prediction = localLogisticRegression.predict(data_input, {"full" => true})

        puts "Then the local logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, local_prediction["prediction"].to_f)

        puts "And the local logistic regression probability for the prediction is <%s>" % probability
        assert_equal(probability.round(4), local_prediction["probability"].round(4))
     end
  end

  def test_scenario10
     data = [['data/iris_unbalanced.csv', {}, '000004', 'Iris-setosa', 0.25284, [0.33333, 0.33333, 0.33333]],
             ['data/iris_unbalanced.csv', {"petal length" => 1, "sepal length" => 1, "petal width" => 1, "sepal width" => 1}, '000004', 'Iris-setosa', 0.7575, [1.0, 0.0, 0.0]]]

     puts
     puts "Scenario: Successfully comparing predictions with proportional missing strategy and balanced models"

     data.each do |filename, data_input, objective, prediction_result, confidence, probabilities|
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

        local_prediction = local_model.predict(data_input, {'full' => true,
                                                            'missing_strategy' => BigML::PROPORTIONAL})

        puts "Then the local prediction is <%s>" % prediction_result

        if prediction_result.is_a?(Numeric)
           assert_equal(local_prediction["prediction"].round(4), prediction_result.round(4))
        else
           assert_equal(local_prediction["prediction"], prediction_result)
        end
        puts "And the local prediction's confidence is <%s>" % confidence
        assert_equal(local_prediction["confidence"].round(2), confidence.round(2))
        
        puts "And I create local probabilities for <%s>" % JSON.generate(data_input)
        
        local_probabilities = local_model.predict_probability(data_input, {"missing_strategy" => BigML::LAST_PREDICTION, 
                                                                           "compact" => true})
        puts "Then the local probabilities are <%s>" % JSON.generate(probabilities)
        assert_equal(local_probabilities, probabilities)
     end
  end
  
  #
  # Scenario: Successfully comparing predictions for logistic regression with balance_fields:
  # 
  def test_scenario11
     data = [['data/movies.csv', {"fields"=> {"000000"=> {"name"=> "user_id", "optype"=> "numeric"},
                                                   "000001"=> {"name"=> "gender", "optype"=> "categorical"},
                                                   "000002"=> {"name"=> "age_range", "optype"=> "categorical"},
                                                   "000003"=> {"name"=> "occupation", "optype"=> "categorical"},
                                                   "000004" => {"name" => "zipcode", "optype"=> "numeric"},
                                                   "000005"=> {"name"=> "movie_id", "optype"=> "numeric"},
                                                   "000006"=> {"name"=> "title", "optype"=> "text"},
                                                   "000007"=> {"name"=> "genres", "optype"=> "items",
                                                   "item_analysis" => {"separator"=> "$"}},
                                                   "000008"=> {"name"=> "timestamp", "optype"=> "numeric"},
                                                   "000009"=> {"name"=> "rating", "optype"=> "categorical"}},
                                                   "source_parser"=> {"separator" => ";"}}, {"timestamp" => 999999999}, "4", 0.4053, "000009", {"balance_fields" => false}],
            ['data/movies.csv', {"fields" => {"000000"=> {"name"=> "user_id", "optype"=> "numeric"},
                                                   "000001"=> {"name"=> "gender", "optype"=> "categorical"},
                                                   "000002"=> {"name"=> "age_range", "optype"=> "categorical"},
                                                   "000003"=> {"name"=> "occupation", "optype"=> "categorical"},
                                                   "000004"=> {"name"=> "zipcode", "optype"=> "numeric"},
                                                   "000005"=> {"name"=> "movie_id", "optype"=> "numeric"},
                                                   "000006"=> {"name"=> "title", "optype"=> "text"},
                                                   "000007"=> {"name"=> "genres", "optype"=> "items",
                                                  "item_analysis"=> {"separator"=> "$"}},
                                                  "000008"=> {"name"=> "timestamp", "optype"=> "numeric"},
                                                  "000009"=> {"name"=> "rating", "optype"=> "categorical"}},
                                                 "source_parser"=> {"separator"=> ";"}}, {"timestamp"=> 999999999}, "4", 0.2623, "000009", {"normalize"=> true}],
            ['data/movies.csv', {"fields"=> {"000000"=> {"name"=> "user_id", "optype"=> "numeric"},
                                                   "000001"=> {"name"=> "gender", "optype"=> "categorical"},
                                                   "000002"=> {"name"=> "age_range", "optype"=> "categorical"},
                                                   "000003"=> {"name"=> "occupation", "optype"=> "categorical"},
                                                   "000004"=> {"name"=> "zipcode", "optype"=> "numeric"},
                                                   "000005"=> {"name"=> "movie_id", "optype"=> "numeric"},
                                                   "000006"=> {"name"=> "title", "optype"=> "text"},
                                                   "000007"=> {"name"=> "genres", "optype"=> "items",
                                                   "item_analysis"=> {"separator"=> "$"}},
                                                   "000008"=> {"name"=> "timestamp", "optype"=> "numeric"},
                                                   "000009"=> {"name"=> "rating", "optype"=> "categorical"}},
                                                   "source_parser"=> {"separator"=> ";"}}, {"timestamp"=> 999999999}, "4", 0.2623, "000009", {"balance_fields"=> true, "normalize"=> true}] 
            ]

     puts
     puts "Scenario: Successfully comparing predictions for logistic regression with balance_fields"

     data.each do |filename, options, data_input, prediction_result, probability, objective, parms|
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

        puts "And I create a logistic regression model with objective <%s> and flags <%s> " % [objective,parms]
        logistic_regression = @api.create_logisticregression(dataset, parms.merge({"objective_field" => objective}))
        puts "And I wait until the logistic regression model is ready"

        assert_equal(BigML::HTTP_CREATED, logistic_regression["code"])
        assert_equal(@api.ok(logistic_regression), true)

        puts "And I create a local logistic regression model"
        localLogisticRegression = BigML::Logistic.new(logistic_regression)

        puts "When I create a logistic regression prediction for <%s>" % JSON.generate(data_input)
        prediction = @api.create_prediction(logistic_regression, data_input)
        assert_equal(BigML::HTTP_CREATED, prediction["code"])

        puts "Then the logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result.to_s, prediction["object"]["output"].to_s)

        puts "And the logistic regression probability for the prediction is <%s>" % probability
        prediction["object"]["probabilities"].each do |prediction_value, remote_probability|
           if prediction_value == prediction["object"]["output"]
              assert_equal(remote_probability.to_f.round(2),probability.round(2))
              break
           end
        end

        puts "And I create a local logistic regression prediction for <%s>" % JSON.generate(data_input)
        local_prediction = localLogisticRegression.predict(data_input, {"full" => true})

        puts "Then the local logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, local_prediction["prediction"])

        puts "And the local logistic regression probability for the prediction is <%s>" % probability
        assert_equal(probability.round(4), local_prediction["probability"].round(4))

     end
  end
  
  #
  # Scenario: Successfully comparing logistic regression predictions with constant fields:
  # 
  def test_scenario12
     data = [['data/constant_field.csv', {"a" => 1, "b" => 1, "c" => 1}, 'a', {"fields" => {"000000" => {"preferred" => true}}}]]
     
     puts
     puts "Scenario: Successfully comparing logistic regression predictions with constant fields"

     data.each do |filename, data_input, prediction_result, field_id|
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
        assert_equal(prediction_result.to_s, prediction["object"]["output"].to_s)
        
        puts "And I create a local logistic regression prediction for <%s>" % JSON.generate(data_input)
        local_prediction = localLogisticRegression.predict(data_input, {"full" => true})
        
        puts "Then the local logistic regression prediction is <%s>" % prediction_result
        assert_equal(prediction_result, local_prediction["prediction"])
     end    
  end  
  
  # Scenario: Successfully creating a prediction:
  def test_scenario13
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv", 
             "data_input" => {'petal width'=> 0.5},
             "objective" => "000004",           
             "prediction" => "Iris-setosa",
             "pathfile" => File.dirname(__FILE__)+"/tmp/my_model.json",
             "namefile" => "my_test"},
             {"filename" => File.dirname(__FILE__)+"/data/iris.csv", 
             "data_input" => {'petal length'=> 6, 'petal width'=> 2},
             "objective" => "000004",           
             "prediction" => "Iris-virginica",
             "pathfile" => File.dirname(__FILE__)+"/tmp/my_model.json",
             "namefile" => "my_test"},
             {"filename" => File.dirname(__FILE__)+"/data/iris.csv", 
             "data_input" => {'petal length' => 4, 'petal width'=> 1.5},
             "objective" => "000004",           
             "prediction" => "Iris-versicolor",
             "pathfile" => File.dirname(__FILE__)+"/tmp/my_model.json",
             "namefile" => "my_test"}, 
             {"filename" => File.dirname(__FILE__)+"/data/iris_sp_chars.csv",
             "data_input" => {"pétal.length" => 4, "pétal&width\u0000" => 1.5},
             "objective" => "000004",   
             "prediction" => "Iris-versicolor",
             "pathfile" => File.dirname(__FILE__)+"/tmp/my_model.json",
             "namefile" => "my_test"}
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
        model=@api.create_model(dataset, {"tags" => ["%s" % item["namefile"]]})

        puts "And I wait until the model is ready"
        assert_equal(BigML::HTTP_CREATED, model["code"])
        assert_equal(1, model["object"]["status"]["code"])
        assert_equal(@api.ok(model), true)

        puts "And I export the model"
        @api.export(model["resource"], item["pathfile"])

        puts "And I create a local model from file %s" % item["pathfile"]  
        local_model = BigML::Model.new(item["pathfile"], @api)
        
        puts "When I create a prediction for <%s>" % JSON.generate(item["data_input"])
        prediction = @api.create_prediction(model, item["data_input"])
        assert_equal(BigML::HTTP_CREATED, prediction["code"])
       
        puts "Then the prediction for <%s> is <%s>" % [item["objective"], item["prediction"]]
        assert_equal(item["prediction"], prediction["object"]["prediction"][item["objective"]])       

        puts "And I create a local prediction for <%s>" % JSON.generate(item["data_input"])
        prediction = local_model.predict(item["data_input"])

        puts "Then the local prediction is <%s>" % item["prediction"]
        assert_equal(prediction, item["prediction"]) 

        puts "I Export the tags model"
        @api.export_last(item["namefile"], item["pathfile"])
        
        puts "And I create a local model from file %s" % item["pathfile"]  
        local_model = BigML::Model.new(item["pathfile"], @api)
        
        puts "And I create a local prediction for <%s>" % JSON.generate(item["data_input"])
        prediction = local_model.predict(item["data_input"])
        
        puts "Then the local prediction is <%s>" % item["prediction"]
        assert_equal(prediction, item["prediction"]) 
      
    end
  end
  
  # Successfully comparing predictions with supervised model
  def test_scenario14
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
    puts "Successfully comparing predictions with supervised model"     
        
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


        puts "And I create a local supervised model"
        local_model = BigML::SupervisedModel.new(model, @api)
        
        puts "When I create a prediction for <%s>" % JSON.generate(item["data_input"])
        prediction = @api.create_prediction(model, item["data_input"])
        assert_equal(BigML::HTTP_CREATED, prediction["code"])
       
        puts "Then the prediction for <%s> is <%s>" % [item["objective"], item["prediction"]]
        assert_equal(item["prediction"], prediction["object"]["prediction"][item["objective"]])       

        puts "And I create a local prediction for <%s>" % JSON.generate(item["data_input"])
        prediction = local_model.predict(item["data_input"])

        puts "Then the local prediction is <%s>" % item["prediction"]
        assert_equal(prediction, item["prediction"]) 

        puts "And I create a local prediction for <%s>" % JSON.generate(item["data_input"])
        prediction = local_model.predict(item["data_input"])
        
        puts "Then the local prediction is <%s>" % item["prediction"]
        assert_equal(prediction, item["prediction"])
      
    end
  end
     

  

end

