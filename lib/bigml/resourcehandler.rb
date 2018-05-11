# encoding: utf-8
#
# Copyright 2014-2016 BigML
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

require_relative 'bigmlconnection'
require_relative 'util'

module BigML

  def self.get_resource_type(resource)
    #Returns the associated resource type for a resource
    if resource.is_a?(Hash) and resource.key?('resource')
       resource = resource['resource']
    end 

    if !resource.is_a?(String)
       raise ArgumentError, "Failed to parse a resource string or structure."
    end

    BigML::RESOURCE_RE.each do |resource_type, resource_re|
      return resource_type if resource_re.match(resource)
    end

    return nil

  end

  def self.get_resource(resource_type, resource)
    # Returns a resource/id
    if resource.is_a?(Hash) and resource.key?('resource')
       resource = resource['resource']
    end
   
    if resource.is_a?(String)
       return resource if BigML::RESOURCE_RE[resource_type].match(resource)
       found_type = self.get_resource_type(resource)
       if !found_type.nil? and resource_type != self.get_resource_type(resource) 
         raise ArgumentError, "The resource %s  has not the expected type: %s " % [resource, resource_type]
       end
    end 
   
    raise ArgumentError, resource+ " is not a valid resource ID." 

  end

  def self.resource_is_ready(resource)
    #Checks a fully fledged resource structure and returns True if finished.
    if !resource.is_a?(Hash) or !resource.key?('error')
       raise ArgumentError, "No valid resource structure found"
    end
   
    unless resource["error"].nil?
       raise Exception, resource['error']['status']['message']
    end
 
    return ([BigML::HTTP_OK, BigML::HTTP_ACCEPTED].include?(resource['code']) and BigML::Util::get_status(resource)['code'] == BigML::FINISHED)

  end

  def self.check_resource_type(resource, expected_resource, message=nil)
    #Checks the resource type.
    resource_type = get_resource_type(resource)
    if expected_resource != resource_type
        raise Exception, message+"\nFound "+resource_type
    end
  end 

  def self.get_source_id(source)
    #Returns a source/id.
    return get_resource( BigML::SOURCE_PATH, source)
  end

  def self.get_dataset_id(dataset)
    #Returns a datasetid.
    return get_resource( BigML::DATASET_PATH, dataset)
  end
  
  def self.get_model_id(model)
    #Returns a model/id.
    return get_resource( BigML::MODEL_PATH, model)
  end

  def self.get_prediction_id(prediction)
    #Returns a prediction/id.
    return get_resource( BigML::PREDICTION_PATH, prediction)
  end
  
  def self.get_evaluation_id(evaluation)
    #Returns a evaluation/id.
    return get_resource( BigML::EVALUATION_PATH, evaluation)
  end

  def self.get_ensemble_id(ensemble)
    #Returns a ensemble/id.
    return get_resource( BigML::ENSEMBLE_PATH, ensemble)
  end

  def self.get_batch_prediction_id(batch_prediction)
    #Returns a batchprediction/id.
    return get_resource( BigML::BATCH_PREDICTION_PATH, batch_prediction)
  end
 
  def self.get_cluster_id(cluster)
    #Returns a cluster/id.
    return get_resource( BigML::CLUSTER_PATH, cluster)
  end

  def self.get_centroid_id(centroid)
    #Returns a centroid/id.
    return get_resource( BigML::CENTROID_PATH, centroid)
  end

  def self.get_batch_centroid_id(batch_centroid)
    #Returns a batchcentroid/id.
    return get_resource( BigML::BATCH_CENTROID_PATH, batch_centroid)
  end

  def self.get_anomaly_id(anomaly)
    #Returns a anomaly/id.
    return get_resource( BigML::ANOMALY_PATH, anomaly)
  end

  def self.get_anomaly_score_id(anomaly_score)
    #Returns a anomalyscore/id.
    return get_resource( BigML::ANOMALY_SCORE_PATH, anomaly_score)
  end

  def self.get_batch_anomaly_score_id(batch_anomaly_score)
    #Returns a batchanomalyscore/id.
    return get_resource( BigML::BATCH_ANOMALY_SCORE_PATH, batch_anomaly_score)
  end

  def self.get_project_id(project)
    #Returns a project/id.
    return get_resource( BigML::PROJECT_PATH, project)
  end

  def self.get_sample_id(sample)
    #Returns a sample/id.
    return get_resource( BigML::SAMPLE_PATH, sample)
  end

  def self.get_correlation_id(correlation)
    #Returns a correlation/id.
    return get_resource( BigML::CORRELATION_PATH, correlation)
  end

  def self.get_statistical_test_id(statistical_test)
    #Returns a statisticaltest/id.
    return get_resource( BigML::STATISTICAL_TEST_PATH, statistical_test)
  end

  def self.get_logisticregression_id(logistic_regression)
    #Returns a logisticregression/id.
    return get_resource( BigML::LOGISTIC_REGRESSION_PATH, logistic_regression)
  end

  def self.get_association_id(association)
    #Returns a association/id.
    return get_resource( BigML::ASSOCIATION_PATH, association)
  end

  def self.get_association_set_id(association_set)
    #Returns a associationset/id.
    return get_resource( BigML::ASSOCIATION_SET_PATH, association_set)
  end
  
  def self.get_configuration_id(configuration)
    #Returns an configuration/id
    return get_resource(BigML::CONFIGURATION_PATH, configuration)
  end

  def self.get_topic_model_id(topic_model)
    #Returns an topicmodel/id
    return get_resource(BigML::TOPIC_MODEL_PATH, topic_model)
  end

  def self.get_topic_distribution_id(topic_distribution)
    #Returns an topicdistribution/id
    return get_resource(BigML::TOPIC_DISTRIBUTION_PATH, topic_distribution)
  end

  def self.get_batch_topic_distribution_id(topic_distribution)
    #Returns an batchtopicdistribution/id
    return get_resource(BigML::BATCH_TOPIC_DISTRIBUTION_PATH, batch_topic_distribution)
  end

  def self.get_time_series_id(time_series)
    # Returns a timeseries/id
    return get_resource(BigML::TIME_SERIES_PATH, time_series)
  end

  def self.get_forecast_id(forecast)
    # Returns a forecast/id
    return get_resource(BigML::FORECAST_PATH, forecast)
  end

  def self.get_deepnet_id(deepnet)
    # Returns a deepnet/id
    return get_resource(BigML::DEEPNET_PATH, deepnet)
  end
    
  def self.get_script_id(script)
    #Returns a script/id.
    return get_resource( BigML::SCRIPT_PATH, script)
  end
 
  def self.get_execution_id(execution)
    #Returns a execution/id.
    return get_resource( BigML::EXECUTION_PATH, execution)
  end

  def self.get_library_id(library)
    #Returns a library/id.
    return get_resource( BigML::LIBRARY_PATH, library)
  end

  def self.get_resource_id(resource)
    #Returns the resource id if it falls in one of the registered types
    if resource.is_a?(Hash) and resource.key?('resource')
       return resource['resource']
    elsif resource.is_a?(String) 
      BigML::RESOURCE_RE.each do |resource_type, resource_re|
        return resource if resource_re.match(resource)
      end
    else
      return 
    end 
  end

  def self.exception_on_error(resource)
    #Raises exception if resource has error
    unless resource.fetch('error', nil).nil?
       raise Exception, resource['error']['status']['message']
    end
  end

  def self.check_resource(resource, get_method=nil, query_string='', wait_time=1,
                          retries=nil, raise_on_error=false, api=nil)

     # Waits until a resource is finished.
     # Given a resource and its corresponding get_method (if absent, the
     # generic get_resource is used), it calls the get_method on
     # the resource with the given query_string
     # and waits with sleeping intervals of wait_time
     # until the resource is in a final state (either FINISHED
     # for FAULTY. The number of retries can be limited using the retries
     # parameter.
    
     if resource.is_a?(String)
        resource_id = resource
     else
        resource_id = get_resource_id(resource)
     end

     resource_id = get_resource_id(resource)
     if resource_id.nil?
        raise ArgumentError, "Failed to extract a valid resource id to check."
     end

     kwargs = {'query_string' => query_string} 

     if get_method.nil? and api.respond_to?('get_resource')
        get_method = api.method("get_resource")
     elsif get_method.nil?
        raise ArgumentError, "You must supply either the get_method or the api connection info to retrieve the resource" 
     end
    
     if resource.is_a?(String)
        resource = get_method.call(resource, *kwargs.values)
        #resource = get_method.call(resource, kwargs.fetch("query_string", nil), 
        #                           kwargs.fetch("shared_username", nil), 
        #                           kwargs.fetch("shared_api_key", nil))
     end

     counter=0
     while retries.nil? or counter < retries do
       counter+=1
       status = BigML::Util::get_status(resource)
       code = status['code']
       if code == BigML::FINISHED
          if counter > 1 
             # final get call to retrieve complete resource
             resource = get_method.call(resource, kwargs.fetch("query_string", nil))
          end
          if raise_on_error 
             exception_on_error(resource)
          end 
          return resource
       elsif code == BigML::FAULTY
          raise ArgumentError, status
       end

       sleep(BigML::Util::get_exponential_wait(wait_time, counter))
       # retries for the finished status use a query string that gets the
       # minimal available resource
       unless kwargs.fetch('query_string', nil).nil?
         tiny_kwargs = {'query_string' => BigML::TINY_RESOURCE}
       else
         tiny_kwargs = {}
       end

       resource = get_method.call(resource, tiny_kwargs.fetch("query_string", nil))
     end

     if raise_on_error
        exception_on_error(resource)
     end
     return resource
  end

  def self.http_ok(resource)
    #Checking the validity of the http return code
    if resource.key?('code') 
      return [BigML::HTTP_OK, BigML::HTTP_CREATED, BigML::HTTP_ACCEPTED].include?(resource['code'])
    end
  end

  class ResourceHandler < BigMLConnection
     # This class is used by the BigML class as
     #  a mixin that provides the get method for all kind of
     #  resources and auxiliar utilities to check their status. It should not
     #  be instantiated independently.

     def get_resource(resource, query_string=nil, shared_username=nil, shared_api_key=nil)
        # Retrieves a remote resource.
        # The resource parameter should be a string containing the
        # resource id or the dict returned by the corresponding create method.
        # As each resource is an evolving object that is processed
        # until it reaches the FINISHED or FAULTY state, thet function will
        # return a dict that encloses the resource values and state info
        # available at the time it is called.

        resource_type = BigML::get_resource_type(resource)
        if resource_type.nil?
          raise Exception, "A resource id or structure is needed."
        end

        resource_id = BigML::get_resource_id(resource)

        unless resource_id.nil?
           return self._get("#{@url}#{resource_id}", 
	                    query_string, 
			    shared_username,
			    shared_api_key)
        end
     end

     def ok(resource, query_string='', wait_time=1,
           retries=nil, raise_on_error=false)
        # Waits until the resource is finished or faulty, updates it and
        # returns True on success
        if BigML::http_ok(resource)
            resource.merge!(BigML::check_resource(resource, nil, query_string,
                                           wait_time, retries, raise_on_error,
                                           self))
            return true
        else
          puts "The resource couldn't be created: "+JSON.generate(resource['error'])
        end
     end

     def _set_create_from_datasets_args(datasets, args=nil,
                                        wait_time=3, retries=10, key=nil)
        # Builds args dictionary for the create call from a `dataset` or a
        #   list of `datasets`.
        dataset_ids = []
        unless datasets.is_a?(Array)
          origin_datasets=[datasets]
        else
          origin_datasets=datasets
        end

        origin_datasets.each do |dataset|
           BigML::check_resource_type(dataset, BigML::DATASET_PATH, "A dataset id is needed to create the resource.")
           dataset_ids << BigML::get_dataset_id(dataset).gsub("shared/", "")
           dataset = BigML::check_resource(dataset, nil, BigML::TINY_RESOURCE, wait_time, retries, true, self)
        end 

        create_args = {}

        unless args.nil?
           create_args = args.clone
        end 
      
        if dataset_ids.size == 1
           key = "dataset" if key.nil?
           create_args[key] = dataset_ids[0]
        else
           key = "datasets" if key.nil?
           create_args[key] = dataset_ids
        end

        return create_args 
 
     end

     def check_origins(dataset, model, args, model_types=nil,
                      wait_time=3, retries=10)
        # Returns True if the dataset and model needed to build
        # the batch prediction or evaluation are finished. The args given
        # by the user are modified to include the related ids in the
        # create call.

        # If model_types is a list, then we check any of the model types in
        # the list.

        def self.args_update(resource_id, args, wait_time, retries, dataset_id, resource_type)
          # Updates args when the resource is ready
          unless resource_id.nil?
            BigML::check_resource(resource_id, nil, BigML::TINY_RESOURCE, 
                                  wait_time, retries, true, self)

	    args[resource_type]=resource_id
	    args["dataset"]=dataset_id
          end
        end
      
        if model_types.nil?
           model_types = []
        end

        resource_type = BigML::get_resource_type(dataset)

        if BigML::DATASET_PATH != resource_type
           raise Exception, "A dataset id is needed as second argument"
                            " to create the resource. "+resource_type+ " found."
        end
 
        dataset_id = BigML::get_dataset_id(dataset)

        unless dataset_id.nil?
            dataset = BigML::check_resource(dataset_id, nil,
                                            BigML::TINY_RESOURCE,
                                            wait_time, retries,
                                            true, self)
            resource_type = BigML::get_resource_type(model)
            if model_types.include?(resource_type)
               resource_id = BigML::get_resource_id(model)
               args_update(resource_id, args, wait_time, retries, dataset_id, resource_type)
            elsif resource_type == BigML::MODEL_PATH
               resource_id = BigML::get_model_id(model)
               args_update(resource_id, args, wait_time, retries, dataset_id, resource_type)
            else
               raise "A model or ensemble id is needed as first 
                      argument to create the resource."+resource_type+ " found"
            end
        end

        return (!dataset_id.nil? and !resource_id.nil?)

     end
     
     def export(resource, filename=None, args={})
       
       # Retrieves a remote resource when finished and stores it
       # in the user-given file
       # The resource parameter should be a string containing the
       # resource id or the dict returned by the corresponding create method.
       # As each resource is an evolving object that is processed
       # until it reaches the FINISHED or FAULTY state, the function will
       # wait until the resource is in one of these states to store the
       # associated info.
       
       resource_type = BigML::get_resource_type(resource)
       if resource_type.nil?
         raise ArgumentError, "A resource ID or structure is needed."
       end 
       
       resource_id = BigML::get_resource_id(resource)
       
       if resource_id.nil?
          raise ArgumentError, "First agument is expected to be a valid resource ID or structure."
       else
         
         resource_info = self._get("#{@url}#{resource_id}", 
                                    args.key?('query_string') ? args['query_string'] : nil,
                                    args.key?('shared_username') ? args['shared_username'] : nil,
                                    args.key?('shared_api_key') ? args['shared_api_key'] : nil,
                                    args.key?('organization') ? args['organization'] : nil)
         if !BigML::Util::is_status_final(resource_info)
            BigML::http_ok(resource_info)
         end 
         
         if filename.nil?
           file_dir = @storage || BigML::Util::DFT_STORAGE
           filename = File.join(file_dir, resource_id.gsub("/","_"))
         end
         
         if BigML::COMPOSED_RESOURCES.include?(resource_type)
           resource_info["object"]["models"].each do |component_id|
             self.export(component_id, 
                         File.join(File.dirname(filename), 
                                   resource_id.gsub("/","_")), args)
           end 
         end
         
         return BigML::Util::save(resource_info, filename)
       end

     end
     
     def export_last(tags, filename=None,
                     resource_type="model", 
                     project=nil, args={})
       # Retrieves a remote resource by tag when finished and stores it
       # in the user-given file
       # The resource parameter should be a string containing the
       # resource id or the dict returned by the corresponding create method.
       # As each resource is an evolving object that is processed
       # until it reaches the FINISHED or FAULTY state, the function will
       # wait until the resource is in one of these states to store the
       # associated info.
       # 
       if !tags.nil? && tags != ''
         query_string = BigML::LIST_LAST % tags
         if !project.nil?
           query_string += ";project=%s" % project
         end 
         
         args.merge!({'query_string' => "%s;%s" % [query_string, args.fetch('query_string', '')]})
          
         response = self._list("%s%s" % [@url, resource_type], 
                               args['query_string'], 
                               args.key?('organization') ? organization : nil)

         if response.fetch("objects", []).size > 0
           resource_info = response["objects"][0]
           if !BigML::Util::is_status_final(resource_info)
             BigML::http_ok(resource_info)
           end
           
           if filename.nil?
             file_dir = @storage || BigML::Util::DFT_STORAGE
             now = Time.now.strftime("%a%b%d%y_%H%M%S")
             filename = File.join(file_dir, 
                                 "%s_%s.json" % [tags.gsub("/", "_"), now])
           end 
           
           if BigML::COMPOSED_RESOURCES.include?(resource_type)
             resource_info["models"].each do |component_id|
               self.export(component_id, 
                           File.join(File.dirname(filename), 
                                     resource_id.gsub("/","_")))
             end 
           end 
           
           return BigML::Util::save(resource_info, filename)
           
         else
           raise ArgumentError, "No %s found with tags %s." % [resource_type,
                                                                tags]
         end
       else
         raise ArgumentError, "First agument is expected to be a non-empty tag"
       end 
       
       
     end

  end 
  
end  
