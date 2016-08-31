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

#require_relative 'util'

EXPANSION_ATTRIBUTES = {"categorical" => "categories", 
                        "text" => "tag_cloud",
                       "items" => "items"}

require_relative 'resourcehandler'
require_relative 'util'
require_relative 'model'
require_relative 'predicate'
require_relative 'modelfields'
require_relative 'cluster'

module BigML
 
   def self.get_unique_terms(terms, term_forms, tag_cloud)
      #
      # Extracts the unique terms that occur in one of the alternative forms in
      # term_forms or in the tag cloud.
      #

      extend_forms = {}
      term_forms.each do |term, forms|
        forms.each do |form|
           extend_forms[form] = term
        end
        extend_forms[term] = term
      end
 
      terms_set={}
 
      terms.each do |term|
         if tag_cloud.include?(term)
             if !terms_set.include?(term)
                terms_set[term] = 0
             end
             terms_set[term] += 1
         elsif extend_forms.include?(term)
            term = extend_forms[term]
            if !terms_set.include?(term)
               terms_set[term] = 0 
            end
            terms_set[term] += 1
         end
      end
 
      return terms_set.collect {|k,v| [k,v]}

   end

   class Logistic < ModelFields
      # A lightweight wrapper around a logistic regression model.

      # Uses a BigML remote logistic regression model to build a local version
      # that can be used to generate predictions locally.

      def initialize(logistic_regression, api=nil)
         @resource_id = nil
         @input_fields = []
         @term_forms = {}
         @tag_clouds = {}
         @term_analysis = {}
         @items = {}
         @item_analysis = {}
         @categories = {}
         @coefficients = {}
         @data_field_types = {}
         @field_codings = {}
         @numeric_fields = {}
         @bias = nil
         @missing_numerics = nil
         @c = nil
         @eps = nil
         @lr_normalize = nil
         @balance_fields = nil
         @regularization = nil
         old_coefficients = false

         if !(logistic_regression.is_a?(Hash) and 
             logistic_regression.include?('resource') and
              !logistic_regression['resource'].nil?)

            if api.nil?
               api = BigML::Api.new(nil, nil, false, false, false, BigML::STORAGE)
            end

            @resource_id = BigML::get_logisticregression_id(logistic_regression)
            if @resource_id.nil?
                raise Exception
                    api.error_message(logistic_regression,
                                      'logistic_regression',
                                      'get')
            end
            query_string = BigML::ONLY_MODEL
            logistic_regression = BigML::retrieve_resource(
                api, @resource_id, query_string)
         else
            @resource_id = BigML::get_logisticregression_id(logistic_regression)
         end

         if logistic_regression.include?('object') and 
             logistic_regression['object'].is_a?(Hash) 
           logistic_regression = logistic_regression['object']
         end
 
         begin
            @input_fields =  logistic_regression.fetch("input_fields", [])
            @dataset_field_types =  logistic_regression.fetch("dataset_field_types", {})
            if !logistic_regression['objective_fields'].nil?
               objective_field = logistic_regression['objective_fields']
            else
               objective_field = logistic_regression['objective_field']
            end

         rescue Exception
            raise ArgumentError "Failed to find the logistic regression expected
                                JSON structure. Check your arguments."
         end
 
         if logistic_regression.include?('logistic_regression') and 
               logistic_regression['logistic_regression'].is_a?(Hash)

            status = BigML::get_status(logistic_regression)
            if status.include?('code') and status['code'] == FINISHED
              logistic_regression_info = logistic_regression['logistic_regression']
              fields = logistic_regression_info.fetch('fields', {})

              if @input_fields.nil? or @input_fields.empty?
                 @input_fields = @fields.sort_by {|field_id,x|  
                                      x["column_number"] }.collect {|field_id,v| field_id}
              end

              @coefficients = {}

              logistic_regression_info.fetch('coefficients', []).each do |c|
                 @coefficients[c[0]] = c[1]
              end

              if !@coefficients.values()[0][0].is_a?(Array)
                  old_coefficients = true
              end

              @bias = logistic_regression_info.fetch('bias', 0)
              @c = logistic_regression_info.fetch('c')
              @eps = logistic_regression_info.fetch('eps')
              @lr_normalize = logistic_regression_info.fetch('normalize')
              @balance_fields = logistic_regression_info.fetch('balance_fields')
              @regularization = logistic_regression_info.fetch('regularization')

              @field_codings = logistic_regression_info.fetch('field_codings', {})
              # old models have no such attribute, so we set it to False in
              # this case
              @missing_numerics = logistic_regression_info.fetch('missing_numerics', false)
              objective_id = BigML::extract_objective(objective_field)
              fields.each do |field_id, field|
                 if field['optype'] == 'text'
                   @term_forms[field_id] = {}
                   @term_forms[field_id] = field['summary']['term_forms'].clone 
                   @tag_clouds[field_id] = []
                   @tag_clouds[field_id] = field['summary']['tag_cloud'].collect{|tag,value| tag}

                   @term_analysis[field_id] = {}
                   @term_analysis[field_id] =  field['term_analysis'].clone

                 elsif field['optype'] == 'items'
                   @items[field_id] = []
                   @items[field_id] = field['summary']['items'].collect {|item,value| item }
                   @item_analysis[field_id] = {}
                   @item_analysis[field_id] = field['item_analysis'].clone
                 elsif field['optype'] == 'categorical'
                   @categories[field_id] = field['summary']['categories'].collect {
							|category,value| category }
                 end

                 if @missing_numerics and field['optype'] == 'numeric'
                      @numeric_fields[field_id] = true
                 end
              end

              super(fields, objective_id)
               
              @field_codings = logistic_regression_info.fetch('field_codings', {})
              format_field_codings() 
              @field_codings.each do |field_id|
                 if (!fields.include?(field_id) and 
                      @inverted_fields.include?(field_id))
                   @field_codings[@inverted_fields[field_id]] = @field_codings[field_id].clone
                   @field_codings.delete(field_id)
                 end
              end

              if old_coefficients
                 map_coefficients()
              end

            else
               raise Exception "The logistic regression isn't finished yet"
            end
         else
            raise Exception "Cannot create the LogisticRegression instance.
                             Could not find the 'logistic_regression' key
                             in the resource:\n\n%s" % logistic_regression
         end

      end


      def predict(input_data, by_name=true, add_unused_fields=false)
         #
         # Returns the class prediction and the probability distribution
         # By default the input fields must be keyed by field name but you can use
         # `by_name` to input them directly keyed by id.
         
         # input_data: Input data to be predicted
         # by_name: Boolean, True if input_data is keyed by names
         # add_unused_fields: Boolean, if True adds the information about the
         #                    fields in the input_data that are not being used
         #                    in the model as predictors. 

         # Checks and cleans input_data leaving the fields used in the model
         new_data = filter_input_data(input_data, by_name, add_unused_fields)

         if add_unused_fields
           input_data, unused_fields = new_data
         else
           input_data = new_data
         end

         # In case that missing_numerics is False, checks that all numeric
         # fields are present in input data.
         if @missing_numerics == false
            @fields.each do |field_id, field|
               if !OPTIONAL_FIELDS.include?(field['optype']) and 
                  !input_data.include?(field_id)
                  raise Exception "Failed to predict. Input 
                                  data must contain values for all numeric
                                  fields to get a logistic regression prediction."
               end      
            end 

         end

         # Strips affixes for numeric values and casts to the final field type
         BigML::Util::cast(input_data, @fields)

         if !@balance_fields.nil? and @balance_fields
            input_data.each do |field, value|
              if @fields[field]['optype'] == 'numeric'
                 mean = @fields[field]['summary']['mean']
                 stddev = @fields[field]['summary']['standard_deviation']
                 input_data[field] = (input_data[field] - mean) / stddev
              end
            end

         end

         # Compute text and categorical field expansion
         unique_terms = get_unique_terms(input_data)

         probabilities = {}
         total = 0

         @coefficients.keys.each do |category|
            probability = category_probability(input_data,
                                         unique_terms, category)
            order = @categories[@objective_id].index(category)
            probabilities[category] = {"category" => category,
                                       "probability" => probability, 
                                       "order" => order} 

            total += probabilities[category]["probability"]
                             
         end
         

         probabilities.keys.each do |category| 
           probabilities[category]["probability"] /= total 
         end
         

         predictions = probabilities.sort_by {|i,x| [x["probability"],-x["order"]] }.reverse


         predictions.each do |prediction, probability|
            probability.delete('order')
         end
         prediction, probability = predictions[0]

         result = {"prediction" => prediction,
                   "probability" => probability["probability"],
                   "distribution" => predictions.collect {|category,probability| 
							  {"category" => category,  
                                                           "probability" => probability["probability"]}}}

         if add_unused_fields
            result['unused_fields'] = unused_fields
         end

         return result

      end

      def category_probability(input_data, unique_terms, category)
         #
         # Computes the probability for a concrete category
         #

         probability = 0
         norm2 = 0
         # the bias term is the last in the coefficients list
         bias = @coefficients[category][@coefficients[category].size - 1][0]
         # numeric input data
         input_data.each do |field_id, value|
            coefficients = get_coefficients(category, field_id)
            probability += coefficients[0] * input_data[field_id]
            norm2 += input_data[field_id] ** 2
         end

         unique_terms.each do |field_id, value|

            if @input_fields.include?(field_id)

               coefficients = get_coefficients(category, field_id)

               unique_terms[field_id].each do |term,occurrences|
                  begin
                     one_hot = true
                     if @tag_clouds.include?(field_id)
                        index = @tag_clouds[field_id].index(term)
                     elsif @items.include?(field_id)
                        index = @items[field_id].index(term)
                     elsif  @categories.include?(field_id) and (
                            !@field_codings.include?(field_id) or 
                            @field_codings[field_id].keys[0] == "dummy")
                        index = @categories[field_id].index(term) 
                     elsif @categories.include?(field_id)
                         one_hot = false
                         index = @categories[field_id].index(term)
                         coeff_index = 0
                         @field_codings[field_id].values[0].each do |contribution|
                            probability += coefficients[coeff_index] * 
                                            contribution[index] * occurrences
                            coeff_index += 1
                         end
                     end

                     if one_hot
                        probability += coefficients[index] * occurrences
                     end
                     norm2 += occurrences ** 2
                  rescue Exception
                     next
                  end
               end

            end

         end

         @numeric_fields.each do |field_id, value|
            if @input_fields.include?(field_id)
                coefficients = get_coefficients(category, field_id)
                if !input_data.include?(field_id)
                    probability += coefficients[1]
                    norm2 += 1
                end
            end
         end


         @tag_clouds.each do |field_id, value|
            if @input_fields.include?(field_id)
                coefficients = get_coefficients(category, field_id)
                if !unique_terms.include?(field_id) or (unique_terms[field_id].nil? or unique_terms[field_id].empty?)
                   norm2 += 1
                   probability += coefficients[value.size]
                end
            end
         end

         @items.each do |field_id, value|
            if @input_fields.include?(field_id)
               coefficients = get_coefficients(category, field_id)
               if !unique_terms.include?(field_id) or (unique_terms[field_id].nil? or unique_terms[field_id].empty?)
                   norm2 += 1
                   probability += coefficients[value.size]
               end
            end
         end

         @categories.each do |field_id, value|
            if @input_fields.include?(field_id)
                coefficients = get_coefficients(category, field_id)
                if field_id != @objective_id  and
                     !unique_terms.include?(field_id)
                   
                   norm2 += 1
                   if !@field_codings.include?(field_id) or
                        @field_codings[field_id].keys[0] = "dummy"
                       shift = @fields[field_id]['coefficients_shift']
                       probability += coefficients[value.size]
                   else
                      #  codings are given as arrays of coefficients. The
                      #  last one is for missings and the previous ones are
                      #  one per category as found in summary
                     coeff_index = 0
                     @field_codings[field_id].values[0].each do |contribution|
                        probability += coefficients[coeff_index] * contribution[-1]
                        coeff_index += 1
                     end
                   end

                end
 
            end

         end

         probability += bias
 
         if @bias != 0
           norm2 += 1
         end

         if !@lr_normalize.nil? and @lr_normalize
            begin 
                probability /= Math.sqrt(norm2)
            rescue 
                # this should never happen
                probability = Float::INFINITY
            end
         end

         begin
            probability = 1 / (1 + Math.exp(-probability))
         rescue 
            probability = probability < 0 ? 0 : 1
         end

         return probability
 
      end

      def get_unique_terms(input_data)
         # Parses the input data to find the list of unique terms in the
         #  tag cloud
         #
         unique_terms = {}
         @term_forms.each do |field_id, value|
            if input_data.key?(field_id)
                input_data_field = input_data.fetch(field_id, '')
                if input_data_field.is_a?(String)
                    case_sensitive = @term_analysis[field_id].fetch(
                        'case_sensitive', true)
                    token_mode = @term_analysis[field_id].fetch(
                        'token_mode', 'all')
                    if token_mode != BigML::TM_FULL_TERM
                        terms = BigML::parse_terms(input_data_field,
                                            case_sensitive)
                    else
                        terms = []
                    end

                    full_term = case_sensitive ? input_data_field :  
                                                 input_data_field.downcase
                    # We add full_term if needed. Note that when there's
                    # only one term in the input_data, full_term and term are
                    # equal. Then full_term will not be added to avoid
                    # duplicated counters for the term.
                    if token_mode == BigML::TM_FULL_TERM or 
                            (token_mode == BigML::TM_ALL and terms[0] != full_term)
                        terms << full_term
                    end
                    unique_terms[field_id] = BigML::get_unique_terms(
                        terms, @term_forms[field_id],
                        @tag_clouds.fetch(field_id, []))
                else
                    unique_terms[field_id] = [[input_data_field, 1]]
                end
                input_data.delete(field_id)
            end
         end 
         # the same for items fields
         @item_analysis.each do |field_id, value|
            if input_data.include?(field_id)
               input_data_field = input_data.fetch(field_id, '')
               if input_data_field.is_a?(String)
                  # parsing the items in input_data
                  separator = @item_analysis[field_id].fetch(
                        'separator', ' ')
                  regexp = @item_analysis[field_id].fetch(
                        'separator_regexp', nil)
                  if regexp.nil?
                     regexp = '%s' % Regexp.quote(separator)
                  end
                  terms = BigML::parse_items(input_data_field, regexp)
                  unique_terms[field_id] = BigML::get_unique_terms(terms, {},
                                          @items.fetch(field_id, []))
 
               else 
                  unique_terms[field_id] = [[input_data_field, 1]]
               end
               input_data.delete(field_id)
            end
         end
 
         @categories.each do |field_id, value|
           if input_data.include?(field_id)
              input_data_field = input_data.fetch(field_id, '')
              unique_terms[field_id] = [[input_data_field, 1]]
              input_data.delete(field_id)
           end
         end

         return unique_terms

      end 

      def map_coefficients()
         #
         # Maps each field to the corresponding coefficients subarray 
         #
         field_ids = @input_fields.select {|field_id| field_id != @objective_id}
         shift = 0
         field_ids.each do |field_id|
            optype = @fields[field_id]['optype']
            if EXPANSION_ATTRIBUTES.keys.include?(optype)
               # text and items fields have one coefficient per
               # text plus a missing terms coefficient plus a bias
               # coefficient
               # categorical fields too, unless they use a non-default
               # field coding.
               if optype != 'categorical' or @field_coding.include?(field_id) or 
                  @field_codings[field_id].keys[0] == "dummy"
                  length = @fields[field_id]['summary'][EXPANSION_ATTRIBUTES[optype]].size
                  # missing coefficient
                  length += 1
               else
                  length = @field_codings[field_id].values[0]
               end
            else
               # numeric fields have one coefficient and an additional one
               # if self.missing_numerics is True
               length = @missing_numerics ? 2 : 1
            end
            
            @fields[field_id]['coefficients_shift'] = shift
            @fields[field_id]['coefficients_length'] = length
            shift += length
         end

         group_coefficients()

      end

      def get_coefficients(category, field_id)
        # Returns the set of coefficients for the given category and fieldIds
        return  @coefficients[category][@input_fields.index(field_id)]
      end

      def group_coefficients()
         # Groups the coefficients of the flat array in old formats to the
         # grouped array, as used in the current notation
         # 
         coefficients = @coefficients.clone
         @flat_coefficients = coefficients
         coefficients.each do |category|
            @coefficients[category] = []
            @input_fields.each do |field_id|
              shift = @fields[field_id]['coefficients_shift']
              length = @fields[field_id]['coefficients_length']
              coefficients_group = coefficients[category][shift..(length+shift-1)]
              @coefficients[category] << coefficients_group
            end

            @coefficients[category] << [coefficients[category][coefficients[category].size- 1]]
         end

      end

      def format_field_codings()
        #
        # Changes the field codings format to the dict notation
        #
        if @field_codings.is_a?(Array)
           @field_codings_list = @field_codings[0..-1]
           @field_codings = @field_codings[0..-1]
           @field_codings = {}
           @field_codings.each_with_index do |element,index|
              field_id = element['field']
              if element["coding"] == "dummy"
                 @field_codings[field_id] = {element["coding"] => element['dummy_class']}
              else
                 @field_codings[field_id] = {element["coding"] => element['coefficients']}
              end    
           end 

        end
      end
   end

end

