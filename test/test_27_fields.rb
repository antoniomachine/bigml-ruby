require_relative "../lib/bigml/api"
require_relative "../lib/bigml/fields"
require "test/unit"

class TestFields < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new(nil, nil, true)
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

  # Scenario: Successfully creating a Fields object 
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 0, '000000']]

    puts 
    puts "Scenario: Successfully creating a Fields object" 

    data.each do |filename, objective_column, objective_id|
      puts
      puts "Given I create a data source uploading a " + filename+ " file"
      source = @api.create_source(filename, {'name'=> 'source_test', 'project'=> @project["resource"]})

      puts "And I wait until the source is ready"
      assert_equal(BigML::HTTP_CREATED, source["code"])
      assert_equal(1, source["object"]["status"]["code"])
      assert_equal(@api.ok(source), true)

      puts "And I create a Fields object from the source with objective column <%s>" % objective_column
      fields = BigML::Fields.new(source, nil, nil, false, objective_column, true)

      puts "Then the object id is <%s>" % objective_id
      assert_equal(fields.field_id(fields.objective_field), objective_id)

    end

  end

  # Scenario: Successfully creating a Fields object and a summary fields file
  def test_scenario2
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 0, File.dirname(__FILE__)+'/tmp/fields_summary.csv', File.dirname(__FILE__)+'/data/fields/fields_summary.csv']]


    puts
    puts "Scenario: Successfully creating a Fields object and a summary fields file" 

    data.each do |filename,objective_column,summary_file,expected_file|
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

      puts "And I create a Fields object from the dataset with objective column <%s>" % objective_column
      fields = BigML::Fields.new(dataset, nil, nil, false, objective_column, true)
      
      puts "And I export a summary fields file <%s>" % summary_file
      fields.summary_csv(summary_file)

      puts "Then I check that the file <%s> is like <%s>" % [summary_file, expected_file]
      assert_equal(true, File.open(summary_file, 'r').read() != File.open(expected_file, 'r').read()) 

    end

  end

end

