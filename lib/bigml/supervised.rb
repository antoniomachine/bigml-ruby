# encoding: utf-8
# A local Predictive Supervised model class
#
# This module defines a supervised model to make predictions locally or
# embedded into your application without needing to send requests to
# BigML.io.
#
# This module cannot only save you a few credits, but also enormously
# reduce the latency for each prediction and let you use your supervised models
# offline.
# 
# Example usage (assuming that you have previously set up the BIGML_USERNAME
# and BIGML_API_KEY environment variables and that you own the
# logisticregression/id below):
#

require_relative 'ensemble'
require_relative 'logistic'
require_relative 'deepnet'

module BigML
  
  COMPONENT_CLASSES = {"model" => BigML::Model, 
                       "ensemble" => BigML::Ensemble, 
                       "logisticregression" => BigML::Logistic, 
                       "deepnet" => BigML::Deepnet}
  
  def self.extract_id(model)
    #
    # Extract the resource id from:
    #    - a resource ID string
    #    - a resource structure
    #    - the name of the file that contains a resource structure
    #
    # the string can be a path to a JSON file
    if model.is_a?(String)
      begin
        model = JSON.parse(File.open(model, 'r').read)
        resource_id = BigML::get_resource_id(model)
        if resource_is.nil?
          raise Exception, "The JSON file does not seem to contain a valid BigML resource representation."
        end  
      rescue
        # if it is not a path, it can be a model id
        resource_id = BigML::get_resource_id(model)
        if resource_id.nil?
          if !model.index("model/").nil?
            raise Exception, BigML::Api.new().error_message(model, 'model', 'get')
          else
            raise Exception, "Failed to open the expected JSON file at %s " + model
          end    
        end  
      end 
    else
      resource_id = BigML::get_resource_id(model)
      if resource_id.nil?
        raise Exception, "The first argument does not contain a valid supervised model structure."
      end  
    end
    
    return resource_id, model  
    
  end
  
  class SupervisedModel < BaseModel
    # A lightweight wrapper around any supervised model.
    # Uses any BigML remote supervised model to build a local version
    # that can be used to generate predictions locally.
    def initialize(model, api=nil)
      resource_id, model = BigML::extract_id(model)
      resource_type = BigML::get_resource_type(resource_id)
      @local_model = BigML::COMPONENT_CLASSES[resource_type].new(model, api)
      
      @local_model.attributes.each do|attribute_name|
        
        define_singleton_method(attribute_name) {
          @local_model.send(attribute_name.to_s)
        }
      end
    end  
    
    def predict(data_input, options={})
      return @local_model.predict(data_input, options)
    end
  end
  
end