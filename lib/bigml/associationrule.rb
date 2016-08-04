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
 
   SUPPORTED_LANGUAGES = ["JSON", "CSV"]

   class AssociationRule
      #
      # Object encapsulating an association rule as described in
      #    https://bigml.com/developers/associations
      #  
      attr_accessor :lhs, :rhs, :rhs_cover, :lhs_cover, :rule_id,
                    :confidence, :leverage, :p_value, :lift, :support

      def initialize(rule_info)
        @rule_id = rule_info.fetch('id')
        @confidence = rule_info.fetch('confidence')
        @leverage = rule_info.fetch('leverage')
        @lhs = rule_info.fetch('lhs', [])
        @lhs_cover = rule_info.fetch('lhs_cover', [])
        @p_value = rule_info.fetch('p_value')
        @rhs = rule_info.fetch('rhs', [])
        @rhs_cover = rule_info.fetch('rhs_cover', [])
        @lift = rule_info.fetch('lift')
        @support = rule_info.fetch('support', []) 
      end

      def out_format(language="JSON")
        #
        # Transforming the rule structure to a string in the required format
        #
        if SUPPORTED_LANGUAGES.include?(language)
           return self.send("to_%s" % language.lower())
        end
      end

      def to_csv()
        #
        # Transforming the rule to CSV formats
        #  Metrics ordered as in ASSOCIATION_METRICS in association.py
        #
        output = [@rule_id, @lhs, @rhs,
                  (@lhs_cover.nil? or @lhs_cover.empty?) ? nil : @lhs_cover[0],
                  (@lhs_cover.nil? or @lhs_cover.empty?) ? nil : @lhs_cover[1],
                  (@support.nil? or @support.empty?) ? nil : @support[0],
                  (@support.nil? or @support.empty?) ? nil : @support[1],
                  @confidence,
                  @leverage,
                  @lift,
                  @p_value,
                  (@rhs_cover.nil? or @rhs_cover.empty?) ? nil : @rhs_cover[0],
                  (@rhs_cover.nil? or @rhs_cover.empty?) ? nil : @rhs_cover[1]
                 ]
        return output
      end

      def to_json()
        #
        # Transforming the rule to JSON
        #
        rule_dict = {}
        self.instance_variables.each {|var| rule_dict[var.to_s.delete("@")] = self.instance_variable_get(var) }
        return rule_dict
     end

   end

end

