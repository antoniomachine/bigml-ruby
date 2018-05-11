require_relative "../lib/bigml/api"
require_relative "../lib/bigml/model"

require "test/unit"

class TestLocalModelOutputs < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})

   unless File.directory?(File.dirname(__FILE__)+'/tmp/')
     FileUtils.mkdir_p(File.dirname(__FILE__)+'/tmp/')
   end
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end
  # Scenario: Successfully creating a model and translate the tree model into a set of IF-THEN rules
  def test_scenario1
    data = [['data/iris.csv', 'data/model/if_then_rules_iris.txt'],
            ['data/iris_sp_chars.csv','data/model/if_then_rules_iris_sp_chars.txt'],
            ['data/spam.csv', 'data/model/if_then_rules_spam.txt'],
            ['data/grades.csv', 'data/model/if_then_rules_grades.txt'],
            ['data/diabetes.csv','data/model/if_then_rules_diabetes.txt'],
            ['data/iris_missing2.csv', 'data/model/if_then_rules_iris_missing2.txt'],
            ['data/tiny_kdd.csv', 'data/model/if_then_rules_tiny_kdd.txt']
           ]
    puts 
    puts "Scenario: Successfully creating a model and translate the tree model into a set of IF-THEN rules"

    data.each do |filename, expected_file|
      puts
      puts "Given I create a data source uploading a " + filename+ " file"
      source = @api.create_source(File.dirname(__FILE__)+"/"+filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

      puts "And I wait until the source is ready"
      assert_equal(BigML::HTTP_CREATED, source["code"])
      assert_equal(1, source["object"]["status"]["code"])
      assert_equal(@api.ok(source), true)

      puts "And I create dataset"
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

      puts "And I create a local model"
      local_model = BigML::Model.new(model, @api)

      puts "I translate the tree into IF_THEN rules"
      tmp_file_name = File.dirname(__FILE__)+'/tmp/%s' % File.basename(expected_file)
      local_model.rules(File.open(tmp_file_name, 'w'))

      puts "Then I check the output is like %s expected file" % expected_file
      #assert_equal(true, FileUtils.compare_file(tmp_file_name, File.dirname(__FILE__)+"/"+expected_file))
      
      f1 = IO.readlines(tmp_file_name).map(&:strip)
      f2 = IO.readlines(File.dirname(__FILE__)+"/"+expected_file).map(&:strip)
      assert_equal(f1, f2)

    end

  end

  # Scenario: Successfully creating a model with missing values and translate the tree model into a set of IF-THEN rules
  def test_scenario2
    data = [[File.dirname(__FILE__)+'/data/iris_missing2.csv', File.dirname(__FILE__)+'/data/model/if_then_rules_iris_missing2_MISSINGS.txt']]
    puts
    puts "Scenario: Successfully creating a model with missing values and translate the tree model into a set of IF-THEN rules"

    data.each do |filename, expected_file|
      puts
      puts "Given I create a data source uploading a " + filename+ " file"
      source = @api.create_source(filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

      puts "And I wait until the source is ready"
      assert_equal(BigML::HTTP_CREATED, source["code"])
      assert_equal(1, source["object"]["status"]["code"])
      assert_equal(@api.ok(source), true)

      puts "And I create dataset"
      dataset=@api.create_dataset(source)

      puts "And I wait until the dataset is ready"
      assert_equal(BigML::HTTP_CREATED, dataset["code"])
      assert_equal(1, dataset["object"]["status"]["code"])
      assert_equal(@api.ok(dataset), true)

      puts "And I create model with missing splits"
      model=@api.create_model(dataset, {"missing_splits" => true})

      puts "And I wait until the model is ready"
      assert_equal(BigML::HTTP_CREATED, model["code"])
      assert_equal(1, model["object"]["status"]["code"])
      assert_equal(@api.ok(model), true)

      puts "And I create a local model"
      local_model = BigML::Model.new(model, @api)

      puts "I translate the tree into IF_THEN rules"
      tmp_file_name = File.dirname(__FILE__)+'/tmp/%s' % File.basename(expected_file)
      local_model.rules(File.open(tmp_file_name, 'w'))

      puts "Then I check the output is like %s expected file" % expected_file
      assert_equal(true, FileUtils.compare_file(tmp_file_name, expected_file))

    end

  end

  # Scenario: Successfully creating a model and translate the tree model into a set of IF-THEN rules
  def test_scenario3
    data = [['data/spam.csv', {"fields" => {"000001" => {"optype" => "text", "term_analysis"=> {"case_sensitive"=> true, "stem_words"=> true, "use_stopwords"=> false, "language"=> "en"}}}},'data/model/if_then_rules_spam_textanalysis_1.txt'],
            ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> true, "stem_words"=> true, "use_stopwords"=> false}}}}, 'data/model/if_then_rules_spam_textanalysis_2.txt'],
            ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> false, "use_stopwords"=> false, "language"=> "en"}}}}, 'data/model/if_then_rules_spam_textanalysis_3.txt'],
            ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> false, "stem_words"=> true, "use_stopwords"=> true, "language"=> "en"}}}}, 'data/model/if_then_rules_spam_textanalysis_4.txt'],
            ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"token_mode"=> "full_terms_only", "language"=> "en"}}}}, 'data/model/if_then_rules_spam_textanalysis_5.txt'],
            ['data/spam.csv', {"fields"=> {"000001"=> {"optype"=> "text", "term_analysis"=> {"case_sensitive"=> true, "stem_words"=> true, "use_stopwords"=> false, "language"=> "en"}}}}, 'data/model/if_then_rules_spam_textanalysis_6.txt']]
    puts
    puts "Scenario: Successfully creating a model and translate the tree model into a set of IF-THEN rules" 

    data.each do |filename, options, expected_file|
      puts
      puts "Given I create a data source uploading a " + filename+ " file"
      source = @api.create_source(File.dirname(__FILE__)+"/"+filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

      puts "And I wait until the source is ready"
      assert_equal(BigML::HTTP_CREATED, source["code"])
      assert_equal(1, source["object"]["status"]["code"])
      assert_equal(@api.ok(source), true)

      puts "And I update the source with options <%s>" % JSON.generate(options)
      source = @api.update_source(source, options)
      assert_equal(BigML::HTTP_ACCEPTED, source["code"])
      assert_equal(@api.ok(source), true)

      puts "And I create dataset"
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
     
      puts "And I create a local model"
      local_model = BigML::Model.new(model, @api)

      puts "I translate the tree into IF_THEN rules"
      tmp_file_name = File.dirname(__FILE__)+'/tmp/%s' % File.basename(expected_file)
      local_model.rules(File.open(tmp_file_name, 'w'))

      puts "Then I check the output is like %s expected file" % expected_file
      #assert_equal(true, FileUtils.compare_file(tmp_file_name, File.dirname(__FILE__)+"/"+expected_file))
      
      f1 = IO.readlines(tmp_file_name).map(&:strip)
      f2 = IO.readlines(File.dirname(__FILE__)+"/"+expected_file).map(&:strip)
      assert_equal(f1, f2)

    end

  end

  # Scenario: Successfully creating a model and check its data distribution
  def test_scenario4
    data = [['data/iris.csv', 'data/model/data_distribution_iris.txt'],
            ['data/iris_sp_chars.csv', 'data/model/data_distribution_iris_sp_chars.txt'],
            ['data/spam.csv', 'data/model/data_distribution_spam.txt'],
            ['data/grades.csv', 'data/model/data_distribution_grades.txt'],
            ['data/diabetes.csv', 'data/model/data_distribution_diabetes.txt'],
            ['data/iris_missing2.csv', 'data/model/data_distribution_iris_missing2.txt'],
            ['data/tiny_kdd.csv', 'data/model/data_distribution_tiny_kdd.txt']]

    puts
    puts "Scenario: Successfully creating a model and check its data distribution"

    data.each do |filename, expected_file|
      puts
      puts "Given I create a data source uploading a " + filename+ " file"
      source = @api.create_source(File.dirname(__FILE__)+"/"+filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

      puts "And I wait until the source is ready"
      assert_equal(BigML::HTTP_CREATED, source["code"])
      assert_equal(1, source["object"]["status"]["code"])
      assert_equal(@api.ok(source), true)

      puts "And I create dataset"
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

      puts "And I create a local model"
      local_model = BigML::Model.new(model, @api)

      puts "And I translate the tree into IF_THEN rules"
      distribution = local_model.get_data_distribution()

      distribution_str = distribution.collect {|value| "[%s,%s]\n" % [value[0], value[1]] }.map(&:strip) 

      file_distribution = IO.readlines(File.dirname(__FILE__)+"/"+expected_file).map(&:strip)
      
      puts"Then I check the output is like %s expected file" % expected_file
      assert_equal(distribution_str, file_distribution)

    end

  end

  # Scenario: Successfully creating a model and check its predictions distribution
  def test_scenario5
    data = [['data/iris.csv', 'data/model/predictions_distribution_iris.txt'],
            ['data/iris_sp_chars.csv', 'data/model/predictions_distribution_iris_sp_chars.txt'],
            ['data/spam.csv', 'data/model/predictions_distribution_spam.txt'],
            ['data/grades.csv', 'data/model/predictions_distribution_grades.txt'],
            ['data/diabetes.csv', 'data/model/predictions_distribution_diabetes.txt'],
            ['data/iris_missing2.csv', 'data/model/predictions_distribution_iris_missing2.txt'],
            ['data/tiny_kdd.csv', 'data/model/predictions_distribution_tiny_kdd.txt']]
    puts
    puts "Scenario: Successfully creating a model and check its predictions distribution" 

    data.each do |filename, expected_file|
      puts
      puts "Given I create a data source uploading a " + filename+ " file"
      source = @api.create_source(File.dirname(__FILE__)+"/"+filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

      puts "And I wait until the source is ready"
      assert_equal(BigML::HTTP_CREATED, source["code"])
      assert_equal(1, source["object"]["status"]["code"])
      assert_equal(@api.ok(source), true)

      puts "And I create dataset"
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

      puts "And I create a local model"
      local_model = BigML::Model.new(model, @api)

      puts "And I translate the tree into IF_THEN rules"
      distribution = local_model.get_prediction_distribution()

      distribution_str = distribution.collect {|value| "[%s,%s]\n" % [value[0], value[1]] }.map(&:strip) 
      file_distribution = IO.readlines(File.dirname(__FILE__)+"/"+expected_file).map(&:strip)

      puts "Then I check the predictions distribution with <%s> file" % expected_file
      assert_equal(distribution_str, file_distribution)
    end

  end

  # Scenario: Successfully creating a model and check its summary information
  def test_scenario6
    data = [['data/iris.csv', 'data/model/summarize_iris.txt'],
            ['data/iris_sp_chars.csv', 'data/model/summarize_iris_sp_chars.txt'],
            ['data/spam.csv', 'data/model/summarize_spam.txt'],
            ['data/grades.csv', 'data/model/summarize_grades.txt'],
            ['data/diabetes.csv', 'data/model/summarize_diabetes.txt'],
            ['data/iris_missing2.csv', 'data/model/summarize_iris_missing2.txt'],
            ['data/tiny_kdd.csv', 'data/model/summarize_tiny_kdd.txt']
           ]
    puts
    puts "Scenario: Successfully creating a model and check its summary information"

    data.each do |filename, expected_file|
      puts
      puts "Given I create a data source uploading a " + filename+ " file"
      source = @api.create_source(File.dirname(__FILE__)+"/"+filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

      puts "And I wait until the source is ready"
      assert_equal(BigML::HTTP_CREATED, source["code"])
      assert_equal(1, source["object"]["status"]["code"])
      assert_equal(@api.ok(source), true)

      puts "And I create dataset"
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

      puts "And I create a local model"
      local_model = BigML::Model.new(model, @api)

      puts "I translate the tree into IF_THEN rules"
      tmp_file_name = File.dirname(__FILE__)+'/tmp/%s' % File.basename(expected_file)
      local_model.summarize(File.open(tmp_file_name, 'w'))

      puts "Then I check the model summary with %s file" % expected_file
      
      f1 = IO.readlines(tmp_file_name).map(&:strip)
      f2 = IO.readlines(File.dirname(__FILE__)+"/"+expected_file).map(&:strip)
      assert_equal(f1, f2)

    end

  end

end

