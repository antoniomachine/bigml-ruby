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
require_relative 'fields'

module BigML
  
  def self.check_model_structure(model)
    # Checks the model structure to see if it contains all the needed keys

    return (model.is_a?(Hash) and model.key?('resource') and 
            !model["resource"].nil? and (model.key?("object") and 
             (model["object"].key?("model") or model.key?('model'))))
  end

  class ModelFields 
     # A lightweight wrapper of the field information in the model, cluster
     # or anomaly objects
     def initialize(fields, objective_id=nil, data_locale=nil,
                      missing_tokens=nil)
        if fields.is_a?(Hash)
           begin
              @objective_id = objective_id
              uniquify_varnames(fields)
              @inverted_fields = BigML::invert_dictionary(fields)
              @fields = {}
              @fields = fields.clone
              @data_locale = @data_locale.nil? ? BigML::DEFAULT_LOCALE : data_locale
              @missing_tokens = missing_tokens.nil? ? BigML::DEFAULT_MISSING_TOKENS : missing_tokens
           #rescue Exception
           #    raise Exception, "Wrong field structure"
           end
        end
     end
  
     def uniquify_varnames(fields)
        #Tests if the fields names are unique. If they aren't, a
        #transformation is applied to ensure unicity.
        unique_names = fields.collect {|field_id, field| field['name']}.uniq
        if unique_names.size < fields.size
           transform_repeated_names(fields)
        end
     end

     def transform_repeated_names(fields)
        #If a field name is repeated, it will be transformed adding its
        #   column number. If that combination is also a field name, the
        #   field id will be added.
        # The objective field treated first to avoid changing it.
        unique_names =  @objective_id.nil? ? [] : [fields[@objective_id]['name']]

        fields_ids =fields.reject{|field_id| field_id == @objective_id}.collect{|field_id| field_id}.sort

        fields_ids.each do |field_id, value|
           new_name = fields[field_id]['name']
           if unique_names.include?(new_name)
              new_name = "%s%s" % [fields[field_id]['name'], fields[field_id]['column_number']] 
              if unique_names.include?(new_name)
                 new_name = "%s_%s" % [new_name, field_id]
              end
              fields[field_id]['name'] = new_name
           end
           unique_names << new_name
        end
     end

     def normalize(value)
        #Transforms to unicode and cleans missing tokens
        if value.is_a?(String) and value.encoding.to_s != "UTF-8"
           value = value.encode('utf-8') 
        end
        return (!value.nil? and  @missing_tokens.include?(value)) ?  nil : value 
     end

     def filter_input_data(input_data, by_name=true)
        #Filters the keys given in input_data checking against model fields
        if input_data.is_a?(Hash)
          #  remove all missing values
          input_data.each do |key, value|
            value = normalize(value)
            if value.nil?
               input_data.delete(key)
            end
          end

          if by_name
            # We no longer check that the input data keys match some of
            # the dataset fields. We only remove the keys that are not
            # used as predictors in the model
            new_input_data={}
            input_data.each do |key, value|
               if @inverted_fields.key?(key) and 
                  (@objective_id.nil? or @inverted_fields[key] != @objective_id) 
                    new_input_data[@inverted_fields[key]] = value
               end
            end
            input_data = new_input_data

          else
            new_input_data={}
            input_data.each do |key, value|
               if (@fields.include?(key) and (@objective_id.nil? or key !=  @objective_id) )
                  new_input_data[key] = value
               end
            end
            input_data = new_input_data
          end
          return input_data
        else
          puts "Failed to read input data in the expected  {field:value} format."
          return {}
        end

     end

  end

end
