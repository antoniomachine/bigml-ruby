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

require_relative 'predicate'
require_relative 'stats'
require_relative 'prediction'
require_relative 'multivote'
require_relative 'util'
require_relative 'tree_utils'

module BigML
  #Tree structure for the BigML local Model

  # This module defines an auxiliary Tree structure that is used in the local Model
  # to make predictions locally or embedded into your application without needing
  # to send requests to BigML.io.

  MISSING_OPERATOR = {
    "=" => "is",
    "!=" => "is not"
  }

  T_MISSING_OPERATOR = {
    "=" => "ISNULL(",
    "!=" => "NOT ISNULL("
  }

  LAST_PREDICTION = 0
  PROPORTIONAL = 1

  DISTRIBUTION_GROUPS = ['bins', 'counts', 'categories']

  def self.get_instances(distribution)
    #Returns the total number of instances in a distribution
    return distribution.empty? ? 0 : distribution.inject(0) { |sum, x| sum + x[1] }
  end

  def self.mean(distribution)
    #Computes the mean of a distribution in the [[point, instances]] syntax
    addition = 0.0
    count = 0.0
  
    distribution.each do |point, instances|
       addition += point * instances
       count += instances
    end 

    if count > 0
        return addition / count
    end
    return Float::INFINITY
  end

  def self.unbiased_sample_variance(distribution, distribution_mean=nil)
    # Computes the standard deviation of a distribution in the
    #   [[point, instances]] syntax

    addition = 0.0
    count = 0.0
    if (distribution_mean.nil? or !distribution_mean.is_a?(Numeric))
        distribution_mean = mean(distribution)
    end

    distribution.each do |point, instances|
      addition += ((point - distribution_mean) ** 2) * instances
      count += instances
    end 

    if count > 1
       return addition / (count - 1)
    end

    return Float::INFINITY

  end

  def self.regression_error(distribution_variance, population, r_z=1.96)
    #Computes the variance error
    # php $ppf=AChiSq($stats::erf($r_z / sqrt(2) ), $population);
    if population > 0
        ppf = Stats::AChiSq(Stats::erf( r_z/Math.sqrt(2) ), population)

        if ppf != 0
          error = distribution_variance * (population - 1) / ppf
          error = error * ((Math.sqrt(population) + r_z) ** 2)
          return Math.sqrt(error / population)
        end
    end

    return Float::INFINITY

  end

  def self.extract_distribution(summary)
    # Extracts the distribution info from the objective_summary structure
    #   in any of its grouping units: bins, counts or categories
   
    DISTRIBUTION_GROUPS.each do |group|
       if summary.include?(group)
          return [group, summary.fetch(group)]
       end
    end 
  end

  def self.dist_median(distribution, count)
    #Returns the median value for a distribution

    counter = 0
    previous_value = nil 
    distribution.each do |value, instances|
       counter += instances
       if counter > count / 2.0
          if ((count % 2) != 0 and (counter - 1) == (count / 2) and !previous_value.nil?)
             return (value + previous_value) / 2.0
          end
          return value
       end
       previous_value = value
    end
    return nil
  end

  class Tree
     attr_accessor :regression, :predicate, :output, :children, :predicate, :confidence,
                   :distribution, :distribution_unit, :median, :min, :max, 
		   :objective_id, :fields, :count, :impurity, :weighted
     # A tree-like predictive model.

     def initialize(tree, fields, objective_field=nil,
                    root_distribution=nil, parent_id=nil, ids_map=nil,
                    subtree=true, tree_info=nil)

        @fields = fields
        @objective_id = objective_field
        @output = tree['output']

        if tree['predicate'] == true
            @predicate = true
        else
            @predicate = BigML::Predicate.new(tree['predicate']['operator'],
                                      tree['predicate']['field'],
                                      tree['predicate']['value'],
                                      tree['predicate'].fetch('term', nil))
        end
 
        if tree.key?('id')
            @id = tree['id']
            @parent_id = parent_id
            if ids_map.is_a?(Hash)
                ids_map[@id] = self
            end
        else
            @id = nil 
        end

        children = []
        if tree.key?('children')
            tree['children'].each do |child|
                children << Tree.new(child,
                                     @fields,
                                     objective_field,
                                     nil,
                                     @id,
                                     ids_map,
                                     subtree,
                                     tree_info)
           end
        end
        @children = children
        @regression = is_regression()
        tree_info['regression'] = (@regression and
                                   tree_info.fetch('regression', true))
        @count = tree['count']
        @confidence = tree.fetch('confidence', nil)
        @distribution = nil
        @max = nil
        @min = nil
        @weighted = false
        @median = nil
        summary = nil 
        if tree.key?('distribution')
           @distribution = tree['distribution']
        elsif tree.key?('objective_summary') 
            summary = tree['objective_summary']
            @distribution_unit,
            @distribution = BigML::extract_distribution(summary)
            if tree.key?('weighted_objective_summary')
                 summary = tree['weighted_objective_summary']
                 @weighted_distribution_unit,
                 @weighted_distribution = BigML::extract_distribution(summary)
                 @weight = tree["weight"]
                 @weighted = true
            end
        else
            summary = root_distribution
            @distribution_unit,
            @distribution = BigML::extract_distribution(summary)
        end

        if @regression
            tree_info['max_bins'] = [tree_info.fetch('max_bins', 0),
                                        @distribution.size].max
            
            if !summary.nil? and !summary.empty?
                @median = summary.fetch('median')
            end
            if @median.nil?
                @median = BigML::dist_median(@distribution, @count)
            end

            if summary.key?("maximum") 
              @max = summary["maximum"]
            else
              @max = @distribution.collect {|key, instances| key }.max 
            end

            if summary.key?("minimum") 
              @min = summary["minimum"]
            else
              @min = @distribution.collect {|key, instances| key }.min 
            end
        end

        @impurity = nil 
        if not @regression and !@distribution.nil?
            @impurity = gini_impurity()
        end

     end

     def gini_impurity()
        # Returns the gini impurity score associated to the distribution
        # in the node

        purity = 0.0
        if @distribution.nil? 
            return nil
        end
	@distribution.each do |key, instances|
	   purity+=(instances/@count.to_f) ** 2
	end
        return 1.0 - purity
     end


     def list_fields(out=$STDOUT)
        # Lists a description of the model's fields.
        out.puts "<%s%s: %s>" % [@fields[@objective_id]['name'], ' '*32, @fields[@objective_id]['optype']]

        BigML::Util::sort_fields(@fields).each do |key,val|
           if key != @objective_id
              out.puts "[%s%s: %s]" % [val['name'], val['optype']]
           end
        end

        return @fields
     end
 
     def is_regression()
        # Checks if the subtree structure can be a regression

        if @output.is_a?(String)
            return false
        end

        if @children.nil?
            return true
        else
            return !@children.collect {|child| child.output.is_a?(String) }.any?
        end
     end

     def get_leaves(path=nil, filter_function=nil)
        # Returns a list that includes all the leaves of the tree.

        leaves = []
        if path.nil? 
            path = []
        end

        if !(!!@predicate == @predicate)
            path << @predicate.to_lisp_rule(@fields)
        end

        if !@children.nil?
            @children.each do |child|
               leaves += child.get_leaves(path,filter_function) 
            end
        else
            leaf = {
                'id' =>  @id,
                'confidence' => @confidence,
                'count' => @count,
                'distribution' =>  @distribution,
                'impurity' => @impurity,
                'output' =>  @output,
                'path' => path}

           if defined?(@weighted_distribution)
             leaf.merge!({"weighted_distribution": @weighted_distribution,
                          "weight": @weight})
           end    
           
           if !filter_function.key?('__call__') or filter_function(leaf)
              leaves += [leaf]
           end
        end

        return leaves
     end

     def predict(input_data, path=nil, missing_strategy=LAST_PREDICTION)
       # Makes a prediction based on a number of field values.

       # The input fields must be keyed by Id. There are two possible
       # strategies to predict when the value for the splitting field
       # is missing:
       #     0 - LAST_PREDICTION: the last issued prediction is returned.
       #     1 - PROPORTIONAL: as we cannot choose between the two branches
       #         in the tree that stem from this split, we consider both. The
       #         algorithm goes on until the final leaves are reached and
       #         all their predictions are used to decide the final prediction.
       # 

        if path.nil?
            path = []
        end
        if missing_strategy == PROPORTIONAL
          final_distribution,
             d_min,
             d_max,
             last_node,
             population,
             parent_node = predict_proportional(input_data, path)
          
          if @regression
             # singular case:
             # when the prediction is the one given in a 1-instance node
             if final_distribution.keys.size == 1
                prediction, instances = final_distribution.keys[0], 
                                        final_distribution.values[0]
                if instances == 1
                   return BigML::Prediction.new(
                            last_node.output,
                            path,
                            last_node.confidence,
                            @weighted ? last_node.weighted_distribution : last_node.distribution,
                            instances,
                            last_node.distribution_unit,
                            last_node.median,
                            last_node.children,
                            last_node.min,
                            last_node.max)
                end
             end
             # when there's more instances, sort elements by their mean
             distribution=final_distribution.sort_by {|k, v| k }.collect{ |k, v| [k,v] }
             distribution_unit = distribution.size > BINS_LIMIT ? 'bins' : 'counts' 
             distribution = BigML::merge_bins(distribution, BINS_LIMIT)

             total_instances = distribution.collect{|k,instances| instances}.inject(0){|sum,x|sum+x}

             if distribution.size == 1
               # where there's only one bin, there will be no error, but
               # we use a correction derived from the parent's error
               
               prediction = distribution[0][0]
               if total_instances < 2
                  total_instances = 1
               end
               
               begin
                 confidence = (parent_node.confidence / Math.sqrt(total_instances)).round(BigML::Util::PRECISION)
               rescue
                 confidence = nil
               end    
               
             else
               prediction = BigML::mean(distribution)

               confidence = BigML::regression_error(BigML::unbiased_sample_variance(distribution, prediction),
                                           total_instances).round(BigML::Util::PRECISION)
             end
             return BigML::Prediction.new(prediction,
                               path,
                               confidence,
                               distribution,
                               total_instances,
                               distribution_unit,
                               BigML::dist_median(distribution, total_instances),
                               last_node.children,
                               d_min,
                               d_max)
          else
            distribution=final_distribution.sort_by {|k, v| [-v, k] }.collect{ |k, v| [k,v] }
            return BigML::Prediction.new(
                    distribution[0][0],
                    path,
                    BigML::ws_confidence(distribution[0][0], final_distribution, 1.96, population),
                    distribution,
                    population,
                    'categorical',
                    nil,
                    last_node.children)
          end

        else
           if !@children.nil?
               @children.each do |child|
                 if child.predicate.apply(input_data, @fields)
                    path << child.predicate.to_rule(@fields)
                    return child.predict(input_data, path)
                 end
               end
           end
           
           if @weighted
             output_distribution = @weighted_distribution
             output_unit = @weighted_distribution_unit
           else
             output_distribution = @distribution
             output_unit = @distribution_unit
           end
           
           return BigML::Prediction.new(
                @output,
                path,
                @confidence,
                output_distribution,
                BigML::get_instances(output_distribution),
                output_unit,
                @regression.nil? ? nil : @median,
                @children,
                @regression.nil? ? nil : @max,
                @regression.nil? ? nil : @min) 
        end
     end

     def predict_proportional(input_data, path=nil,
                             missing_found=false, median=false, parent=nil)
        # Makes a prediction based on a number of field values averaging
        #   the predictions of the leaves that fall in a subtree.

        #   Each time a splitting field has no value assigned, we consider
        #   both branches of the split to be true, merging their
        #   predictions. The function returns the merged distribution and the
        #   last node reached by a unique path.
        if path.nil?
          path = []
        end
        
        final_distribution = {}
 
        if @children.nil? or @children.empty?
          distribution = !@weighted ? @distribution : @weighted_distribution 
          dict = {}
          distribution.each do |x|
            dict[x[0]] = x[1]
          end

          result = [BigML::merge_distributions({}, dict), @min, @max, self, @count, parent]
          return result
        end

        if BigML::one_branch(@children, input_data) or ["text", "items"].include?(@fields[BigML::Util::split(@children)]["optype"]) 
           @children.each do |child|
             if child.predicate.apply(input_data, @fields)
                new_rule = child.predicate.to_rule(@fields)
                if !path.include?(new_rule) and !missing_found
                   path << new_rule
                end
                return child.predict_proportional(input_data, path, missing_found, median, self)
             end
           end 
        else
          # missing value found, the unique path stops
          missing_found = true
          minimums = []
          maximums = []
          population = 0
          @children.each do |child|
             subtree_distribution, subtree_min, subtree_max, _, subtree_pop, _ = child.predict_proportional(input_data, path, missing_found, median, parent)
             if !subtree_min.nil?
                minimums << subtree_min
             end

             if !subtree_max.nil?
               maximums << subtree_max
             end

             population += subtree_pop
             final_distribution = BigML::merge_distributions(
                        final_distribution, subtree_distribution)

          end

          return [final_distribution, 
                  !minimums.empty? ? minimums.min : nil,
                  !maximums.empty? ? maximums.max : nil,
                  self, population, self]
        end    

     end

     def generate_rules(depth=0, ids_path=nil, subtree=true)
        # Translates a tree model into a set of IF-THEN rules.
        rules = ""
        children = BigML::filter_nodes(@children, ids_path,
                                         subtree)
        if !children.nil?
            children.each do |child|
               rules += "%s IF %s %s\n" % [INDENT * depth, 
                                           child.predicate.to_rule(@fields, 'slug'),
                                           (child.children.nil? or child.children.empty?) ? "THEN" : "AND"]
               rules += child.generate_rules(depth + 1, ids_path, subtree)
            end
        else
            rules += "%s %s = %s\n" % [INDENT * depth,  
                                       @objective_id.nil? ? "Prediction" :
                                          @fields[@objective_id]['slug'], 
                                       @output]
        end

        return rules
     end

     def rules(out, ids_path=nil, subtree=true)
        # Prints out an IF-THEN rule version of the tree.
        BigML::Util::sort_fields(@fields).each do |field, value|
          slug = BigML::Util::slugify(@fields[field]["name"])
          @fields[field]['slug'] = slug 
        end 

        out.puts generate_rules(0, ids_path, subtree)
        out.close
     end
  end
end
