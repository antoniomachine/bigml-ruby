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

#"""A local Predictive Model.   

require_relative 'basemodel'
require_relative 'api' 
require_relative 'tree'
require_relative 'multivote'
require_relative 'path'

module BigML

   STORAGE = './storage'
   DEFAULT_IMPURITY = 0.2

   def self.print_distribution(distribution, out=$STDOUT)
     # Prints distribution data

     total = distribution.collect {|group| group[1] }.inject {|x,y| x + y}

     distribution.each do |group|
        out.puts "    %s: %.2f%% (%d instance%s)" % [group[0],
                                                     (group[1] * 1.0 / total).round(4)*100,
                                                     group[1],
                                                     group[1] == 1 ? "" : "s"]
     end

   end

   class Model < BaseModel
     #  A lightweight wrapper around a Tree model.

     #  Uses a BigML remote model to build a local version that can be used
     #  to generate predictions locally.
     #
     attr_accessor :tree, :fields, :objective_id

     def initialize(model, api=nil)
        # The Model constructor can be given as first argument
        #  a model structure or a model id or  a path to 
        #  a JSON file containing a model structure
        @resource_id = nil 
        @ids_map = {}
        @terms = {}
        # the string can be a path to a JSON file
        if model.is_a?(String) 
           if File.file?(model)
              begin
                File.open(model, "r") do |f|
                    model = JSON.parse(f.read)
                end
                @resource_id =  BigML::get_model_id(model)
                if @resource_id.nil?
                   raise ArgumentError, "The JSON file does not seem to contain a valid BigML model representation"
                end
              #rescue Exception
              #    raise ArgumentError, "The JSON file does not seem to contain a valid BigML model representation"
              end
           else
              # if it is not a path, it can be a model id
             @resource_id =  BigML::get_model_id(model)
             if @resource_id.nil?
               if !model.index('model/').nil?
                   raise Exception, api.error_message(model, 'model', 'get')
               else
                   raise Exception, "Failed to open the expected JSON file at %s" % [model]
               end
             end
           end 
        end

        if !(model.is_a?(Hash) and model.key?('resource') and !model['resource'].nil?) 
           if api.nil?
              api = BigML::Api.new(nil, nil, false, false, false, STORAGE, nil)
           end
           query_string = ONLY_MODEL
           model = BigML::retrieve_resource(api, @resource_id, query_string)
        else
           @resource_id =  BigML::get_model_id(model)
        end

        super(model, api)

        if model.key?('object') and model['object'].is_a?(Hash)
            model = model['object']
        end

        if model.key?("model") and model['model'].is_a?(Hash)
           status = BigML::get_status(model)
           if status.key?('code') and status['code'] == FINISHED
              distribution = model['model']['distribution']['training']
              # will store global information in the tree: regression and
              # max_bins number
              tree_info = {'max_bins' => 0}
              @tree = BigML::Tree.new(model['model']['root'],
                                @fields,
                                @objective_id,
                                distribution,
                                nil,
                                @ids_map,
                                true,
                                tree_info)

              @tree.regression = tree_info['regression']
              if @tree.regression
                @_max_bins = tree_info['max_bins']
              end
           else
             raise Exception, "The model isn't finished yet"
           end 
        else
           raise Exception, "Cannot create the Model instance. Could not find the 'model' key in the resource:\n\n %s " % [model]
        end

        if @tree.regression
           @regression_ready = true
        else
           @regression_ready = false
        end

     end

     def list_fields(out=STDOUT)
        # Prints descriptions of the fields for this model.
       @tree.list_fields(out)
     end

     def get_leaves(filter_function=nil)
        # Returns a list that includes all the leaves of the model.

        #   filter_function should be a function that returns a boolean
        #   when applied to each leaf node.
        return @tree.get_leaves(nil, filter_function)
     end

     def predict(input_data, options={})
        # Makes a prediction based on a number of field values.

        # By default the input fields must be keyed by field name but you can use
        # `by_name` to input them directly keyed by id.

        # input_data: Input data to be predicted
        # by_name: Boolean, true if input_data is keyed by names
        # print_path: Boolean, if true the rules that lead to the prediction
        #             are printed
        # out: output handler
        # with_confidence: Boolean, if true, all the information in the node
        #                 (prediction, confidence, distribution and count)
        #                 is returned in a list format
        # missing_strategy: LAST_PREDICTION|PROPORTIONAL missing strategy for
        #                  missing fields
        # add_confidence: Boolean, if true adds confidence to the dict output
        # add_path: Boolean, if true adds path to the dict output
        # add_distribution: Boolean, if true adds distribution info to the
        #                  dict output
        # add_count: Boolean, if true adds the number of instances in the
        #               node to the dict output
        # add_median: Boolean, if true adds the median of the values in
        #            the distribution
        # add_next: Boolean, if true adds the field that determines next
        #           split in the tree
        # add_min: Boolean, if true adds the minimum value in the prediction's
        #          distribution (for regressions only)
        # add_max: Boolean, if true adds the maximum value in the prediction's
        #         distribution (for regressions only)
        # add_unused_fields: Boolean, if True adds the information about the
        #           fields in the input_data that are not being used
        #           in the model as predictors.
        # multiple: For categorical fields, it will return the categories
        #         in the distribution of the predicted node as a
        #           list of dicts:
        #            [{'prediction' => 'Iris-setosa',
        #              'confidence' => 0.9154
        #              'probability' => 0.97
        #              'count' => 97},
        #             {'prediction' => 'Iris-virginica',
        #              'confidence' => 0.0103
        #              'probability' => 0.03,
        #              'count' => 3}]
        #          The value of this argument can either be an integer
        #          (maximum number of categories to be returned), or the
        #          literal 'all', that will cause the entire distribution
        #          in the node to be returned.
        return _predict(input_data,
	               options.key?("by_name") ? options["by_name"] : true,
                       options.key?("print_path") ? options["print_path"] : false,
		       options.key?("out") ? options["out"] : $STDOUT,
		       options.key?("with_confidence") ? options["with_confidence"] : false,
		       options.key?("missing_strategy") ? options["missing_strategy"] : LAST_PREDICTION,
		       options.key?("add_confidence") ? options["add_confidence"] : false,
		       options.key?("add_path") ? options["add_path"] : false,
		       options.key?("add_distribution") ? options["add_distribution"] : false,
		       options.key?("add_count") ? options["add_count"] : false,
		       options.key?("add_median") ? options["add_median"] : false,
                       options.key?("add_next") ? options["add_next"] : false,
		       options.key?("add_min") ? options["add_min"] : false,
		       options.key?("add_max") ? options["add_max"] : false,
                       options.key?("add_unused_fields") ? options["add_unused_fields"] : false,
		       options.key?("multiple") ? options["multiple"] :nil) 
     end

     def _predict(input_data, by_name=true,
                print_path=false, out=$STDOUT, with_confidence=false,
                missing_strategy=LAST_PREDICTION,
                add_confidence=false,
                add_path=false,
                add_distribution=false,
                add_count=false,
                add_median=false,
                add_next=false,
                add_min=false,
                add_max=false,
                add_unused_fields=false,
                multiple=nil)

        # Makes a prediction based on a number of field values.
 
        # By default the input fields must be keyed by field name but you can use
        # `by_name` to input them directly keyed by id.

        # input_data: Input data to be predicted
        # by_name: Boolean, true if input_data is keyed by names
        # print_path: Boolean, if true the rules that lead to the prediction
        #             are printed
        # out: output handler
        # with_confidence: Boolean, if true, all the information in the node
        #                 (prediction, confidence, distribution and count)
        #                 is returned in a list format
        # missing_strategy: LAST_PREDICTION|PROPORTIONAL missing strategy for
        #                  missing fields
        # add_confidence: Boolean, if true adds confidence to the dict output
        # add_path: Boolean, if true adds path to the dict output
        # add_distribution: Boolean, if true adds distribution info to the
        #                  dict output
        # add_count: Boolean, if true adds the number of instances in the
        #               node to the dict output
        # add_median: Boolean, if true adds the median of the values in
        #            the distribution
        # add_next: Boolean, if true adds the field that determines next
        #           split in the tree
        # add_min: Boolean, if true adds the minimum value in the prediction's
        #          distribution (for regressions only)
        # add_max: Boolean, if true adds the maximum value in the prediction's
        #         distribution (for regressions only)
        # add_unused_fields: Boolean, if True adds the information about the
        #           fields in the input_data that are not being used
        #           in the model as predictors.
        # multiple: For categorical fields, it will return the categories
        #         in the distribution of the predicted node as a
        #           list of dicts:
        #            [{'prediction' => 'Iris-setosa',
        #              'confidence' => 0.9154
        #              'probability' => 0.97
        #              'count' => 97},
        #             {'prediction' => 'Iris-virginica',
        #              'confidence' => 0.0103
        #              'probability' => 0.03,
        #              'count' => 3}]
        #          The value of this argument can either be an integer
        #          (maximum number of categories to be returned), or the
        #          literal 'all', that will cause the entire distribution
        #          in the node to be returned.
 
        # Checks if this is a regression model, using PROPORTIONAL
        # missing_strategy
        if (@tree.regression and missing_strategy == PROPORTIONAL and 
                !@regression_ready)
            raise ImportError "Failed to find the numpy and scipy libraries,
                               needed to use proportional missing strategy
                               for regressions. Please install them before
                               using local predictions for the model."
        end

        # Checks and cleans input_data leaving the fields used in the model
        new_data = filter_input_data(input_data, by_name, add_unused_fields)

        if add_unused_fields
          input_data, unused_fields = new_data
        else
          input_data = new_data
        end

        # Strips affixes for numeric values and casts to the final field type
        BigML::Util::cast(input_data, @fields)
        prediction = @tree.predict(input_data, nil,
                                   missing_strategy)
        if print_path
           out.puts '%s => %s ' % [' AND '.join(prediction.path), prediction["output"]]
        end


        output = prediction.output

        if with_confidence
            output = [prediction.output,
                      prediction.confidence,
                      prediction.distribution,
                      prediction.count,
                      prediction.median]
        end

        if !multiple.nil? and !@tree.regression
           output = []
           total_instances = prediction.count.to_f
           prediction.distribution.each_with_index do |data,index|
              category=data[0]
              instances=data[1]
              if ((multiple.is_a?(String) and multiple == 'all') or 
                  (multiple.is_a?(Integer) and index < multiple))
         
                  prediction_dict={'prediction' => category,
                                   'confidence' => BigML::ws_confidence(category, prediction.distribution),
                                   'probability' => instances/total_instances,
                                   'count' => instances}
                  output << prediction_dict
              end              
 
           end
        else
           if (add_confidence or add_path or add_distribution or add_count or
                    add_median or add_next or add_min or add_max or add_unused_fields)
               output = {'prediction' => prediction.output}

               if add_confidence
                   output['confidence'] = prediction.confidence
               end

               if add_path
                   output['path'] = prediction.path
               end

               if add_distribution
                    output["distribution"] = prediction.distribution
                    output["distribution_unit"] =  prediction.distribution_unit
               end

               if add_count
                  output['count'] = prediction.count
               end

               if @tree.regression and add_median
                  output['median'] = prediction.median
               end

               if add_next
                   field = prediction.children.size == 0 ? nil : prediction.children[0].predicate.field 
                   if !field.nil? and @fields.include?(field)
                     field = @fields[field]['name']
                   end
                   output['next']=field
               end

               if @tree.regression and add_min
                   output['min'] = prediction.min
               end

               if @tree.regression and add_max
                 output['max'] = prediction.max
               end

               if add_unused_fields
                  output['unused_fields'] = unused_fields
               end
           end
        end

        return output
     end

     def get_ids_path(filter_id)
        #
        # Builds the list of ids that go from a given id to the tree root
        #
        ids_path = nil
        if !filter_id.nil? and !@tree.id.nil?
            if !@ids_map.include?(filter_id) 
                raise ArgumentError "The given id does not exist."
            else
                ids_path = [filter_id]
                last_id = filter_id
                while !@ids_map[last_id].parent_id.nil? do
                    ids_path << @ids_map[last_id].parent_id
                    last_id = @ids_map[last_id].parent_id
                end
            end
        end
        return ids_path
     end

     def rules(out=$STDOUT, filter_id=nil, subtree=true)
        #
        # Returns a IF-THEN rule set that implements the model.
        # `out` is file descriptor to write the rules.
        #
        ids_path = get_ids_path(filter_id)
        return @tree.rules(out, ids_path, subtree)
     end
 
     def group_prediction()
        # Groups in categories or bins the predicted data

        # dict - contains a dict grouping counts in 'total' and 'details' lists.
        # 'total' key contains a 3-element list.
        #    - common segment of the tree for all instances
        #    - data count
        #    - predictions count
        #        'details' key contains a list of elements. Each element is a
        #              3-element list:
        #    - complete path of the tree from the root to the leaf
        #    - leaf predictions count
        #    - confidence
        #

       groups = {}
       tree = @tree
       distribution = tree.distribution

       distribution.each do |group|
           groups[group[0]] = {'total' => [[], group[1], 0],
                               'details' => []}
       end

       path = []

       def self.add_to_groups(groups, output, path, count, confidence,
                          impurity=nil)
            #Adds instances to groups array

            group = output
            if !groups.include?(output)
                groups[group] = {'total' => [[], 0, 0],
                                 'details' => []}
            end

            groups[group]['details'] << [path, count, confidence,
                                         impurity]
            groups[group]['total'][2] += count

       end

       def self.depth_first_search(groups, tree, path)
            # Search for leafs' values and instances

            if tree.predicate.is_a?(Predicate)
                path << tree.predicate
                if tree.predicate.term
                    term = tree.predicate.term
                    if !@terms.include?(tree.predicate.field) 
                        @terms[tree.predicate.field] = []
                    end
                    if !@terms[tree.predicate.field].include?(term)
                        @terms[tree.predicate.field] << term
                    end
                end
            end

            if tree.children.size() == 0
                add_to_groups(groups, tree.output,
                              path, tree.count, tree.confidence, tree.impurity)
                return tree.count
            else
                children = tree.children[0..-1]
                children.reverse!

                children_sum = 0
                children.each do |child|
                   children_sum += depth_first_search(groups, child, path[0..-1])
                end
                if children_sum < tree.count
                    add_to_groups(groups, tree.output, path,
                                  tree.count - children_sum, tree.confidence,
                                  tree.impurity)
                end
                return tree.count
            end
        end
 
        depth_first_search(groups, tree, path)
        return groups

     end

     def get_data_distribution()
       #
       # Returns training data distribution
       #
       tree = @tree
       distribution = tree.distribution
        
       return distribution.sort_by {|x| x[0]}
     end

     def get_prediction_distribution(groups=nil)
       #
       # Returns model predicted distribution
       #
       if groups.nil?
            groups = group_prediction()
       end

       predictions = groups.collect {|groupId, group| [groupId,group['total'][2]]}
       # remove groups that are not predicted
       predictions.reject! {|prediction| prediction[1] <= 0 }

       return predictions.sort_by {|x| x[0]}
     end

     def summarize(out=$STDOUT, format=BigML::BRIEF)
        #
        #Prints summary grouping distribution as class header and details
        #
        tree = @tree

        def extract_common_path(groups)
            #
            # Extracts the common segment of the prediction path for a group
            #
            groups.each do |group, value|
              details = groups[group]['details']
              common_path = []
              if details.size > 0
                mcd_len=details.collect {|x| x[0].size}.min
                (0..(mcd_len-1)).each do |i|
                   test_common_path=details[0][0][i]
                   details.each do |subgroup|
                      if subgroup[0][i] != test_common_path
                          i = mcd_len
                          break
                      end
                   end
                   if i < mcd_len
                      common_path << test_common_path
                   end
                end  
              end

              groups[group]['total'][0] = common_path

              if details.size > 0
                 groups[group]['details'] = details.sort_by {|x| -x[1]}
              end 
            end
         end

         def confidence_error(value, impurity=nil)
            # Returns confidence for categoric objective fields
            #   and error for numeric objective fields
            #
            if value.nil?
                return ""
            end
            impurity_literal = ""
            if !impurity.nil? and impurity > 0
                impurity_literal = "; impurity: %.2f%%" % [impurity.round(4)]
            end

            objective_type = @fields[tree.objective_id]['optype']
            if objective_type == 'numeric'
                return " [Error: %s]" % (value)
            else
                return " [Confidence: %.2f%%%s]" % [(value.round(4) * 100),
                                                     impurity_literal]
            end
         end

         distribution = get_data_distribution()

         out.puts "Data distribution:"
         BigML::print_distribution(distribution, out)
         out.puts
         out.puts

         groups = group_prediction()
         predictions = get_prediction_distribution(groups)

         out.puts "Predicted distribution:"
         BigML::print_distribution(predictions, out)
         out.puts 
         out.puts

         if @field_importance
            out.puts "Field importance:"
            print_importance(out)
         end

        extract_common_path(groups)
        out.puts
        out.puts
        out.puts "Rules summary:"

        predictions.collect {|x| x[0] }.each do |group|
          details = groups[group]['details']
          path = Path.new(groups[group]['total'][0])
          data_per_group = groups[group]['total'][1] * 1.0 / tree.count
          pred_per_group = groups[group]['total'][2] * 1.0 / tree.count
          out.puts
          out.print "%s : (data %.2f%% / prediction %.2f%%) %s" % [group,
                                                                  data_per_group.round(4)*100,
                                                                  pred_per_group.round(4)*100,
                                                                  path.to_rules(@fields, 'name', format)]
          if details.size == 0
             out.puts
             out.puts "    The model will never predict this class\n"
          elsif details.size == 1
             subgroup = details[0]
             out.print "%s\n" % confidence_error(subgroup[2], subgroup[3])
          else
             out.puts 
             (0..(details.size-1)).each do |j|
                subgroup = details[j]
                pred_per_sgroup = subgroup[1] * 1.0 / groups[group]['total'][2]
                path = Path.new(subgroup[0])

                if (path.predicates.nil? or path.predicates.empty?)
                  path_chain = "(root node)"
                else
                  path_chain = path.to_rules(@fields, 'name', format)
                end 
                out.puts "    · %.2f%%: %s%s" % [pred_per_sgroup.round(4)*100, path_chain, confidence_error(subgroup[2], subgroup[3])]
             end

          end
          out.puts
        end

        out.flush

     end

     def to_prediction(value_as_string, data_locale="UTF-8")
        #
        # Given a prediction string, returns its value in the required type
        #

        objective_id = @tree.objective_id
        if @fields[objective_id]['optype'] == 'numeric'
            if data_locale.nil? 
               data_locale = @locale
            end
            datatype = @fields[objective_id]['datatype']
            find_locale(data_locale)

            if ["double", "float"].include?(datatype)
               return value_as_string.to_f
            else
               return value_as_string.to_i
            end

        end

        return value_as_string
     end

   end

end

