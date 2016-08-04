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

require_relative 'util'
require_relative 'Predicates'

module BigML
  
   class AnomalyTree
      attr_accessor :predicates
      # An anomaly tree-like predictive model.
      def initialize(tree, fields)
 
        @fields = fields

        if tree['predicates'] == true 
            @predicates = Predicates.new([true])
        else
            @predicates = Predicates.new(tree['predicates'])
            @id = nil
        end

        children = []
        if tree.include?('children')
            tree['children'].each do |child|
               children << AnomalyTree.new(child, @fields)
            end
        end

        @children = children
      end

      def list_fields(out)
        # Lists a description of the model's fields.

        BigML::Util::sort_fields(@fields).each do |k, val|
            field = [ val('name'), val('optype') ]
            out.puts '[%-32s : %s]' % [field[0], field[1]]
            out.flush
        end
         
        return @fields

      end

      def depth(input_data, path=nil, depth=0)
        # Returns the depth of the node that reaches the input data instance
        #   when ran through the tree, and the associated set of rules.

        #   If a node has any children whose
        #   predicates are all true given the instance, then the instance will
        #   flow through that child.  If the node has no children or no
        #   children with all valid predicates, then it outputs the depth of the
        #   node.
        #

        if path.nil?
            path = []
        end
        # root node: if predicates are met, depth becomes 1, otherwise is 0
        if depth == 0
            if !@predicates.apply(input_data, @fields)
                return [depth, path]
            end
            depth += 1
        end

        if !@children.nil? and !@children.empty?
            @children.each do |child|
                if child.predicates.apply(input_data, @fields)
                    path << child.predicates.to_rule(@fields)
                    return child.depth(input_data, path, depth + 1)
                end
            end
        end

        return [depth, path]

      end

   end

end

