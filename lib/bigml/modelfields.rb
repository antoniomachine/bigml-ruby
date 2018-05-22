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
require_relative 'predicate'

module BigML
  
  ONLY_MODEL = 'only_model=true;limit=-1;'
  
  FIELDS_PARENT = {"cluster" => "clusters",
                   "logisticregression" => "logistic_regression",
                   "ensemble" => "ensemble",
                   "deepnet" => "deepnet"}

  def self.retrieve_resource(api, resource_id, query_string='', no_check_fields=false)
     # Retrieves resource info either from a local repo or
     # from the remote server 
     if !api.storage.nil? 
        begin

            stored_resource = File.join(api.storage, resource_id.gsub('/','_'))
            if File.exist?(stored_resource) 
               f = File.open(stored_resource)
               resource = f.read
               begin
                 resource = JSON.parse(resource)
                 # we check that the stored resource has enough fields information
                 # for local predictions to work. Otherwise we should retrieve it.
                 if no_check_fields or BigML::check_model_fields(resource)
                    return resource
                 end
               rescue Exception
                 puts "The file %s contains no JSON" % stored_resource
               end
            end 
        rescue IOError
        end
     end

     api_getter =  api.method "get_%s" % BigML::get_resource_type(resource_id)

     return BigML::check_resource(resource_id, api_getter, query_string)

  end
  
  def self.extract_objective(objective_field)
    # Extract the objective field id from the model structure

    if objective_field.is_a?(Array)
        return objective_field[0]
    end

    return objective_field

  end
                  
  def self.parse_terms(text, case_sensitive=true)
    #
    # Returns the list of parsed terms
    #
    if text.nil?
     return []
    end
    expression = '(\b|_)([^\b_\s]+?)(\b|_)'
    pattern = /#{expression}/

    result = text.scan(pattern).collect {|i| i.join('') }.join(' ')
    if !case_sensitive
       result.downcase!
    end

    return result.split(' ')

  end

  def self.parse_items(text, regexp)
     #
     # Returns the list of parsed items
     #
     if text.nil?
        return []
     end

     return text.split(/#{regexp}/).map{|it| it.strip()}
  end

  def self.get_unique_terms_data(terms, term_forms, tag_cloud)
     #
     # Extracts the unique terms that occur in one of the alternative forms in term_forms or in the tag cloud.
     #
     #
     #if tag_cloud.is_a?(Array)
     #   tag_cloud = Hash[*tag_cloud.flatten]
     #end
     extend_forms = {}
     term_forms.each do |term, forms|
       forms.each do |form|
          extend_forms[form] = term
       end 
     end

     terms_set={}
     terms.each do |term|
       if tag_cloud.include?(term)
         if !terms_set.key?(term)
            terms_set[term] = 0
         end 
          terms_set[term] += 1
          
       elsif extend_forms.key?(term)
         term = extend_forms[term]
         if !terms_set.key?(term)
           terms_set[term] = 0
         end
         terms_set[term] += 1
       end    
     end 
     return terms_set.to_a

  end

  def self.check_model_structure(model, inner_key="model")
    # Checks the model structure to see if it contains all main expected keys 

    return (model.is_a?(Hash) and model.key?('resource') and 
            !model["resource"].nil? and (model.key?("object") and 
             (model["object"].key?(inner_key) or model.key?(inner_key))))
  end

  def self.lacks_info(model, inner_key="model") 
    #Whether the information in `model` is not enough to use it locally
    begin
      return !(BigML::resource_is_ready(model) and check_model_structure(model, inner_key) and check_model_fields(model))
    rescue Exception
      return true
    end
  end
  
  def self.check_model_fields(model)
    # Checks the model structure to see whether it contains the required
    # fields information
   
    inner_key = FIELDS_PARENT.fetch(get_resource_type(model), 'model')
 
    if BigML::check_model_structure(model, inner_key)
       model = model.fetch('object', model)
       fields = model.fetch("fields", model.fetch(inner_key, {}).fetch('fields', nil))
       # models only need model_fields to work. The rest of resources will
       # need all fields to work
       model_fields = model.fetch(inner_key, {}).fetch('model_fields', {}).keys
       if !model_fields
         fields_meta = model.fetch('fields_meta', model.fetch(inner_key, {}).fetch('fields_meta', {}))
         begin
           return fields_meta['count'] == fields_meta['total']
         rescue
           # stored old models will not have the fields_meta info, so
           # we return True to avoid failing in this case
           return true 
         end
       else
         if fields.nil?
           return false
         end
         return model_fields.collect{|field_id| fields.keys.include?(field_id) }.all? 
       end
    end

    return false

  end

  class ModelFields 
     # A lightweight wrapper of the field information in the model, cluster
     # or anomaly objects
     def initialize(fields, objective_id=nil, data_locale=nil,
                    missing_tokens=nil, terms=false, 
                    categories=false, numerics=false)
        if fields.is_a?(Hash)
           #begin
              @objective_id = objective_id
              self.uniquify_varnames(fields)
              @inverted_fields = BigML::invert_dictionary(fields)
              @fields = {}
              @fields = fields.clone
              @data_locale = data_locale.nil? ? BigML::DEFAULT_LOCALE : data_locale
              @missing_tokens = missing_tokens.nil? ? BigML::DEFAULT_MISSING_TOKENS : missing_tokens
              if terms
                @term_forms = {}
                @tag_clouds = {}
                @term_analysis = {}
                @items = {}
                @item_analysis = {}
              end

              if categories
                @categories = {}
              end

              if terms or categories or numerics
                self.add_terms(categories, numerics)
              end

           #rescue Exception
          #   raise Exception, "Wrong field structure"
          # end
        end
     end
  
     def self.attr_accessor(*vars)
       @attributes ||= []
       @attributes.concat vars
       super(*vars)
     end

     def self.attributes
       @attributes ||[]
     end

     def attributes
       self.class.attributes
     end
       
     def add_terms(categories=false, numerics=false)
       @fields.each do |field_id, field|
         if field['optype'] == 'text'
            @term_forms.merge!({field_id => field["summary"].fetch("term_forms", nil)})
            @tag_clouds.merge!({field_id =>  field["summary"].fetch("tag_cloud", []).map{|tag,_| tag}})
            #@tag_clouds.merge!({field_id =>  field["summary"].fetch("tag_cloud", nil)})
            @term_analysis.merge!({field_id => field.fetch("term_analysis", nil)})
         elsif field['optype'] == 'items'
            @items.merge!({field_id => field["summary"]["items"].map{|item,_| item}})
            @item_analysis.merge!({field_id => field['item_analysis']})
         end

         if categories and field['optype'] == 'categorical'
            @categories.merge!({field_id => field['summary'].fetch("categories",[]).map{|category,_| category}})
         end

         if numerics and defined?(@missing_numerics) and 
            @missing_numerics and field['optype'] == 'numeric' and
            defined?(@numeric_fields)
           @numeric_fields.merge!({field_id => true})
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

     def get_unique_terms(input_data)
       # Parses the input data to find the list of unique terms in the
       # tag cloud
       unique_terms = {}
       @term_forms.each do |field_id,value|
         if input_data.key?(field_id)
            input_data_field = input_data.fetch(field_id, '')
            if input_data_field.is_a?(String)
               case_sensitive = @term_analysis[field_id].fetch('case_sensitive', true)
               token_mode = @term_analysis[field_id].fetch('token_mode', 'all')
               if token_mode != BigML::TM_FULL_TERM
                 terms = BigML::parse_terms(input_data_field, case_sensitive)
               else
                 terms = []
               end

               full_term = case_sensitive ? input_data_field : input_data_field.downcase
               # We add full_term if needed. Note that when there's
               # only one term in the input_data, full_term and term are
               # equal. Then full_term will not be added to avoid
               # duplicated counters for the term.
               if token_mode == TM_FULL_TERM or (token_mode == TM_ALL and terms[0] != full_term)
                 terms << full_term
               end   
               
               unique_terms[field_id] =  BigML::get_unique_terms_data(terms,
                                                          @term_forms[field_id], 
                                                          @tag_clouds.fetch(field_id,[]))
              
            else
               unique_terms[field_id] = [[input_data_field, 1]]
            end
            input_data.delete(field_id)
         end
       end

       # the same for items fields
       @item_analysis.each do |field_id, value|
          if input_data.key?(field_id)
             input_data_field = input_data.fetch(field_id, '')
             if input_data_field.is_a?(String)
               # parsing the items in input_data
               separator = value.fetch('separator',' ')
               regexp = value.fetch('separator_regexp', nil)
               if regexp.nil?
                 regexp = '%s' % Regexp.quote(separator)
               end
               terms = BigML::parse_items(input_data_field, regexp)
               
               unique_terms[field_id] = BigML::get_unique_terms_data(terms, {}, @items.fetch(field_id, []))
             else
                unique_terms[field_id] = [[input_data_field, 1]]
             end
             input_data.delete(field_id)
          end
       end

       if defined?(@categories) and !@categories.empty?
         
         @categories.each do |field_id, value|
           if input_data.key?(field_id)
             input_data_field = input_data.fetch(field_id, '')
             unique_terms[field_id] = [[input_data_field, 1]]
             input_data.delete(field_id)
           end
         end
       end

       return unique_terms
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
        return @missing_tokens.include?(value) ?  nil : value 
     end

     def filter_input_data(input_data, add_unused_fields=false)
        #Filters the keys given in input_data checking against model fields
        #  If `add_unused_fields` is set to True, it also
        #  provides information about the ones that are not used.

        unused_fields = []
        new_input = {}

        if input_data.is_a?(Hash)
          #  remove all missing values
          input_data.each do |key, value|
            value = normalize(value)
            if value.nil?
               input_data.delete(key)
            end
          end
          
          input_data.each do |key, value|
            if !@fields.include?(key)
              key = @inverted_fields.fetch(key, key)
            end
            
            if (@fields.include?(key) and 
                (@objective_id.nil? or key !=  @objective_id) )
              new_input[key] = value
            else
              unused_fields << key
            end  
            
          end
            
          result = add_unused_fields ? [new_input, unused_fields] : new_input
          return result

        else
          puts "Failed to read input data in the expected  {field:value} format."
          return add_unused_fields ? [{}, []] : {}
        end

     end

  end

end
