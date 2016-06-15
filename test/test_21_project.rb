require_relative "../lib/bigml/api"
require "test/unit"

class TestSimpleNumber < Test::Unit::TestCase
 
  def setup
    @api = BigML::Api.new
  end

  def teardown
  end

  # Testing projects REST api calls
  def test_scenario1
    puts "\nTesting projects REST api calls\n" 
    name = "my project"
    new_name = "my new project"

    puts "Given I create a project with name "+ name
    project = @api.create_project({'name' => name})

    puts "And I wait until project is ready"
    assert_equal(@api.ok(project), true)

    puts "Then I check project name is " + project["object"]["name"]
    assert_equal(name, project["object"]["name"])

    puts "And I update the project with new name "+new_name
    project = @api.update_project(project["resource"], {"name" => new_name})
    assert_equal(BigML::HTTP_ACCEPTED, project["code"])

    puts "Then I check the project name is a new name "+new_name
    assert_equal(new_name, project["object"]["name"])    

    puts "And i delete the project"
    project = @api.delete_project(project["resource"])
    assert_equal(BigML::HTTP_NO_CONTENT, project["code"])

  end

end

