require File.expand_path("#{File.dirname(__FILE__)}/at-validations/version.rb")


# We're adding (monkey-patching) a method to Object and to Hash.
#
# Hash gets this convenience method:
#
#   {hello: :world}.matches_mask({
#     _id: atv_string,
#     status: atv_union(
#               atv_number,
#               atv_block {|e| e >= 200 && e < 300 })
#   })
#

class Hash
  def matches_mask(mask, opts = {})
    ATValidations::Predicates.atv_hash(mask, opts).call(self)
  end
end

class Object
  def matches_predicate(predicate)
    predicate.call(self)
  end
end


module ATValidations

  module Predicates
    def atv_block(&b)
      b
    end

    def atv_hash(mask, opts = {})
      atv_union(
        atv_instance_of(Hash),
        atv_block do |e|
          errors = {}
          mask.each do |k, v|
            r = v.call(e[k])
            errors[k] = r unless true == r
          end
          if false == opts[:allow_extra] && (extra = (e.keys - mask.keys)).count > 0
            extra.each {|k| errors[k] = 'is not present in predicate' }
          end

          errors.empty? || Error.new(:error => 'must match hash predicate', :failures => errors)
        end
      )
    end

    def atv_array_of(predicate)
      atv_union(
        atv_instance_of(Array),
        atv_block do |e|
          errs = {}
          e.each_index {|i| err = predicate.call(e); errs[i] = err unless true == err }
          errs.count == 0 || Error.new(:error => 'array contains elements which do not match predicate', :failures => errs)
        end
      )
    end

    def atv_union(*predicates)
      atv_block do |e|
        err = nil
        nil == predicates.find {|p| true != (err = p.call(e)) } ||
          Error.new(:error => 'must match all predicate in union', :failure => err)
      end
    end

    def atv_option(*predicates)
      atv_block do |e|
        errs = []
        nil != predicates.find {|p| true == (errs << p.call(e)).last } ||
          Error.new(:error => 'must match at least one predicate in option', :failure => errs)
      end
    end

    def atv_in_set(*set)
      atv_block do |e|
        set.include?(e) || Error.new(:error => "must be in set #{set}")
      end
    end

    def atv_equal(value)
      atv_block do |e|
        e == value || Error.new(:error => "must be equal to #{value}")
      end
    end

    def atv_instance_of(klass)
      atv_block do |e|
        e.is_a?(klass) || Error.new(:error => "must be a #{klass}")
      end
    end

    def atv_numeric
      atv_instance_of(Numeric)
    end

    def atv_string
      atv_instance_of(String)
    end

    def atv_symbol
      atv_instance_of(Symbol)
    end

    def atv_nil_or(predicate)
      atv_block do |e|
        nil == e || predicate.call(e)
      end
    end
  end

  class Error < StandardError
    def initialize(info = {})
      @info = info
    end
    def to_s
      @info.to_s
    end
  end
end
