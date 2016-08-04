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

module BigML
  
   # Predicates structure for the BigML local AnomalyTree
   # This module defines an auxiliary Predicates structure that is used in the
   # AnomalyTree to save the node's predicates info.
 
   class Predicates
      def initialize(predicates_list)
        @predicates = []
        predicates_list.each do|predicate|
          if predicate == true
             @predicates << true
          else
             @predicates << Predicate.new(predicate.fetch("op", nil),
                                          predicate.fetch("field", nil),
                                          predicate.fetch("value", nil),
                                          predicate.fetch("term", nil))
          end
        end
      end 

      def to_rule(fields, label='name')
        #
        # Builds rule string from a predicates list
        #
        return (@predicates.reject {|predicate| !!predicate == predicate }.collect {|predicate| 
						predicate.to_rule(fields, label)}).join(" and ")
 
      end

      def apply(input_data, fields)
        #
        # Applies the operators defined in each of the predicates to
        #    the provided input data

        return @predicates.reject {|predicate| !predicate.is_a?(Predicate) }.collect {|predicate| predicate.apply(input_data, fields)}.all?

      end

  end

end

