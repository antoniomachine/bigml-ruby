require_relative "../lib/bigml/api"
require_relative "../lib/bigml/model"
require "test/unit"

class TestDuplicatedFields < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new(nil, nil, true)
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully changing duplicated field names
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/iris.csv', {"fields" => {"000001" => {"name" => "species"}}}, '000001', 'species1'],
            [File.dirname(__FILE__)+'/data/iris.csv', {"fields" => {"000001" => {"name" => "petal width"}}}, '000003', 'petal width3']]

    puts 
    puts "Scenario: Successfully changing duplicated field names" 

    data.each do |filename, options,  field_id, new_name|
       puts 
       puts "\nScenario: Successfully creating a prediction:\n"
       puts "Given I create a data source uploading a " + filename+ " file"
       source = @api.create_source(filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

       puts "And I wait until the source is ready"
       assert_equal(BigML::HTTP_CREATED, source["code"])
       assert_equal(1, source["object"]["status"]["code"])
       assert_equal(@api.ok(source), true)

       puts "And I create dataset with options"
       dataset=@api.create_dataset(source, options)

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

       puts "Then <%s> field's name is changed to <%s>" % [field_id, new_name]
       assert_equal(local_model.tree.fields[field_id]["name"], new_name)

    end

  end

end

