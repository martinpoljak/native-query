# encoding: utf-8

require "native-query/result"
require "native-query/join"

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
        # Holds list of conditions.
        #
        
        @where
        
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
        # Constructor.
        #
        
        def initialize(connection, table, &block)
            @connection = connection
            @table = table
            @fields = [ ]
            @where = [ ]
            @joins = [ ]
            @order = [ ]
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
        # Selects conditions to load.
        #
        
        def where(*args)
            @where += args
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
                else
                    fields = @fields.map { |i| __fix_field(i) } 
                    hashes = fields.reject { |i| not i.kind_of? Hash }
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
                wheres.each { |i| query.where(i) }
                
                # Ordering settings
                self._process_ordering(query)
                
                if not @limit.nil?
                    query.limit(@limit)
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
                            if i.kind_of? Array
                                query.orderBy("[" << i.first.to_s << "." << i.last.to_s << "]")
                            else
                                query.orderBy(__fix_field(i, true))
                            end
                    end
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
            if name.kind_of? Hash
                result = { }
                
                name.each_pair do |k, v|
                    result[self.fix_field(k, table, formatted)] = v
                end
            else
                result = table.to_s << "." << name.to_s 
            
                if formatted
                    result.replace("[" << result << "]")
                end
            end
            
            return result
        end
        
        ##
        # Fixes where specification(s) if it's hash with symbol key.
        #
        
        protected
        def _fix_where
            self.class::fix_where(@where) do |i|
                __fix_field(i)
            end
        end
        
        ##
        # Fixes where specification(s) if it's hash with symbol key.
        # Block is fixer.
        #
        
        def self.fix_where(where, &block)
            where.map do |specification|
                if specification.kind_of? Hash
                    new = { }
                    
                    specification.each_pair do |k, v|
                        if k.kind_of? Symbol
                            new[block.call(k)] = v
                        else
                            new[k] = v
                        end
                    end
                else
                    new = specification
                end
                
                new  # returns
            end
        end
        
        end
end