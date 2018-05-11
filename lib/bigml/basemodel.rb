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
require_relative 'modelfields'
require_relative 'api'

module BigML
 
  #ONLY_MODEL = 'only_model=true;limit=-1;'
  EXCLUDE_FIELDS = 'exclude=fields;' 

  def self.print_importance(instance, out=$STDOUT)
    # Print a field importance structure
    count = 1
    data = instance.field_importance_data()
    field_importance = data[0]
    fields = data[1]

    field_importance.each do |field, importance|
       out.puts  "    %s. %s: %.2f%%" % [count, fields[field]["name"], importance.round(4)*100]
       count +=1
    end
  end

  class BaseModel < ModelFields

     # A lightweight wrapper of the basic model information

     # Uses a BigML remote model to build a local version that contains the
     # main features of a model, except its tree structure.

     attr_accessor :resource_id, :field_importance

     def initialize(model, api=nil, fields=nil)
        if BigML::check_model_structure(model)
            @resource_id = model['resource']
        else
          # If only the model id is provided, the short version of the model
          # resource is used to build a basic summary of the model
          if api.nil?
             api = BigML.Api.new
          end

          @resource_id =  BigML::get_model_id(model)
          if @resource_id.nil?
             raise Exception, api.error_message(model, 'model', 'get')
          end

          if !fields.nil? and fields.is_a?(Hash)
            query_string = BigML::EXCLUDE_FIELDS
          else
            query_string = BigML::ONLY_MODEL
          end
 
          model = BigML::retrieve_resource(api, @resource_id, query_string)
          # Stored copies of the model structure might lack some necessary
          # keys
          if !BigML::check_model_structure(model)
             model = api.get_model(@resource_id, query_string)
          end
        end

        if model.key?('object') and model['object'].is_a?(Hash)
            model = model['object']
        end

        if model.key?('model') and model['model'].is_a?(Hash)
            status = BigML::Util::get_status(model)
            if status.key?('code') and status['code'] == BigML::FINISHED
              if (fields.nil? and (model['model'].key?('model_fields') or model['model'].key?('fields')) )
                 fields = model["model"].fetch('model_fields',  model['model'].fetch('fields', []))
                 # pagination or exclusion might cause a field not to
                 # be in available fields dict
		 #
		 if !fields.keys.collect {|key| model['model']['fields'].include?(key) }.all?
                    raise Exception, "Some fields are missing to generate a local model.  Please, provide a model with the complete list of fields."
                 end 
               
                 fields.keys.each do |field|
                    field_info = model['model']['fields'][field]
                    if field_info.include?('summary')
                       fields[field]['summary'] = field_info['summary']
                    end
                    fields[field]['name'] = field_info['name']
                 end

              end

              objective_field = model['objective_fields']
   
              super(fields, BigML::extract_objective(objective_field))
              
              @description = model['description']
              @field_importance = model['model'].fetch('importance', nil)
        
              if !@field_importance.nil?
                 @field_importance=@field_importance.select {|element| fields.include?(element[0]) } 
              end

              @locale = model.fetch('locale', BigML::DEFAULT_LOCALE)

            else
              raise Exception, "The model isn't finished yet"
            end

        else
           raise Exception "Cannot create the BaseModel instance. Could not find the 'model' key in the resource:\n\n%s" % [model] 
        end

     end

     def resource()
        #Returns the model resource ID
        return @resource_id
     end

     def field_importance_data()
        #Returns field importance related info
        return [@field_importance, @fields]
     end
 
     def print_importance(out=STDOUT)
        #Prints the importance data
        BigML::print_importance(self, out)
     end

  end

end
