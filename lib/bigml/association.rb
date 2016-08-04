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
require_relative 'associationrule'
require_relative 'item'
require_relative 'tree'
module BigML
   RULE_HEADERS = ["Rule ID", "Antecedent", "Consequent", "Antecedent Coverage %",
                   "Antecedent Coverage", "Support %", "Support", "Confidence",
                   "Leverage", "Lift", "p-value", "Consequent Coverage %",
                   "Consequent Coverage"]

   ASSOCIATION_METRICS = ["lhs_cover", "support", "confidence",
                          "leverage", "lift", "p_value"]

   SCORES = ASSOCIATION_METRICS[0..-2]

   METRIC_LITERALS = {"confidence": "Confidence", "support": "Support",
                      "leverage": "Leverage", "lhs_cover": "Coverage",
                      "p_value": "p-value", "lift": "Lift"}

   DEFAULT_K = 100
   DEFAULT_SEARCH_STRATEGY = "leverage"

   NO_ITEMS = ['numeric', 'categorical']

   def get_metric_string(rule, reverse=false)
      #
      #Returns the string that describes the values of metrics for a rule.
      #
      metric_values = []
      ASSOCIATION_METRICS.each do |metric|
         if reverse and metric == 'lhs_cover'
             metric_key = 'rhs_cover'
         else
             metric_key = metric
         end
         metric_value = rule.fetch(metric_key)
         if metric_value.is_a?(Array)
            metric_values << "%s=%.2f%% (%s)" % [METRIC_LITERALS[metric],
                                       ((round(metric_value[0], 4) * 100)),
                                         metric_value[1]]
         elsif  metric == 'confidence'
            metric_values << "%s=%.2f%%" % [METRIC_LITERALS[metric],
                                           ((round(metric_value, 4) * 100))]
         else
            metric_values << "%s=%s" % [METRIC_LITERALS[metric], metric_value]
         end

      end

      return metric_values.join("; ")
 
   end


   class Association < ModelFields

      # A lightweight wrapper around an Association rules object.
      # Uses a BigML remote association resource to build a local version
      # that can be used to extract associations information.

      def initialize(association, api=nil)

        @resource_id = nil
        @complement = nil
        @discretization = {}
        @field_discretizations = {}
        @items = []
        @k = nil
        @max_lhs = nil
        @min_coverage = nil
        @min_leverage = nil
        @min_strength = nil
        @min_support = nil
        @min_lift = nil
        @prune = nil
        @search_strategy = DEFAULT_SEARCH_STRATEGY
        @rules = []
        @significance_level = nil

        if (association.is_a?(Array) and 
            association.include?('resource') and 
             !association['resource'].nil?)

            if api.nil?
                api = BigML::Api.new(nil, nil, false, false, false, STORAGE)
            end

            @resource_id = BigML::get_association_id(association)
            if @resource_id.nil?
                raise Exception api.error_message(association,
                                                 'association',
                                                  'get')
            end
            query_string = ONLY_MODEL
            association = retrieve_resource(api, @resource_id,
                                            query_string)
        else
            @resource_id = BigML::get_association_id(association)
        end

        if association.include?('object') and 
             association['object'].is_a?(Hash)
            association = association['object']
        end

        if association.include?('associations') and 
              association["associations"].is_a?(Hash)
           status = BigML::get_status(association)
           if status.include?('code') and status['code'] == FINISHED
              
              associations = association['associations']
              fields = associations['fields']
              super(fields)
              @complement = associations.fetch('complement', false)
              @discretization = associations.fetch('discretization', {})
              @field_discretizations = associations.fetch(
                    'field_discretizations', {})
            
              @items = []
              associations.fetch('items', []).each_with_index do |item,index|
                 @items << Item.new(index, item, fields)
              end

              @k = associations.fetch('k', 100)
              @max_lhs = associations.fetch('max_lhs', 4)
              @min_coverage = associations.fetch('min_coverage', 0)
              @min_leverage = associations.fetch('min_leverage', -1)
              @min_strength = associations.fetch('min_strength', 0)
              @min_support = associations.fetch('min_support', 0)
              @min_lift = associations.fetch('min_lift', 0)
              @prune = associations.fetch('prune', true)
              @search_strategy = associations.fetch('search_strategy',
                                     DEFAULT_SEARCH_STRATEGY)

              @rules=[]
              associations.fetch('rules', []).each do |rule|
                 @rules << BigML::AssociationRule.new(rule)
              end

              @significance_level = associations.fetch(
                            'significance_level', 0.05)

           else
             raise Exception "The association isn't finished yet"
           end
        else
           raise Exception "Cannot create the Association instance. Could not
                            find the 'associations' key in the 
                            resource:\n\n%s" % association
        end

      end

      def association_set(input_data,k=DEFAULT_K, score_by=nil, by_name=true)
         # Returns the Consequents for the rules whose LHS best match
         #   the provided items. Cosine similarity is used to score the match.

         #   @param inputs dict map of input data: e.g.
         #                      {"petal length" => 4.4,
         #                       "sepal length" => 5.1,
         #                       "petal width" => 1.3,
         #                       "sepal width" => 2.1,
         #                       "species" => "Iris-versicolor"}
         #   @param k integer Maximum number of item predictions to return
         #                    (Default 100)
         #   @param max_rules integer Maximum number of rules to return per item
         #   @param score_by Code for the metric used in scoring
         #                   (default search_strategy)
         #       leverage
         #       confidence
         #       support
         #       lhs-cover
         #       lift

         #   @param by_name boolean If true, input_data is keyed by field
         #                          name, field_id is used otherwise.

         predictions = {}
         if !score_by.nil? and !SCORES.include?(score_by)
            raise ArgumentError "The available values of 
                                 score_by are: %s" % SCORES.join(", ")
         end

         input_data = filter_input_data(input_data, by_name)
         # retrieving the items in input_data
         items_indexes= get_items(input_map=input_data).collect {|item| item.index }

         if score_by.nil?
            score_by = @search_strategy 
         end

         @rules.each do |rule|
            # checking that the field in the rhs is not in the input data
            field_type = @fields[@items[rule.rhs[0]].field_id]['optype']
            # if the rhs corresponds to a non-itemized field and this field
            # is already in input_data, don't add rhs
            if NO_ITEMS.include?(field_type) and 
               input_data.include?(@items[rule.rhs[0]].field_id)
               next
            end
            # if an itemized content is in input_data, don't add it to the
            # prediction
            if !NO_ITEMS.include?(field_type) and 
               items_indexes.include?(rule.rhs[0])
               next
            end

            cosine = items_indexes.select! {|index| rule.lhs.include?(index) }.size
            if cosine > 0
                cosine = cosine / (Math.sqrt(items_indexes.size) * 
                                   Math.sqrt(rule.lhs.size)).to_f

                rhs = tuple(rule.rhs)
                if !predictions.include?(rhs)
                    predictions[rhs] = {"score" => 0}
                end

                predictions[rhs]["score"] += cosine * rule.fetch("score_by")
            end

         end

         # choose the best k predictions
         k = k.nil? ? predictions.keys.size : k
    
         predictions = predictions.sort_by {|i,v| -v["score"] }.collect {|i, v| 
							[i,v]}[0..k-1]
         final_predictions = []
         predictions.each do |rhs,prediction|
            prediction["item"] = @items[rhs[0]].to_json()
            final_predictions << prediction
         end

         return final_predictions

      end

      def get_items(field=nil, names=nil, input_map=nil, filter_function=nil)

        # Returns the items array, previously selected by the field
        #   corresponding to the given field name or a user-defined function
        #   (if set)
        #

        def filter_function_set(item, filter_function)
            #Checking filter function if set
            if filter_function.nil?
                return true
            end
            return filter_function.call(item)
        end

        def field_filter(item, field)
            #Checking if an item is associated to a fieldInfo
            if field.nil?
                return true
            end
            return item.field_id == field_id
        end

        def names_filter(item, names)
            #Checking if an item by name
            if names.nil? 
               return true
            end
            return names.include?(item.name)
        end

        def input_map_filter(item, input_map)
            #Checking if an item is in the input map
            if input_map.nil?
                return true
            end
            value = input_map.fetch(item.field_id)
            return item.matches(value) 
        end

        items = []
        if !field.nil?
            if @fields.include?(field)
                field_id = field
            elsif @inverted_fields.include?(field)
                field_id = @inverted_fields[field]
            else
                raise Argumentrror "Failed to find a field name or ID
                                    corresponding to %s." % field
            end
        end

        @items.each do |item|
           if [field_filter(item, field), names_filter(item, names),
               input_map_filter(item, input_map), filter_function_set(item, filter_function)].all?
                items << item
           end
        end

        return items


      end

      def get_rules(min_leverage=nil, min_strength=nil,
                  min_support=nil, min_p_value=nil, item_list=nil,
                  filter_function=nil)

        # Returns the rules array, previously selected by the leverage,
        #   strength, support or a user-defined filter function (if set)

        #   @param float min_leverage   Minum leverage value
        #   @param float min_strength   Minum strength value
        #   @param float min_support   Minum support value
        #   @param float min_p_value   Minum p_value value
        #   @param List item_list   List of Item objects. Any of them should be
        #                           in the rules
        #   @param function filter_function   Function used as filter
        #
        def leverage(rule, min_leverage)
            # Check minimum leverage
            if min_leverage.nil?
                return true
            end

            return rule.leverage >= min_leverage
        end

        def strength(rule,min_strength)
            # Check minimum strength
            if min_strength.nil?
                return true
            end
            return rule.strength >= min_strength
        end

        def support(rule, min_support)
            # Check minimum support
            if min_support.nil?
                return true
            end
            return rule.support >= min_support
        end

        def p_value(rule, min_p_value)
            #Check minimum p_value
            if min_p_value.nil?
                return true
            end
            return rule.p_value >= min_p_value
        end

        def filter_function_set(rule, filter_function)
            #Checking filter function if set
            if filter_function.nil?
                return true
            end
            return filter_function.call(rule)
        end


        def item_list_set(rule, item_list)
            #Checking if any of the items list is in a rule
            if item_list.nil?
                return true
            end

            if item_list[0].is_a?(Item)
                items =  item_list.collect {|item| item.index} 
            elsif item_list[0].is_a?(String)
                items = get_items(nil, item_list).collect{|item| item.index}
            end

            rule.lhs.each do |item_index| 
               if items.include?(item_index)
                  return true
               end
            end

            rule.rhs.each do |item_index| 
               if items.include?(item_index)
                  return true
               end
            end

            return false
        end


        rules = []
        @rules.each do |rule|
           if [leverage(rule, min_leverage), strength(rule, min_strength), 
               support(rule, min_support), p_value(rule, min_p_value),
               item_list_set(rule, item_list), 
               filter_function_set(rule, filter_function)].all?

               rules << rule
           end
        end

        return rules

      end

      def rules_csv(file_name, args={})
        #
        # Stores the rules in CSV format in the user-given file. The rules
        #  can be previously selected using the arguments in get_rules
        #
        rules = get_rules(args.fetch(min_leverage, nil), 
                          args.fetch(min_strength, nil),
                          args.fetch(min_support, nil),
                          args.fetch(min_p_value, nil),
                          args.fetch(item_list, nil),
                          args.fetch(filter_function, nil))

        rules = rules.collect{|rule| describe(rule.to_csv())}

        if file_name.nil?
            raise ArgumentError "A valid file name is required to store the 
                                rules."
        end
          

        CSV.open(file_name, "wb") do |csv|
                   
           csv << RULE_HEADERS
           rules.each do |rule|
              csv << rule.collect {|item| item }
           end
        end

      end

      def describe(rule_row)
        #
        # Transforms the lhs and rhs index information to a human-readable
        #   rule text.
        # lhs items  and rhs items (second and third element in the row)
        # substitution by description
        (1..2).each do |index|
           description = []
           rule_row[index].each do |item_index|
              item = @items[item_index]
              # if there's just one field, we don't use the item description
              # to avoid repeating the field name constantly.
              item_description = (@fields.keys.size == 1 and !item.complement) ? 
                                    item.name : item.describe()
              description << item_description
           end

           description_str = description.join(" & ")
           rule_row[index] = description_str
 
        end
 
        return rule_row
      end

      def summarize(out=$STDOUT, limit=10, args={})
        #
        # Prints a summary of the obtained rules
        #

        # groups the rules by its metrics
        rules = get_rules(args.fetch(min_leverage, nil),
                          args.fetch(min_strength, nil),
                          args.fetch(min_support, nil),
                          args.fetch(min_p_value, nil),
                          args.fetch(item_list, nil),
                          args.fetch(filter_function, nil))

        out.puts "Total number of rules: %s" % rules.size
        ASSOCIATION_METRICS.each do |metric| 
          out.puts
          out.puts
          out.puts = "Top %s by %s:" % [limit, METRIC_LITERALS[metric]]
          out.puts
          out.puts
 
          top_rules = rules.sort_by {|x| -x.fetch(metric) }[0..(limit*2)-1]
          out_rules = []
          ref_rules = []
          counter = 0
          top_rules.each do |rule|
             rule_row = describe(rule.to_csv())
             metric_string = get_metric_string(rule)
             operator = "->"
             rule_id_string = "Rule %s: " % rule.rule_id

             top_rules.each do |item| 
               if rule.rhs == item.lhs and rule.lhs == item.rhs and    
                  metric_string == get_metric_string(item, true)
 
                  rule_id_string = "Rules %s, %s: " % [rule.rule_id,
                                                       item.rule_id]
                  operator = "<->"
               end
             end

             out_rule = "%s %s %s [%s]" % [rule_row[1], operator, 
                                           rule_row[2], metric_string]

             reverse_rule = "%s %s %s [%s]" % [rule_row[2], operator,
                                              rule_row[1], metric_string]

             if operator == "->" or (!ref_rules.include?(reverse_rule))
                ref_rules << out_rule
                out_rule = "%s%s%s" % [INDENT * 2, rule_id_string, out_rule]
                out_rules << out_rule 
                counter += 1
                if counter > limit
                   break
                end
             end 
          end     
          out_rules.each do |r| 
            out.puts r
          end
        end

        out.puts

      end

   end 

end

