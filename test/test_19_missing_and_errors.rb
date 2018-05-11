require_relative "../lib/bigml/api"
require_relative "../lib/bigml/fields"

require "test/unit"

class TestMissingsAndErrors < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully obtaining missing values counts 
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/iris_missing.csv', {"fields" => {"000000" => {"optype" => "numeric"}}},  {"000000" => 1}]]

    puts 
    puts "Scenario: Successfully obtaining missing values counts"

    data.each do |filename, params, missing_values|
       puts 
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

       puts "And I create dataset with local source"
       dataset=@api.create_dataset(source)

       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)
       puts "When I ask for the missing values counts in the fields"
       fields = BigML::Fields.new(dataset)

       puts "Then the missing values counts dict is <%s>" % missing_values
       assert_equal(missing_values, fields.missing_counts())

    end

  end

  # Scenario: Successfully obtaining parsing error counts 
  def test_scenario2
    data = [[File.dirname(__FILE__)+'/data/iris_missing.csv', {"fields" => {"000000" => {"optype" => "numeric"}}}, {"000000" => 1}]]

    puts
    puts "Scenario: Successfully obtaining parsing error counts"

    data.each do |filename, params, missing_values|
      puts
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

      puts "And I create dataset with local source"
      dataset=@api.create_dataset(source)

      puts "And I wait until the dataset is ready"
      assert_equal(BigML::HTTP_CREATED, dataset["code"])
      assert_equal(1, dataset["object"]["status"]["code"])
      assert_equal(@api.ok(dataset), true)

      puts "I ask for the error counts in the fields"
      step_results = @api.error_counts(dataset)
      puts "Then the error counts dict is <%s>" % missing_values 

      assert_equal(missing_values, step_results) 
 
    end

  end
end
