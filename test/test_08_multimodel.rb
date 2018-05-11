require "test/unit"
require_relative "../lib/bigml/api"
require_relative "../lib/bigml/multimodel"

class TestMultimodel < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/iris.csv']]

    puts 
    puts "Scenario: Successfully creating a model from a dataset list" 

    data.each do |item|
       puts 
       puts "Given I create a data source uploading a <%s> file" % item[0]
       source = @api.create_source(item[0], {'name'=> 'source_test', 'project'=> @project["resource"]})

       puts "And I wait until the source is ready"
       assert_equal(BigML::HTTP_CREATED, source["code"])
       assert_equal(1, source["object"]["status"]["code"])
       assert_equal(@api.ok(source), true)

       dataset_list = []
       puts "And I create a dataset"
       dataset=@api.create_dataset(source)

       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)

       dataset_list << dataset

       puts "And I create a dataset"
       dataset=@api.create_dataset(source)

       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)

       dataset_list << dataset
      
       puts "Then I create a model from a dataset list"
       model=@api.create_model(dataset_list)
   
       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)

       puts "And I check the model stems from the original dataset list"

       assert_equal(true, (model['object'].key?('datasets') and 
                           model['object']['datasets'] == dataset_list.collect {|i| i["resource"]}))
          
    end
  end

  def test_scenario2
    data = [[File.dirname(__FILE__)+'/data/grades.csv', {"Tutorial" => 99.47, "Midterm" => 53.12, "TakeHome" => 87.96}, 63.33]]

    puts   
    puts "Successfully creating a model from a dataset list and predicting with it using median"

    data.each do |filename, input_data, prediction|
       puts
       source = @api.create_source(filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

       puts "And I wait until the source is ready"
       assert_equal(BigML::HTTP_CREATED, source["code"])
       assert_equal(1, source["object"]["status"]["code"])
       assert_equal(@api.ok(source), true)

       dataset_list = []
       puts "And I create a dataset"
       dataset=@api.create_dataset(source)

       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)       

       puts "Then I create a model"
       model=@api.create_model(dataset)

       puts "And I wait until the model is ready"
       assert_equal(BigML::HTTP_CREATED, model["code"])
       assert_equal(1, model["object"]["status"]["code"])
       assert_equal(@api.ok(model), true)       

       model_array = [model["resource"]]
       puts "I create a local multi model"
       local_multimodel = BigML::MultiModel.new(model_array, @api)

       puts "When I create a local multimodel batch prediction using median for %s" % JSON.generate(input_data)
       batch_predict = local_multimodel.batch_predict([input_data], nil, false,  
                                                      BigML::LAST_PREDICTION, nil, false, true)

       puts "Then the local prediction is %s" % prediction
       assert_equal(batch_predict[0].predictions[0]['prediction'], prediction)
 
    end

  end

end

