require_relative "../lib/bigml/api"
require_relative "../lib/bigml/association"
require "test/unit"

class TestAssociation < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new(nil, nil, true)
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully creating associations from a dataset: 
  def test_scenario1
    data = [[File.dirname(__FILE__)+'/data/iris.csv', 'my new association name']]

    puts 
    puts "Scenario: Successfully creating associations from a dataset:"

    data.each do |filename, association_name|
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

      puts "And I create an association from a dataset"
      association = @api.create_association(dataset,  {'name'=> 'new association'})
      puts "And I wait until the association is ready"
      assert_equal(BigML::HTTP_CREATED, association["code"])
      assert_equal(1, association["object"]["status"]["code"])
      assert_equal(@api.ok(association), true)

      puts "And I update the association name to <%s>" % association_name
      association = @api.update_association(association, {'name' => association_name})

      puts "When I wait until the association is ready"
      assert_equal(BigML::HTTP_ACCEPTED, association["code"])
      assert_equal(@api.ok(association), true)

      puts "Then the association name is <%s>" % association_name
      assert_equal(association["object"]["name"], association_name)
 
    end

  end

  # Scenario: Successfully creating local association object
  def test_scenario2
    data = [[File.dirname(__FILE__)+'/data/tiny_mushrooms.csv', ["Edible"], {'p_value'=> 5.26971e-31, 'confidence'=> 1, 'rhs_cover'=> [0.488, 122], 'leverage'=> 0.24986, 'rhs'=> [19], 'rule_id'=> '000002', 'lift' => 2.04918, 'lhs'=> [0, 21, 16, 7], 'lhs_cover'=> [0.488, 122], 'support' => [0.488, 122]}]]

    puts
    puts "Scenario: Successfully creating local association object:" 

    data.each do |filename, item_list, json_rule|
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

      puts "And I create an association from a dataset"
      association = @api.create_association(dataset,  {'name'=> 'new association'})
      puts "And I wait until the association is ready"
      assert_equal(BigML::HTTP_CREATED, association["code"])
      assert_equal(1, association["object"]["status"]["code"])
      assert_equal(@api.ok(association), true)

      puts "And I create a local association"
      local_association = BigML::Association.new(association)
  
      puts "When I get the rules for %s" % JSON.generate(item_list)

      association_rules = local_association.get_rules(nil, nil, nil, nil, item_list)

      puts "Then the first rule is <%s>" % json_rule
      assert_equal(association_rules[0].to_json(), json_rule)
      
    end

  end

  # Scenario: Successfully creating local association object:
  def test_scenario3
    data = [[File.dirname(__FILE__)+'/data/tiny_mushrooms.csv', ["Edible"], {'p_value' => 2.08358e-17, 'confidence'=> 0.79279, 'rhs_cover'=> [0.704, 176], 'leverage' => 0.07885, 'rhs' => [11], 'rule_id' => '000007', 'lift' => 1.12613, 'lhs' => [0], 'lhs_cover' =>[0.888, 222], 'support' => [0.704, 176]}, 'lhs_cover']]

    puts 
    puts "Scenario: Successfully creating local association object:"

    data.each do |filename, item_list, json_rule, seach_strategy|
      puts 
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

      puts "And I create an association from a dataset with search strategy %s" % seach_strategy
      association = @api.create_association(dataset,  {'name'=> 'new association', 
                                              'search_strategy' => seach_strategy})
      puts "And I wait until the association is ready"
      assert_equal(BigML::HTTP_CREATED, association["code"])
      assert_equal(1, association["object"]["status"]["code"])
      assert_equal(@api.ok(association), true)
 
      puts "And I create a local association"
      local_association = BigML::Association.new(association)
  
      puts "When I get the rules for %s" % JSON.generate(item_list)
      association_rules = local_association.get_rules(nil, nil, nil, nil, item_list)

      puts "Then the first rule is <%s>" % json_rule
      assert_equal(association_rules[0].to_json(), json_rule)

    end
  end
end

