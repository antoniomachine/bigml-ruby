# encoding: utf-8
require_relative 'constants'
module BigML
  module Laminar
    
    def self.broadcast(fn, xs)
      if xs.size == 0
        return []
      elsif xs[0].is_a?(Array)
        return xs.map{|xvec| fn.call(xvec)}
      else
        return fn.call(xs)
      end 
    end
    
    def self.plus(mat, vec)
      return mat.collect{|row| row.zip(vec).map{|r,v| r+v}}
    end
    
    def self.minus(mat, vec)
      return mat.collect{|row| row.zip(vec).map{|r,v| r-v}}
    end
    
    def self.times(mat, vec)
      return mat.collect{|row| row.zip(vec).map{|r,v| r*v}}
    end
    
    def self.divide(mat, vec)
      return mat.collect{|row| row.zip(vec).map{|r,v| r/v}}
    end 
    
    def self.dot(mat1, mat2)
      out_mat = []
      mat1.to_a.each do |row1|
        new_row = mat2.map{|row2| row1.zip(row2).map{|m1,m2| m1*m2}.sum }
        out_mat << new_row
      end  
      
      return out_mat
    end
    
    def self.batch_norm(x, mean, stdev, shift, scale)
      norm_vals = divide(minus(x, mean), stdev)
      return plus(times(norm_vals, scale), shift)
    end    
    
    def self.sigmoid(xs)
      out_vec = []
      
      xs.each do |x|
        if x > 0
          if x < LARGE_EXP
            ex_val = Math.exp(x)
            out_vec << (ex_val / (ex_val + 1))
          else
             out_vec << 1
          end    
        else
          if -x < LARGE_EXP
            out_vec << (1 / (1 + Math.exp(-x)))
          else
             out_vec << 0
          end    
        end    
      end  
      
      return out_vec
    end
    
    def self.softplus(xs)
      return xs.map{|x| x<LARGE_EXP ? Math.log(Math.exp(x)+1) : x }
    end  
    
    def self.softmax(xs)
      xmax = xs.max
      exps = xs.map{|x| Math.exp(x-xmax)}
      sumex = exps.sum
      return exps.map{|ex| ex/sumex}
    end
    
    ACTIVATORS = {
      'tanh' => Proc.new {|xs| xs.map{|x| Math.tanh(x) } },
      'sigmoid' => Proc.new {|xs| sigmoid(xs)},
      'softplus' => Proc.new {|xs| softplus(xs)},
      'relu' => Proc.new {|xs| xs.map{|x| x>0 ? x : 0 }},
      'softmax' =>  Proc.new {|xs| softmax(xs)},
      'identity' => Proc.new {|xs| xs.map{|x| x.to_f }}
    }
      
    def self.init_layers(layers)
      return layers
    end
    
    def self.destandardize(vec, v_mean, v_stdev)
      return vec.map{|v| [ v[0]*v_stdev + v_mean]}
    end
        
    def self.to_width(mat, width)
      if width > mat.to_a[0].size
        ntiles = (width/mat.to_a[0].count.to_f).ceil.to_i
      else
        ntiles = 1
      end
      
      output = mat.to_a.map{|row| (row*ntiles)[0..(width-1)] }

      return output
    end

    def self.add_residuals(residuals, identities)
      to_add = to_width(identities, residuals[0].size)
      raise Exception, "" unless to_add[0].size == residuals[0].size

      return residuals.zip(to_add).collect {|rrow, vrow| rrow.zip(vrow).collect{|r,v| r+v} }
      
    end
        
    def self.propagate(x_in, layers)
      
      last_X = identities = x_in
      
      layers.each do |layer|
        
        w = layer['weights']
        m = layer['mean']
        s = layer['stdev']
        b = layer['offset']
        g = layer['scale']
        
        afn = layer['activation_function']
        
        x_dot_w = dot(last_X, w)
        
        if !m.nil? && !s.nil?
          next_in = batch_norm(x_dot_w, m, s, b, g)
        else
          next_in = plus(x_dot_w, b) 
        end  

        if layer.fetch('residuals', false)
          next_in = add_residuals(next_in, identities)
          last_X = broadcast(ACTIVATORS[afn], next_in)
          identities = last_X
        else
          last_X = broadcast(ACTIVATORS[afn], next_in)
        end    
      end  
    
      return last_X
    
    end
        
    def self.sum_and_normalize(youts, is_regression)
      ysums = []
      
      youts[0].each_with_index do |row,i|
        sum_row = []
        row.each_with_index do |r, j|
          sum_row << youts.collect{|yout| yout[i][j]}.sum
        end  
        
        ysums << sum_row
      end  
     
      out_dist = []
      if is_regression
        ysums.each do |ysum|
          out_dist << [ysum[0] / youts.size]
        end  
      else
        ysums.each do |ysum|
          rowsum = ysum.sum
          out_dist << ysum.map{|y| y / rowsum }
        end
      end
      
      return out_dist
    end
  end
end
    