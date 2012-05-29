# encoding: utf-8

require "native-query/result"
require "native-query/join"
require "hash-utils/object"
require "hash-utils/array"
require "hash-utils/hash"

module NativeQuery
    
    ##
    # Represents ORM query.
    #
     
    class Query
    
        ##
        # Brings database connection object.
        #
        
        @connection
        
        ##
        # Indicates upon which table query works.
        #
        
        @table
        
        ##
        # Holds list of fields to load.
        #
        
        @fields
        
        ##
        # Holds list of where conditions.
        #
        
        @where
        
        ##
        # Holds list of having conditions.
        #
        
        @having
                
        ##
        # Holds order specification.
        #
        
        @order
        
        ##
        # Joins for the query.
        #
        
        @joins
        
        ##
        # Indicates limit to load.
        #
        
        @limit
        
        ##
        # Indicates offset to load.
        #
        
        @offset
        
        ##
        # Holds group by settings.
        #
        
        @group
        
        ##
        # Constructor.
        #
        
        def initialize(connection, table, &block)
            @connection = connection
            @table = table
            @fields = [ ]
            @where = [ ]
            @having = [ ]
            @joins = [ ]
            @order = [ ]
            @group = [ ]
        end
        
        ##
        # Calls mapping to joins specification. Call name is name of 
        # the target table.
        #
        # Block works by the same way as query, but for join. But 
        # intra-join calls doesn't work because it returns Query too.
        #
        
        def method_missing(sym, *args, &block)
            join = Join::new(@table, sym)

            if args and not args.empty?
                join.fields(*args)
            end
            
            if not block.nil?
                join.instance_eval(&block)
            end
            
            @joins << join
            return self
        end
        
        ##
        # Selects fields which to load.
        #
        
        def fields(*args)
            @fields += args
            return self
        end
        
        ##
        # Selects where conditions to load.
        #
        
        def where(*args)
            @where << args
            return self
        end

        ##
        # Selects having conditions to load.
        #
        
        def having(*args)
            @having << args
            return self
        end
                
        ##
        # Selects fields for ordering according them.
        # Default order is :asc.
        #
        # Expects [:<field>, [:asc|:desc]]+ arguments.
        # 
        
        def order(*args)
            @order += args
            return self
        end
        
        ##
        # Sets limit to load.
        #
        
        def limit(limit)
            @limit = limit
            return self
        end
         
        ##
        # Sets offset to load.
        #
        
        def offset(offset)
            @offset = offset
            return self
        end 
        
        ##
        # Sets group by to load.
        #
        
        def group(*fields)
            @group = fields
            return self
        end

        ##
        # Returns result object.
        #
        
        def get
            
            # Builds query
            
                # Process joins
                join_fields, wheres, append_joins = self._process_joins
                
                # Checkouts regular fields
                if @joins.empty?
                    fields = @fields
                    hashes = [ ]
                    group = @group
                else
                    fields = @fields.map { |i| __fix_field(i) } 
                    hashes = fields.reject { |i| not i.hash? }
                    fields -= hashes
                end
                
                
                query = @connection.query
                
                if not fields.empty?
                    query.select(fields)
                end
                
                if not join_fields.empty?
                    query.select(join_fields)
                end
                
                if not hashes.empty?
                    hashes.each do |hash|
                        query.select(hash)
                    end
                end


                query.from(@table)

                # Appends joins
                append_joins.call(query)
                
                # Where conditions
                wheres += self._fix_where
                wheres.each { |i| query.where(*i) }
                
                # Where conditions
                havings = self._fix_having
                havings.each { |i| query.having(*i) }
                  
                # Grouping, ordering and having settings
                self._process_grouping(query)
                self._process_ordering(query)
                
                # Limit and offset
                if not @limit.nil?
                    query.limit(@limit)
                end
                
                if not @offset.nil?
                    query.offset(@offset)
                end

            # Returns
            return Result::new(query)
            
        end
        
        ##
        # Builds itself to string.
        #
        
        def build
            self.get.query.build
        end
        
        alias :"build!" :build
        
        ##
        # Process joins.
        #
        
        protected
        def _process_joins
            fields = { }
            wheres = [ ]
            specs = { }
            joins = [ ]
            
            new_joins = @joins.dup
            add_joins = [ ]
            
            # Agregates subjoins (e.g. joins from joins)
            while not new_joins.empty?
                new_joins.each do |join|
                    add_joins += join.joins
                end
                
                joins += new_joins
                new_joins = add_joins
                add_joins = [ ]
            end

            # Process joins
            joins.each do |join|
                fields.merge! join.fields
                wheres += join.wheres
                specs.merge! join.build
            end
            
            callback = Proc::new do |query|
                specs.each_pair do |join, on|
                    query.join(join).on(on)
                end
            end
            
            return fields, wheres, callback
        end
        
        ##
        # Process ordering settngs.
        #
        
        protected
        def _process_ordering(query)
            # Ordering settings
            if not @order.nil?
                @order.each do |i|
                    case i
                        when :asc
                            query.asc
                        when :desc
                            query.desc
                        else
                            if i.array?
                                query.orderBy("[" << i.first.to_s << "." << i.second.to_s << "]")
                            else
                                query.orderBy(__fix_field(i, true))
                            end
                    end
                end
            end
        end
        
        
        ##
        # Process ordering settngs.
        #
        
        protected
        def _process_grouping(query)
            # Grouping settings
            @group.each do |i|
                if i.array?
                    query.groupBy("[" << i.first.to_s << "." << i.second.to_s << "]")
                else
                    query.groupBy(__fix_field(i, true))
                end
            end
        end
        
        ##
        # Fixes field name. Joins table name if SQL table joining
        # required.
        #
        
        private
        def __fix_field(name, formatted = false)
            if not @joins.empty?
                result = self.class::fix_field(name, @table, formatted)
            else
                result = name
            end
            
            return result
        end
        
        ##
        # Fixes field name. Joins table name if SQL table joining
        # required.
        #
        
        def self.fix_field(name, table, formatted = false)
            if name.hash?
                result = name.map_keys { |k| self.fix_field(k, table, formatted) }
            else
                result = table.to_s + "." + name.to_s
            end
            
            if formatted
                result = "[" << result << "]"
            end
            
            return result
        end
        
        ##
        # Fixes where specification(s) if it's hash with symbol key.
        #
        
        protected
        def _fix_where
            Query::fix_conditions(@where) do |arg|
                __fix_field(arg)
            end
        end

        ##
        # Fixes having specification(s) if it's hash with symbol key.
        #
        
        protected
        def _fix_having
            Query::fix_conditions(@having) do |arg|
                #args.each do |i|
                    __fix_field(arg)
                #end
            end
        end
        
        ##
        # Fixes where specification(s) if it's hash with symbol key.
        # Block is fixer.
        #
        
        def self.fix_conditions(where, &block)
            where.map do |specification|
              
                if specification.array?
                    _new = specification.map do |item|
                        if item.hash?
                            item.map_keys do |k|
                                if k.symbol?
                                    block.call(k)
                                else
                                    k
                                end
                            end 
                        else
                            item
                        end
                    end
                else
                    _new = specification
                end
              
                #if specification.hash?
                #    _new = specification.map_keys do |k|
                #        if k.symbol?
                #            block.call(k)
                #        else
                #            k
                #        end
                #    end
                #else
                #    _new = specification
                #end
                
                _new  # returns
            end
        end
        
      end
end
