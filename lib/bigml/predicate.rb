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

  # Predicate structure for the BigML local Model
  # This module defines an auxiliary Predicate structure that is used in the Tree
  # to save the node's predicate info.

  # Map operator str to its corresponding function
  OPERATOR = {
    "<" => :<,
    "<=" => :<=,
    "=" => :==,
    "!=" => :!=,
    "/=" => :!=,
    ">=" =>  :>=,
    ">" => :>,
    "in" => :include?
  }

  TM_TOKENS = 'tokens_only'
  TM_FULL_TERM = 'full_terms_only'
  TM_ALL = 'all'
  FULL_TERM_PATTERN = /^.+\b.+$/

  RELATIONS = {
    '<=' => 'no more than %s %s',
    '>=' => '%s %s at most',
    '>' => 'more than %s %s',
    '<' => 'less than %s %s'
  }

  def self.term_matches(text, forms_list, options)
    # Counts the number of occurences of the words in forms_list in the text

    # The terms in forms_list can either be tokens or full terms. The
    # matching for tokens is contains and for full terms is equals.

    token_mode = options.fetch('token_mode', TM_TOKENS)
    case_sensitive = options.fetch('case_sensitive', false)
    first_term = forms_list[0]
    if token_mode == TM_FULL_TERM
      return full_term_match(text, first_term, case_sensitive)
    end

    # In token_mode='all' we will match full terms using equals and
    # tokens using contains
    if token_mode == TM_ALL and forms_list.size == 1
      if FULL_TERM_PATTERN.match(first_term)
         return full_term_match(text, first_term, case_sensitive)
      end
    end

    return term_matches_tokens(text, forms_list, case_sensitive)

  end

  def self.full_term_match(text, full_term, case_sensitive)
    #Counts the match for full terms according to the case_sensitive option

    if !case_sensitive
        text = text.downcase
        full_term = full_term.downcase
    end

    return text == full_term ? 1 : 0

  end

  def self.get_tokens_flags(case_sensitive)
    # Returns flags for regular expression matching depending on text analysis
    # options

    flags = ''
    if !case_sensitive
        flags = '?i:'
    end

    return flags
  end

  def self.term_matches_tokens(text, forms_list, case_sensitive)
    # Counts the number of occurences of the words in forms_list in the text

    flags = get_tokens_flags(case_sensitive)
    expression = '(\b|_)%s(\b|_)' % [forms_list.join('(\\b|_)|(\\b|_)')]

    if flags != ''
       pattern = /#{expression}/i
    else
      pattern = /#{expression}/
    end

    return text.scan(pattern).size

  end

  def self.item_matches(text, item, options)
    # Counts the number of occurences of the item in the text

    # The matching considers the separator or
    # the separating regular expression.

    separator = options.fetch('separator', ' ')
    regexp = options.fetch('separator_regexp', nil)
    if regexp.nil?
      regexp = "%s" % [Regexp.quote(separator)]
    end

    return count_items_matches(text, item, regexp)
  end

  def self.count_items_matches(text, item, regexp)
    # Counts the number of occurences of the item in the text

    expression = '(^|%s)%s($|%s)' % [regexp, item, regexp]
    pattern = /#{expression}/
    return text.scan(pattern).size

  end

  class Predicate 
     #
     # A predicate to be evaluated in a tree's node.
     #
     attr_accessor :field, :missing, :value, :term, :operator

     def initialize( operation, field, value, term=nil)
        @operator = operation
        @missing = false
        if @operator.end_with?("*")
            @operator = @operator[0..-2]
            @missing = true 
        end

        @field = field
        @value = value
        @term = term
     end

     def is_full_term(fields)
        #
        #Returns a boolean showing if a term is considered as a full_term
        #
        if !@term.nil? 
            # new optype has to be handled in tokens
            if fields[@field]['optype'] == 'items'
                return false
            end

            options = fields[@field]['term_analysis']
            token_mode = options.fetch('token_mode', TM_TOKENS)

            if token_mode == TM_FULL_TERM
               return true
            end

            if token_mode == TM_ALL
               pattern = /#{FULL_TERM_PATTERN}/
          
               return pattern.match(@term)
            end
        end

        return false

     end

     def to_rule(fields, label='name', missing=nil)
        #Builds rule string from a predicate

        # externally forcing missing to True or False depending on the path
        if missing.nil?
            missing = @missing
        end

        if !label.nil?
            name = fields[@field][label]
        else
            name = ""
        end

        full_term = is_full_term(fields)
        relation_missing = missing ? " or missing" : ""

        if !@term.nil?
            relation_suffix = ''
            if ((@operator == '<' and @value <= 1) or
                    (@operator == '<=' and @value == 0))
                relation_literal = full_term ? 'is not equal to' : 'does not contain'
            else
                relation_literal = full_term ? 'is equal to' : 'contains'
                if !full_term
                    if @operator != '>' or @value != 0
                        relation_suffix = RELATIONS[@operator] %
                                           [value,
                                            plural('time', self.value)]
                    end
                end
            end

            return "%s %s %s %s%s" % [name, relation_literal,
                                       @term, relation_suffix,
                                       relation_missing]
        end

        if @value.nil?
            return "%s %s" % [name,
                               @operator == '=' ? "is missing" : "is not missing"]
        end

        return "%s %s %s%s" % [name,
                                @operator,
                                @value,
                                relation_missing]
     end

     def apply(input_data, fields)
        # Applies the operators defined in the predicate as strings to
        # the provided input data

        # for missing operators
        if input_data.fetch(@field, nil).nil?
            # text and item fields will treat missing values by following the
            # doesn't contain branch
            if @term.nil?
                return (@missing or (@operator == '=' and @value.nil?))
            end
        elsif @operator == '!=' and @value.nil?
            return true
        end

        if !@term.nil?
            if fields[@field]['optype'] == 'text'
                all_forms = fields[@field]['summary'].fetch('term_forms', {})
                term_forms = all_forms.fetch(@term, [])
                terms = [@term]
                terms.concat(term_forms)
                options = fields[@field]['term_analysis']
                return BigML::term_matches(input_data.fetch(@field, ""), terms, options).send(OPERATOR[@operator], @value)

            else
                # new items optype
                options = fields[@field]['item_analysis']
                return BigML::item_matches(input_data.fetch(@field, ""), @term, options).send(OPERATOR[@operator], @value)
            end
        end

        if @operator == "in"
            return @value.send(OPERATOR[@operator], input_data[@field])
        end

        return input_data[@field].send(OPERATOR[@operator], @value)

     end

  end

end  
