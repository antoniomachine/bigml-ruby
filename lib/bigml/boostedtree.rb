# -*- coding: utf-8 -*-
#!/usr/bin/env python
#
# Copyright 2017 BigML
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

# Tree structure for the BigML local boosted Model
# This module defines an auxiliary Tree structure that is used in the local
# boosted Ensemble to predict locally or embedded into your application
# without needing to send requests to BigML.io.

require_relative 'predicate'
require_relative 'prediction'
require_relative 'util'
require_relative 'tree'
 
module BigML

  class BoostedTree
     # A boosted tree-like predictive model.
     attr_accessor :predicate
     
     def initialize(tree, fields, objective_field=nil)

        @fields = fields
        @objective_id = @objective_field
        @output = tree['output']

        if tree['predicate'] == true
          @predicate = true
        else
          @predicate = BigML::Predicate.new(
                               tree['predicate']['operator'],
                               tree['predicate']['field'],
                               tree['predicate']['value'],
                               tree['predicate'].fetch('term', nil))
        end

        @id = tree.fetch('id', nil)
        children = []
        
        if tree.key?('children')
            tree['children'].each do |child|
                children << BoostedTree.new(child,
                                     @fields,
                                     objective_field)
           end
        end

        @children = children
        @count = tree['count']
        @g_sum = tree.fetch('g_sum', nil)
        @h_sum = tree.fetch('h_sum', nil)

     end

     def list_fields(out=$STDOUT)
        # Lists a description of the model's fields.
        
        BigML::Util::sort_fields(@fields).each do |key,val|
          field = [val['name'], val['optype']]
          out.puts "[%s%s: %s]\n" % [field[0],' '*32, field[1]]
        end

        return @fields
     end

     def predict(input_data, path=nil, missing_strategy=LAST_PREDICTION)
       # Makes a prediction based on a number of field values.

       # The input fields must be keyed by Id. There are two possible
       # strategies to predict when the value for the splitting field
       # is missing:
       #     0 - LAST_PREDICTION: the last issued prediction is returned.
       #     1 - PROPORTIONAL:  we consider all possible outcomes and create 
       #                        an average prediction.
       # 

       if path.nil?
         path = []
       end
       
       if missing_strategy == PROPORTIONAL
         return predict_proportional(input_data, path)
       else

         unless @children.empty?
            @children.each do |child|
               if child.predicate.apply(input_data, @fields)
                 path << child.predicate.to_rule(@fields)
                 return child.predict(input_data, path)
               end
            end            
         end

         return  BigML::Prediction.new(@output, path, nil, 
                                       nil, @count, nil, 
                                      nil, @children, nil, nil)

       end

     end

     def predict_proportional(input_data, path=nil,
                               missing_found=false)
       # Makes a prediction based on a number of field values considering all
       # the predictions of the leaves that fall in a subtree.
       # Each time a splitting field has no value assigned, we consider
       # both branches of the split to be true, merging their
       # predictions. The function returns the merged distribution and the
       # last node reached by a unique path

       if path.nil?
         path = []
       end

       unless @children.empty?
         return [@g_sum, @h_sum, @count, path]
       end 

       if BigML::one_branch(@children, input_data) or ["text", "items"].include?(@fields[BigML::split(@children)]["optype"])
          @children.each do |child|
             if child.predicate.apply(input_data, @fields)
                new_rule = child.predicate.to_rule(@fields)
                if !path.include?(new_rule) and !missing_found
                   path << new_rule
                end
                return child.predict_proportional(input_data, path, missing_found)
             end
          end
       else
          missing_found = true
          minimums = []
          maximums = []
          population = 0
          @children.each do |child|
            g_sum, h_sum, count, _ = child.predict_proportional(input_data, path, missing_found)
            g_sums += g_sum
            h_sums += h_sum
            population += count
          end

          return [g_sums, h_sums, population, path]
       end
     end

     def get_leaves(path=nil, filter_function=nil)
       # Returns a list that includes all the leaves of the tree
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
                'count' => @count,
                'g_sum' =>  @g_sum,
                'h_sum' => @h_sum,
                'output' =>  @output,
                'path' => path}

           if !filter_function.key?('__call__') or filter_function(leaf)
              leaves += [leaf]
           end
        end

        return leaves
 
     end

  end

end

