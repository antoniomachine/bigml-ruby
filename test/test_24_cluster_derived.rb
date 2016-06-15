require_relative "../lib/bigml/api"
require "test/unit"

class TestClusterDerived < Test::Unit::TestCase

  def setup
   @api = BigML::Api.new
   @test_name=File.basename(__FILE__).gsub('.rb','')
   @api.delete_all_project_by_name(@test_name)
   @project = @api.create_project({'name' => @test_name})
  end

  def teardown
    @api.delete_all_project_by_name(@test_name)
  end

  # Scenario: Successfully Creating datasets and models associated to a cluster
  def test_scenario1
    data = [{"filename" => File.dirname(__FILE__)+"/data/iris.csv",
             'centroid' => '000001'}] 

    puts 
    puts "Scenario: Successfully creating datasets for first centroid of a cluster" 
  
    data.each do |item|
       puts
       puts "Given I create a data source uploading a " + item["filename"] + " file"
       source = @api.create_source(item["filename"], {'name'=> 'source_test', 'project'=> @project["resource"]})

       puts "And I wait until the source is ready"
       assert_equal(BigML::HTTP_CREATED, source["code"])
       assert_equal(1, source["object"]["status"]["code"])
       assert_equal(@api.ok(source), true)

       puts "And I create dataset with local source"
       dataset=@api.create_dataset(source)

       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)

       puts "And I create cluster"
       cluster=@api.create_cluster(dataset, {'seed'=>'BigML tests', 'k' =>  8, 'cluster_seed' => 'BigML'})

       puts "And I wait until the cluster is ready"
       assert_equal(BigML::HTTP_CREATED, cluster["code"])
       assert_equal(1, cluster["object"]["status"]["code"])
       assert_equal(@api.ok(cluster), true)

       puts "When I create a dataset associated to centroid #{item['centroid']}" 
       dataset = @api.create_dataset(cluster, {'centroid' => item["centroid"]})
 
       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(@api.ok(dataset), true)

       puts "Then the dataset is associated to the centroid #{item['centroid']} of the cluster"

       cluster = @api.get_cluster(cluster)
       assert_equal(BigML::HTTP_OK, cluster["code"]);
       assert_equal("dataset/"+cluster["object"]["cluster_datasets"][item["centroid"]], dataset["resource"])

    end

  end

  # Scenario:  creating models for first centroid of a cluster 
  def test_scenario2
    data = [{'filename' => File.dirname(__FILE__)+'/data/iris.csv',
             'centroid' => '000001',
             'options' => {"model_clusters"=> true, "k" => 8}}
           ]
    puts 
    puts "Scenario:  creating models for first centroid of a cluster"
    data.each do |item|
       puts
       puts "Given I create a data source uploading a " + item["filename"] + " file"
         
       source = @api.create_source(item["filename"], {'name'=> 'source_test', 'project'=> @project["resource"]})

       puts "And I wait until the source is ready"
       assert_equal(BigML::HTTP_CREATED, source["code"])
       assert_equal(1, source["object"]["status"]["code"])
       assert_equal(@api.ok(source), true)

       puts "And I create dataset with local source"
       dataset=@api.create_dataset(source)
  
       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(1, dataset["object"]["status"]["code"])
       assert_equal(@api.ok(dataset), true)
  
       puts "And I create cluster with options #{JSON.generate(item["options"])}"
       cluster=@api.create_cluster(dataset, item["options"]) 
  
       puts "And I wait until the cluster is ready"
       assert_equal(BigML::HTTP_CREATED, cluster["code"])
       assert_equal(1, cluster["object"]["status"]["code"])
       assert_equal(@api.ok(cluster), true)

       puts "When I create a dataset associated to centroid #{item['centroid']}"
       dataset = @api.create_dataset(cluster, {'centroid' => item["centroid"]})

       puts "And I wait until the dataset is ready"
       assert_equal(BigML::HTTP_CREATED, dataset["code"])
       assert_equal(@api.ok(dataset), true)      

       puts "Then the the model is associated to the centroid #{item["centroid"]} of the cluster"
       cluster = @api.get_cluster(cluster)
       assert_equal(BigML::HTTP_OK, cluster["code"])

       assert_equal("dataset/"+cluster["object"]["cluster_datasets"][item["centroid"]], dataset["resource"])
 
    end
  
  end

end
