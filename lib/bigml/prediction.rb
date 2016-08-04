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
module BigML

  class Prediction
     # A Prediction object containing the predicted Node info or the
     # subtree grouped prediction info for proportional missing strategy
     #
     attr_reader :output, :confidence, :distribution, :path, :count, 
                 :distribution_unit, :median, :children, :min, :max 
 
     def initialize(output, path, confidence,
                    distribution=nil, count=nil, distribution_unit=nil,
		    median=nil, children=nile, d_max=nil, d_min=nil)

        @output = output
        @path = path
        @confidence = confidence
        @distribution = distribution.nil? ? [] : distribution

        @count = 0
        if count.nil?
          @distribution.each do |key,instances|
             count+=instances
          end
        else
           @count = count 
        end 

        @distribution_unit = distribution_unit.nil? ? 'categorical'  : distribution_unit
        @median = median
        @children = children.nil? ? [] : children
        @min = d_min
        @max = d_max	    
     end

     def print
       puts "output: %s" % @output
       puts "confidence: %s" % @confidence
     end
  end
end
