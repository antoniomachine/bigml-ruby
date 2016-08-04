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
  class Stats
     def initialize()
     end
     
     def self.AChiSq(p,n) 
       v=0.5
       dv=0.5
       x=0
       while (dv>1e-15) do
          x=(1.0/v)-1
          dv=dv/2.0
          if (ChiSq(x,n)>p)
            v=v-dv;
          else
            v=v+dv;
          end
       end

       return x
     end

     def self.Norm(z)
       q=z*z
       if (z.abs>7.0)
          return (1-(1/q)+(3.0/(q*q)))*Math.exp(-q/2)/(z.abs*Math.sqrt(Math::PI/2.0))
       else
          return ChiSq(q,1.0)
       end
     end

    def self.ChiSq(x,n)
       if (x>1000 || n>1000) 

         a = ((x/n) ** (1.0/3.0))+(2/(9*n))-1
         b = Math.sqrt(2/(9*n))

         q=Norm(a/b)/2.0

         if (x>n)
           return q
         else
           return 1-q
         end
       end

       p=Math.exp(-0.5*x)
      if ((n%2)==1) 
         p=p*Math.sqrt((2*x)/Math::PI)
      end 

      k=n
      while (k>=2) do
        p=(p*x)/k
        k=k-2
      end

      t=p
      a=n

      while(t>1e-15*p) do
        a=a+2
        t=(t*x)/a
        p=p+t
      end

      return 1-p

    end

    
    # Error Function
    # 
    # Returns the real error function of a number.
    # An approximation from Abramowitz and Stegun is used.
    # Maximum error is 1.5e-7. More information can be found at
    # http://en.wikipedia.org/wiki/Error_function#Approximation_with_elementary_functions
    # 
    # @param float $x Argument to the real error function
    # @return float A value between -1 and 1
    # @static
    #
    def self.erf(x)
      if (x < 0)  
         return -erf(-x)
      end

      t = 1 / (1 + 0.3275911 * x)
      return 1 - (0.254829592*t - 0.284496736*(t ** 2) + 1.421413741*(t ** 3) + -1.453152027*(t ** 4) + 1.061405429*(t ** 5))*Math.exp(-(x ** 2));

    end

  end
end
