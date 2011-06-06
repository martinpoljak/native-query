# encoding: utf-8
require "native-query/query"

module NativeQuery

    ##
    # Represents join request.
    #
     
    class Join
    
        ##
        # Indicates table to join from.
        #
        
        @original
    
        ##
        # Indicates table to join.
        #
        
        @table
        
        ##
        # Indicates fields for select.
        #
        
        @fields
        
        ##
        # Holds joins specifiaction.
        #
        
        @joins
        attr_reader :joins
        
        ##
        # Holds join conditions.
        #
        
        @where
        
        ##
        # Indicates type of joining.
        # Possible values are:
        #
        #  * :indirect for M:N relation,
        #  * :direct for 1:N relation
        #
        
        @type
        
        ##
        # Indicates source of indirect joining.
        #
        # Usable, if joining performed through more than one step
        # without nesting.
        #
        
        @indirect_source
        
        ##
        # Indicates fields for direct joining.
        # Usable for "backwards" joining B -> A instead of A -> B.
        #
        
        @direct_fields
        
        ##
        # Constructor.
        #
        
        def initialize(original, table)
            @table = table
            @original = original
            @fields = [ ]
            @where = [ ]
            @joins = [ ]
            @type = :direct
            
            @indirect_source = original
        end
        
        ##
        # Sets hash for select from joined table.
        # Without arguments returns fields list. 
        #
        
        def fields(*args)
            if args.empty?
                result = { }
                @fields.each do |i|
                    if not i.kind_of? Hash
                        i = {i => i}
                    end
                    
                    i.each_pair do |from, to|
                        result[__fix_field(from)] = @table.to_s << "_" << to.to_s
                    end
                end
                
                return result
            else
                @fields += args
                return self
            end
        end
        
        ##
        # Sets join conditions.
        #
        
        def where(*args)
            @where += args
            return self
        end
        
        ##
        # Indicates indirect joining. (M:N)
        #
        
        def indirect(from = nil)
            @type = :indirect
            
            if not from.nil?
                @indirect_source = from
            end
            
            return self
        end
        
        ##
        # Indicates direct joining. (1:M)
        #
        
        def direct(fields = nil)
            @type = :direct
            
            if not fields.nil?
                @direct_fields = fields
            end
            
            return self
        end
        
        ##
        # Indicates "backwards" joining, so in opposite direction
        # than tables are designed and is usual from point of view 
        # of the library.
        #
        
        def backwards
            self.direct((@table.to_s << "_id").to_sym => :id)
        end

        ##
        # Builds ON join string.
        #
        
        def build
            result = nil
            
            case @type
                when :indirect
                    result = __indirect
                when :direct
                    result = __direct
            end
            
            return result
        end
        
        ##
        # Return wheres.
        #
        
        def wheres
            self._fix_where
        end
        
        ##
        # Calls mapping to joins specification. Call name is name of 
        # the target table.
        #
        # Block works by the same way as query, but for join. But 
        # intra-join calls doesn't work because it returns Query too.
        #
        
        def method_missing(sym, *args, &block)
            join = self.class::new(@table, sym)

            if args and not args.empty?
                join.fields(*args)
            end

            join.instance_eval(&block)
            @joins << join
            
            return self
        end
        
        ##
        # Fixes field name. Joins table name if SQL table joining
        # required.
        #
        
        private
        def __fix_field(name, formatted = false)
            NativeQuery::Query::fix_field(name, @table, formatted)
        end

        
        ##
        # Fixes where specification(s) if it's hash with symbol key.
        #
        
        protected
        def _fix_where
            NativeQuery::Query::fix_where(@where) do |i|
                __fix_field(i)
            end
        end
        
        ##
        # Builds indirect join.
        #
        
        private
        def __indirect
            result = { }
            to = @table.to_s
            
            if @indirect_source.nil?
                from = @original.to_s
            else
                from = @indirect_source.to_s
            end
        
            joining_table = (from + "_" + to).to_sym
            result[joining_table] = "[" << from << ".id] = [" << from << "_" << to << "." << from << "_id]"
            result[@table] = "[" << from << "_" << to << "." << to << "_id] = [" << to << ".id]"
            
            return result
        end
        
        ##
        # Builds direct join.
        #
        
        private
        def __direct
            original = @original.to_s
            from = @original.to_sym.to_s
            to = @table.to_sym.to_s
            result = { }
            
            if @direct_fields.nil?
                from << ".id"
                to << "." << original << "_id"
            else
                from << "." << @direct_fields.keys.first.to_s
                to << "." << @direct_fields.values.first.to_s
            end
            
            result[@table] = "[" << from << "] = [" << to << "]"
            return result
        end            
    end
end
