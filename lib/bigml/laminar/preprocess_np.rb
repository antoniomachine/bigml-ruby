# encoding: utf-8
require_relative 'constants'
require "numo/narray"
module BigML
  module Laminar
    
    # TODO np.vectorize(
    # TODO np.asarray
    # TODO np.c_
    # TODO np.zeros
    # TODO .sum(axis=1, keepdims=True)
    
    MODE_CONCENTRATION = 0.1
    MODE_STRENGTH = 3

    MEAN = "mean"
    STANDARD_DEVIATION = "stdev"

    ZERO = "zero_value"
    ONE = "one_value"
    
    def self.search_index(alist, value)
      begin
        return alist.index(value)
      rescue
        return nil
      end  
    end
          
    def self.one_hot(vector, possible_values)
      idx = []
      vector.each_with_index do |v,i|
        idx << [i, search_index(possible_values, v)]
      end  
      
      valid_pairs = idx.select{|x| !x[1].nil? }

      outvec = Numo::Float32.zeros(idx.size, possible_values.size)
      
      valid_pairs.each do |v|
        outvec[v[0], v[1]] = 1
      end

      return outvec
    end
      
    def self.standardize(vector, mn, stdev)
      newvec = vector-mn

      if stdev > 0
        newvec = newvec/stdev
      end
      
      if newvec.is_a?(Float) && newvec.nan?
        newvec = 0.0
      else  
        newvec = newvec.map{|x| x.to_f.nan? ? 0.0 : x}
      end
      return newvec
    end
    
    def self.binarize(vector, zero, one)
      if one == 0.0
        vector[vector == one] = 1.0
        vector[(vector != one) & (vector != 1.0)] = 0.0
      else
        vector[vector != one] = 0.0
        vector[vector == one] = 1.0
      end
      return vector
    end
            
    def self.moments(amap)
      return amap[MEAN], amap[STANDARD_DEVIATION]
    end
    
    def self.bounds(amap)
      return amap[ZERO], amap[ONE]
    end
    
    def self.transform(vector, spec)
      vtype = spec['type']
      if vtype == BigML::Laminar::NUMERIC
        if spec.key?(STANDARD_DEVIATION)
          mn, stdev = moments(spec)
          output = standardize(vector, mn, stdev)
        elsif spec.key?(ZERO)
          low, high = bounds(spec)
          output = binarize(vector, low, high)
        else
          raise ArgumentError.new("'%s' is not a valid numeric spec!" % spec.to_s)    
        end  
          
      elsif vtype == BigML::Laminar::CATEGORICAL 
        output = one_hot(vector, spec['values'])
      else
        raise ArgumentError.new("'%s' is not a valid spec type!" % vtype) 
      end  
      return output
    end
    
    def self.tree_predict(tree, point)
      node = tree[0..-1]
      while !node[-1].nil?
        if point[node[0]] <= node[1]
            node = node[2]
        else
            node = node[3]
        end
      end
      return node[0]
    end    
    
    def self.get_embedding(x, model)
      if model.is_a?(Array)
        preds = nil
        model.each do|tree|
          tree_preds = []
          x.to_a.each do |row|
            tree_preds << tree_predict(tree, Numo::Float32.cast(row))
          end  
          if preds.nil?
            preds =  Numo::Float32.cast(tree_preds.to_a)#Numo::DFloat[tree_preds]
          else
            preds +=  Numo::Float32.cast(tree_preds.to_a)# Numo::DFloat[tree_preds]
          end    
          
        end  
        
        if preds.to_a[0].size > 1
          total = preds.to_a.map{|i| i.inject(0) {|sum,x|sum+x}}
          
          result = []
          
          preds.to_a.each_with_index do |p,idx|
            result << p.map{|x| x/total[idx] }
          end  
          
          preds=result
          
        else

          result = []
          preds.to_a.each do |p|
            result << p.map{|x| x/model.size }
          end 
          preds=result
        end
        
        return preds
        
      else
          raise ArgumentError, "Model is unknown type!"
      end
    end
    
    def self.tree_transform(x, trees)
      outdata = nil
      trees.each do |feature_range, model|
        sidx, eidx = feature_range
        inputs = Numo::Float32.cast(x.to_a.map{|it| it[sidx..(eidx-1)]})
        outarray = get_embedding(inputs, model)
        
        if !outdata.nil?  
          if outdata.is_a?(Float)
            outdata = Numo::Float32.cast([[outdata,outarray]])
          else
            if outarray.is_a?(Float)
              outdata= Numo::Float32.cast(outdata.to_a.map{|i| i << outarray})
            else
              result=[]
              outdata.to_a.each_with_index do |i, index|
                result << i+outarray[index]
              end  
              outdata=  Numo::Float32.cast(result)
            end  
          end    
        else
          outdata = outarray
        end 
        
        #if outdata.nil?
        #  outdata = outdata.zip(outarray)
        #else
        #  outdata = outarray  
        #end
      end
      
      if x.is_a?(Float)
        outdata= Numo::Float32.cast(outdata.to_a.map{|i| i << x})
      else
        result=[]
        outdata.to_a.each_with_index do |i, index|
          result << i+x.to_a[index]
        end  
        outdata=  Numo::Float32.cast(result)
        
        #outdata= Numo::Float32.cast(outdata.to_a.map{|i| i+x.to_a })
      end
      
      return  outdata#.zip(x)
    end    
  
    def self.preprocess(columns, specs)
      outdata = nil

      specs.each do |spec|
        column = columns[spec['index']]
        if spec['type'] == BigML::Laminar::NUMERIC
          column = column.nil? ? Float::NAN : Numo::Float32.cast(column)
        end

        outarray = transform(column, spec)
        
        if !outdata.nil?  
          if outdata.is_a?(Float)
            outdata = Numo::Float32.cast([[outdata,outarray]])
          else
            if outarray.is_a?(Float)
              outdata= Numo::Float32.cast(outdata.to_a.map{|i| i << outarray})
            else
              result = []
              outdata.to_a.each do|i|
                if i.is_a?(Float)
                  i = [i]
                end
                
                result << i+outarray.to_a
              end  
              
              outdata= Numo::Float32.cast(result)
            end  
            #outdata= Numo::Float32.cast(outdata.to_a.map{|i| i << outarray})
          end    
          #outdata = outdata.is_a?(Float) ? Numo::Float32.cast([[outdata,outarray]]) : outdata.append(outarray)
        else
          outdata = outarray
        end  
      end

      return outdata
    end
    
  end
end    