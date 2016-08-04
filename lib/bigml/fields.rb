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

require_relative 'constants'
require_relative 'resourcehandler'

module BigML

  DEFAULT_LOCALE = 'UTF-8'

  ITEM_SINGULAR = {"categories" => "category"}

  RESOURCES_WITH_FIELDS = [SOURCE_PATH, DATASET_PATH, MODEL_PATH,
                           PREDICTION_PATH, CLUSTER_PATH, ANOMALY_PATH,
                           SAMPLE_PATH, CORRELATION_PATH, STATISTICAL_TEST_PATH,
                           LOGISTIC_REGRESSION_PATH, ASSOCIATION_PATH]

  DEFAULT_MISSING_TOKENS = ["", "N/A", "n/a", "NULL", "null", "-", "#DIV/0",
                            "#REF!", "#NAME?", "NIL", "nil", "NA", "na",
                            "#VALUE!", "#NULL!", "NaN", "#N/A", "#NUM!", "?"]

  LIST_LIMIT = 10
  SUMMARY_HEADERS = ["field column", "field ID", "field name", "field label",
                     "field description","field type", "preferred",
                     "missing count", "errors", "contents summary",
                     "errors summary"]

  UPDATABLE_HEADERS = {"field name" => "name",
                       "field label" => "label",
                       "field description" => "description",
                       "field type" => "optype",
                       "preferred" => "preferred"}

  def self.get_fields_structure(resource, errors=false)
    # Returns the field structure for a resource, its locale and
    # missing_tokens
    begin 
        resource_type = BigML::get_resource_type(resource)
    rescue Exception
        raise ArgumentError, "Unknown resource structure"
    end

    field_errors = nil 
    if BigML::RESOURCES_WITH_FIELDS.include?(resource_type)
      resource = resource.fetch('object', resource)
      # locale and missing tokens
      if resource_type == SOURCE_PATH
        resource_locale = resource['source_parser']['locale']
        missing_tokens = resource['source_parser']['missing_tokens']
      else
        resource_locale = resource.fetch('locale', BigML::DEFAULT_LOCALE)
        missing_tokens = resource.fetch('missing_tokens', BigML::DEFAULT_MISSING_TOKENS)
      end

      # fields structure
      if [MODEL_PATH, ANOMALY_PATH].include?(resource_type)
         fields = resource['model']['fields']
      elsif resource_type == CLUSTER_PATH
          fields = resource['clusters']['fields']
      elsif resource_type == CORRELATION_PATH
          fields = resource['correlations']['fields']
      elsif resource_type == STATISTICAL_TEST_PATH
          fields = resource['statistical_tests']['fields']
      elsif resource_type == LOGISTIC_REGRESSION_PATH
          fields = resource['logistic_regression']['fields']
      elsif resource_type == ASSOCIATION_PATH
          fields = resource['associations']['fields']
      elsif resource_type == SAMPLE_PATH
          fields = {}
          resource['sample']['fields'].each do |field| 
             fields[field['id']] = field
          end
      else
          fields = resource['fields']
      end
      # Check whether there's an objective id
      objective_column = nil
      if resource_type == DATASET_PATH
          objective_column = resource.fetch("objective_field", {}).fetch('id', nil)
            unless errors.nil?
               field_errors = resource.fetch("status", {}).fetch("field_errors", nil)
            end
      elsif [MODEL_PATH, LOGISTIC_REGRESSION_PATH].include?(resource_type)
            objective_id = resource.fetch('objective_fields', [nil])[0]
            objective_column = fields.fetch(objective_id, {}).fetch('column_number', nil)
      end

      result = [fields, resource_locale, missing_tokens, objective_column]
     
      if errors
         result << field_errors
      end

      return result

    else
      return errors.nil? ? [nil, nil, nil, nil] : [nil, nil, nil, nil, nil]
    end

  end

  def self.attribute_summary(attribute_value, item_type, limit=nil)
    # Summarizes the information in fields attributes where content is
    #   written as an array of arrays like tag_cloud, items, etc.

    if attribute_value.nil?
      return nil 
    end
    items = []
    attribute_value.each do |item, instances|
       items << "%s (%s)" % [item, instances] 
    end

    items_length = items.size

    if limit.nil? or limit > items_length
        limit = items_length
    end

    return "%s %s: %s" % [items_length, type_singular(item_type,
                                                      items_length == 1),
                           items[0..limit].join(", ")]

  end

  def self.type_singular(item_type, singular=False)
    # Singularizes item types if needed

    if singular
        return BigML::ITEM_SINGULAR.fetch(item_type, item_type[0..-2])
    end

    return item_type
  end

  def self.invert_dictionary(dictionary, field='name')
    # Inverts a dictionary.
    # Useful to make predictions using fields' names instead of Ids.
    # It does not check whether new keys are duplicated though.
   
    result = {}
    dictionary.each do |key, value|
      result[value[field]]=key 
    end
  
    return result

  end

  RUBY_TYPE_MAP = {
    "categorical" => [String],
    "numeric" => [Integer, Float],
    "text" => [String],
    "items" => [String]
  }

  def self.ruby_map_type(value)
    # Maps a BigML type to equivalent Python types.

    if RUBY_TYPE_MAP.include?(value)
        return RUBY_TYPE_MAP[value]
    else
        return [String]
    end

  end

  def self.find_locale(data_locale="UTF-8", verbose=false)
     begin
       encoding = Encoding.find(data_locale)
       if encoding.nil? and !encoding.index(".").nil?
          encoding = Encoding.find(data_locale.split(".")[-1])
          if encoding.nil?
             encoding = Encoding.find("UTF-8")
          end
          Encoding.default_external = encoding
       end
     rescue Exception
       puts "Error find Locale"
     end
 
  end

  class Fields 
     # A class to deal with BigML auto-generated ids.
     attr_accessor :objective_field
     def initialize(resource_or_fields, missing_tokens=nil,
                    data_locale=nil, verbose=false,
                    objective_field=nil, objective_field_present=false,
                    _include=nil, errors=nil)

       # The constructor can be instantiated with resources or a fields
       # structure. The structure is checked and fields structure is returned
       # if a resource type is matched.
       begin
         resource_info = BigML::get_fields_structure(resource_or_fields, true)
         
         @fields = resource_info[0]
         resource_locale = resource_info[1]
         resource_missing_tokens = resource_info[2]
         objective_column = resource_info[3]
         resource_errors = resource_info[4] 

         if data_locale.nil?
            data_locale = resource_locale
         end

         if missing_tokens.nil?
           if resource_missing_tokens
              missing_tokens = resource_missing_tokens
           end
         end

         if errors.nil?
            errors = resource_errors
         end

       rescue Exception
          # If the resource structure is not in the expected set, fields 
          # structure is assumed
          @fields = resource_or_fields
          if data_locale.nil?
             data_locale = BigML::DEFAULT_LOCALE
          end

          if missing_tokens.nil?
             missing_tokens = BigML::DEFAULT_MISSING_TOKENS
          end

          objective_column = nil
       end

       if @fields.nil? 
          raise ArgumentError ,"No fields structure was found."
       end

       @fields_by_name = BigML::invert_dictionary(@fields, 'name')
       @fields_by_column_number = BigML::invert_dictionary(@fields, 'column_number')
       BigML::find_locale(data_locale, verbose)
       @missing_tokens = missing_tokens
       @fields_columns = @fields_by_column_number.keys.sort
       # Ids of the fields to be included
       @filtered_fields = _include.nil? ? @fields.keys : _include

       # To be updated in update_objective_field
       @row_ids = nil 
       @headers = nil
       @objective_field = nil 
       @objective_field_present = nil
       @filtered_indexes = nil 
       @field_errors = errors

       # if the objective field is not set by the user
       # use the one extracted from the resource info
       if objective_field.nil? and !objective_column.nil?
           objective_field = objective_column
           objective_field_present = true
       end

       update_objective_field(objective_field, objective_field_present)

     end

     def update_objective_field(objective_field, objective_field_present,
                               headers=nil)
        # Updates objective_field and headers info

        # Permits to update the objective_field, objective_field_present and
        # headers info from the constructor and also in a per row basis.
         
        # If no objective field, select the last column, else store its column

        if objective_field.nil?
            @objective_field = @fields_columns[-1]
        elsif objective_field.is_a?(String)
            begin
              @objective_field = field_column_number(objective_field)
            rescue Exception
              # if the name of the objective field is not found, use the last
              # field as objective
              @objective_field = @fields_columns[-1]
            end
	else
	   @objective_field = objective_field
        end
 
        # If present, remove the objective field from the included fields
        objective_id = field_id(@objective_field)
        if @filtered_fields.include?(objective_id)
           @filtered_fields.delete(objective_id)
        end
 
        @objective_field_present = objective_field_present
        if headers.nil?
           # The row is supposed to contain the fields sorted by column number
           #fields.   
           @row_ids = [] 
           @fields.sort_by {|k,x| x['column_number'] }.each do |k,v| 
               if objective_field_present or v['column_number'] != @objective_field
                  @row_ids << k
               end
           end
           @headers = @row_ids
        else
            # The row is supposed to contain the fields as sorted in headers
            @row_ids = headers.collect { |header| field_id(header) }
            @headers = headers
        end
        # Mapping each included field to its correspondent index in the row.
        # The result is stored in filtered_indexes.
        @filtered_indexes = []
        @filtered_fields.each do |field|
           begin
              @filtered_indexes << @row_ids.index(field)
           rescue Exception
              continue
           end
        end

      end

      def field_id(key)
        #Returns a field id.
        if key.is_a?(String)
          begin
             id = @fields_by_name[key]
          rescue Exception
             raise ArgumentError, "Error: field name '%s' does not exist" % [key]
          end
          return id

        elsif key.is_a?(Integer)
          begin
             id = @fields_by_column_number[key]
          rescue Exception
             raise ArgumentError, "Error: field column number '%s' does not exist" % [key]
          end
          return id 
        end
      end

      def field_name(key)
        #"Returns a field name.

        if key.is_a?(key, String)
          begin
            name = @fields[key]['name'] 
          rescue Exception
             raise ArgumentError, "Error: field id '%s' does not exist" % [key]
          end
          return name
        elsif key.is_a?(key, Integer)
          begin
             name = @fields[@fields_by_column_number[key]]['name']
          rescue Exception
             raise ArgumentError, "Error: field column number '%s' does not exist" % [key]
          end
          return name
        end
        
      end

      def field_column_number(key)
        # Returns a field column number.
        begin 
          return @fields[key]['column_number']
        rescue Exception
          return @fields[@fields_by_name[key]]['column_number']
        end
      end

      def len()
        #Returns the number of fields.
        return @fields.size
      end


      def pair(row, headers=nil, objective_field=nil, objective_field_present=nil)
        # Pairs a list of values with their respective field ids.

        # objective_field is the column_number of the objective field.

        #`objective_field_present` must be True is the objective_field column
        #   is present in the row.

        # Try to get objective field form Fields or use the last column
        if objective_field.nil?
           objective_field = @objective_field.nil? ? @fields_columns[-1] : @objective_field
        end 
 
        # If objective fields is a name or an id, retrive column number
        if objective_field.is_a?(String)
           objective_field = field_column_number(objective_field)
        end

        # Try to guess if objective field is in the data by using headers or
        # comparing the row length to the number of fields
        if objective_field_present.nil?
           if headers
              objective_field_present = headers.include?(@field_name[objective_field])
           else
              objective_field_present = (row.size() == len())
           end
        end

        # If objective field, its presence or headers have changed, update
        if (objective_field != @objective_field or
                objective_field_present != @objective_field_present or
                (!headers.nil? and headers != @headers))

            update_objective_field(objective_field,
                                   objective_field_present, headers)
        end

        row = row.collect {|info| normalize(info)}
        return to_input_data(row)

      end

      def list_fields(out=$STDOUT)
        # Lists a description of the fields.

        @fields.sort_by {|k| k[1]['column_number']}.each do |field|
           out.puts "[%s%s: %s%s: %s%s]" % [field["name"], ' '*32, field['optype'], ' '*16, field['column_number'], ' '*8]
        end

      end

      def preferred_fields()
        # Returns fields where attribute preferred is set to True or where
        # it isn't set at all.
        result ={} 
        @fields.each do |key, value|
           if !value.key?("preferred") or !value["preferred"].nil?
              result[key] = value
           end
        end
        return result 
      end
 
      def validate_input_data(input_data, out=$STDOUT)
        # Validates whether types for input data match types in the
        # fields definition.
        
        if input_data.is_a?(Hash)
            input_data.each do |name|
              if @fields_by_name.include?(name)
                 output = "[%s%s: %s%s: %s%s: ]" % [name, ' '*32, 
                                                    type(input_data[name]), ' '*16, 
                                                    @fields[@fields_by_name[name]]['optype'], ' '*16]
             
                 if ruby_map_type(@fields[@fields_by_name[name]['optype']]).include?(input_data[name].class)
                    output += "OK" 
                 else
                    output += "WRONG"
                 end
                 out.puts output
              else
                 out.puts "Field '%s' does not exist" % [name]
              end
            end
        else
            out.puts "Input data must be a dictionary"
        end
      end

      def normalize(value)
        #Transforms to unicode and cleans missing tokens

        if value.is_a?(String) and value.encoding.to_s != "UTF-8"
           value = value.encode('utf-8')
        end
  
        return @missing_tokens.include?(value) ?  nil : value

      end


      def to_input_data(row)
        #Builds dict with field, value info only for the included headers

        pair = {}

        @filtered_indexes.each do |index|
          pair[@headers[index]]=row[index]
        end

        return pair

      end


      def missing_counts()
        #Returns the ids for the fields that contain missing values
 
        summaries = []
        @fields.each do |field_id, field|
           summaries << [field_id, field.fetch('summary', {})]
        end       

        if summaries.size == 0
            raise ArgumentError("The structure has not enough information 
                                to extract the fields containing missing values.
                                Only datasets and models have such information. 
                                You could retry the get remote call 
                                 with 'limit=-1' as query string.")
        end

        result = {}
        summaries.each do |field_id, summary|
          if summary.fetch("missing_count", 0) > 0
             result[field_id] = summary.fetch('missing_count', 0)
          end
        end 
       
        return result 

      end

      def stats(field_name)
        #Returns the summary information for the field
        return  @fields[field_id(field_name)].fetch('summary', {})
      end

      def summary_csv(filename=nil)
        # Summary of the contents of the fields
        summary = []
        writer = nil
        unless filename.nil?
            writer = File.open(filename, 'w')
            writer.puts SUMMARY_HEADERS.join(",")
        else
            summary << SUMMARY_HEADERS
        end

        @fields_columns.each do |field_column|

           field_id = field_id(field_column)
           field = @fields.fetch(field_id)
           field_summary = []
           field_summary << field.fetch('column_number','')
           field_summary << field_id
           field_summary << field.fetch('name')
           field_summary << field.fetch('label','')
           field_summary << field.fetch('description','')
           field_summary << field.fetch('optype','')
           field_summary_value = field.fetch('summary', {})

           if not field_summary_value
             field_summary << "" # no preferred info
             field_summary << "" # no missing info
             field_summary << "" # no error info
             field_summary << "" # no content summary
             field_summary << "" # no error summary
           else
             begin 
              field_summary << JSON.generate(field.fetch('preferred',''))
             rescue
              field_summary << field.fetch('preferred','').to_s
             end
             field_summary << field_summary_value.fetch("missing_count","")

             if (!@field_errors.nil? and !@field_errors.empty?) and @field_errors.keys.include?(field_id)
               errors = @field_errors.fetch(field_id)
               field_summary << errors.fetch("total")
             else
               field_summary << "0"
             end

             if field['optype'] == 'numeric'
                field_summary << "[%s, %s], mean: %s" % [field_summary_value.fetch("minimum"), 
                                                  field_summary_value.fetch("maximum"),
                                                  field_summary_value.fetch("mean")]
             elsif field['optype'] == 'categorical'
                categories = field_summary_value.fetch("categories")
                field_summary << BigML::attribute_summary(categories, 
                                        "categorìes", LIST_LIMIT)
             elsif field['optype'] == "text"
                terms = field_summary_value.fetch("tag_cloud")
                field_summary <<  attribute_summary(terms, "terms", LIST_LIMIT)
             elsif field['optype'] == "items"
                items = field_summary_value.fetch("items")
                field_summary << attribute_summary(items, "items", LIST_LIMIT)
             else
               field_summary << ""
             end

           end

           unless writer.nil?
             writer.puts field_summary.join(",")
           else
             summary << field_summary
           end

        end

        if writer.nil?
          return summary
        else
          writer.close()
        end

      end
  end
end
