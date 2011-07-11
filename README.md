Native Query
============

**Native Query** is cool way how to speak with database server. It's 
ellegant and very ruby SQL query helper which works by similar way as 
Arel or another ORM selecting logic. It's derived from [Dibi][1] 
database layer in its ideas, so is much more simple and (of sure) much 
more KISS, readable and straightforward.

It's build on top of the general [Fluent Query][2] library which servers as 
underlying layer, so can be extended to almost whatever &ndash; and not-only 
database &ndash; platform.

### Connecting

    # Include it!
    require "fluent-query/mysql"
    require "native-query"
    
    # Setup it!
    driver = FluentQuery::Drivers::MySQL
    settings = {
        :username => "wikistatistics.net",
        :password => "alfabeta",
        :server => "localhost",
        :port => 5432,
        :database => "wikistatistics.net",
        :schema => "public"
    }
    
    # Create it!
    model = NativeQuery::Model::new(driver, settings)

Now we have model prepared for use.

### Selecting

Simply call method accroding to table name above the model. Its 
arguments will be fields which you would like to select:

    records = model.maintainers :name, :code do
        ...
        get.all
    end
    
The last command in the block is getter. You can take `all` records, 
`one` record only or `single` (first) value of first row. `assoc` method
is described below.

Traversing through returned records is simple of sure:

    records.each do |row|
        p row.code, row.name
    end
    
#### Associative Fetching

Special associative method is the `assoc` one which is directly inspired
by appropriate feature of the [Dibi][1] layer. It's aim is automatic
aggregation of returned rows to multidimensional Hashes.

Simply give it key names from your dataset. Be warn, only one or two 
levels (e.g. dimesions in resultant Hash) are supported:

    records = model.sites :maintainer_id, :language, :name do
        # ...
        get.assoc :maintainer_id, :language
    end
    
Will transform the dataset:

    # maintainer_id, language, name
    [1, "en", "English Wikipedia"],
    [1, "es", "Spain Wikipedia"],
    [2, "cs", "Czech Wikihow"],
    [2, "ja", "Japan Wikihow"],

To the following structure:

        1 => {
            "en" => "English Wikipedia",
            "es" => "Spain Wikipedia"
        },
        
        2 => {
            "cs" => "Czech Wikihow",
            "ja" => "Japan Wikihow"
        }

### Conditions, ordering and limits

Limits and offsets are simple too:

    records = model.maintainers :name, :code do
        # ...
        offset 5
        limit 3
        # ...
    end
  
Will select sixth, seventh and eighth record.
  
#### Conditions

Conditions (`WHERE` equivalent) receives Ruby's native data types. So 
simply call:

    records = model.maintainers :name, :code do
        where :active => true
        where :id => 5
        # ...
    end
    
These confitions are simple and `AND` equivalency of sure. Because aim 
is to be simple and to don't complicate rather nice interface by giant 
stuff of sophisticated and complicated calls, you can provide whatever 
condition using FluentQuery strings:

    records = model.maintainers :name, :code do
        # ...    
        where "[id] > 5"
        where "[name] IN %%l", names
        where "%%or", :id => 10, :id => 12
        # ...
    end

Brackets always means "this identifer is a field name". See description 
of the [Fluent Query][2] below.

#### Ordering

Orders work by very predictable way. For example:

    records = model.maintainers :name, :code do
        # ...
        order :name, :desc
        order [:date, :id], :asc
        # ...
    end
    
Means "order by `name DESC` and then by `date, id ASC`". If you need
order by joined fields, simply replace symbol by array with table name
and field name as you can see in advanced example below.

### Joining

Two kinds of joining are available: *automatic* and *manual*. They have 
the same syntax principially, for manual joining is necessary to provide
more informations of sure.

#### Manual Joining

For manual joining simply type:

    records = model.maintainers :name, :code, :sites_code, :sites_name do
        # ...
        sites :code, :name, :language_name do
            direct :site_id => :id
            # ...
        end
        # ...
    end

Which means select from table `maintainers` and join it with 
table `sites` by N:1 (direct) relation. Yes, you can join directly by 
"calling the table" and treating its block as your primary table. It's 
ellegant and very readable. For next level of joining simply do the same 
in the inner block.

All fields selected from the joined table are prefixed by its name and 
it's necessary of sure to tell interpret you want return them, as you 
can see above. It's practical because you know about orgination of the 
field whenever further in your source code.

Slightly more complicated is M:N relation type which works in 
semiautomatic way only:

    records = model.maintainers :name, :code, :sites_code, :sites_name do
        # ...
        sites :code, :name, :language_name do
            indirect :sites_maintainers, :id => :id
            # ...
        end
        # ...
    end
    
Which means the same as:

    SELECT ... FROM `maintainers` 
        JOIN `sites_maintainers` ON `maintainers`.`id` = `sites_maintainers`.`maintainers_id`
        JOIN `sites` ON `sites_maintainers`.`sites_id` = `site`.`id`
        ...

Only `LEFT JOIN` is supported. For other joining types, use direct 
*Fluent Query* interface (see below). Special conditions in `ON` clausule
is possible to achieve simply by giving the *Fluent Query* string:

    records = model.maintainers :name, :code, :sites_code, :sites_name do
        # ...
        sites :code, :name, :language_name do
            indirect "[maintainers.id] = [sites_maintainers.strange_1]", "[sites_maintainers.strange_2] = [site.id]"
            # ...
        end
        # ...
    end

And the same for direct joining of sure.

#### Automatic joining 

Automatic joining is recommended joining way although it has some strict 
requirements for table and field names:

* primary keys are expected to be named `id`,
* foreign key fields are expected to be named `<target-table>_id`,
* M:N linking tables are expected to be named `<source-table>_<target-table>`.

But then you can use the following nice syntax for both *direct*:

    records = model.maintainers :name, :code, :sites_code, :sites_name do
        # ...
        sites :code, :name, :language_name do
            direct
            # ...
        end
        # ...
    end
    
Which will be transformed approximately (it's driver dependent) into:
  
    SELECT `name`, `code`, `sites`.`code`, `sites`.`name`
        FROM `maintainers`
        JOIN `sites` ON `maintainers`.`id` = `sites`.`maintainer_id`
        ...
        
Or *indirect*:

    records = model.maintainers :name, :code, :sites_code, :sites_name do
        # ...
        sites :code, :name, :language_name do
            indirect
            # ...
        end
        # ...
    end

Which will be transformed approximately (it's driver dependent) into:

    SELECT `name`, `code`, `sites`.`code` AS `sites_code`, `sites`.`name` AS `sites_name`
        FROM `maintainers`
        JOIN `maintainers_sites` ON `maintainers`.`id` = `maintainers_sites`.`maintainer_id`
        JOIN `sites` ON `maintainers_sites`.`site_id` = `site`.`id`
        ...
        
Should be noted, if you need *backward indirect* joining (so in opposite 
direction than in examples above), simply call `direct backward` or
`indirect backward`.
          
### Inserts, Updates and Deletes

Native Query doesn't support native inserting, updating and deleting, 
but provides bridge to appropriate Fluent Query methods. Some examples:

    model.insert(:maintainers, :name => "Wikimedia", :country => "United States")
    
    # Will be:
    #   INSERT INTO `maintainers` (`name`, `country`) VALUES ("Wikimedia", "United States")
    
    model.update(:maintainers).set(:country => "Czech Republic").where(:id => 10).limit(1)
    
    # Will be:
    #   UPDATE `maintainers` SET `country` = "Czech Republic" WHERE `id` = 10 LIMIT 1
    
    model.delete(:maintainers).where(:id => 10).limit(1)
    
    # Will be:
    #   DELETE FROM `maintainers` WHERE `id` = 10 LIMIT 1

#### Transactions

Transactions support is available manual:
    
* `model.begin`
* `model.commit`
* `model.rollback`

Or by automatic way:

    model.transaction do
        #...
    end
    
### Fluent Queries

The *Native Query* library is built on top of the [Fluent Query][2]
library which provides way how to fluently translate series of method 
calls to some query language (but typically SQL). Some example:

    model.select("[id], [name]").from("[maintainers]").orderBy("[code] ASC")
    
Will be rendered to:

    SELECT `id`, `name` FROM `maintainers` ORDER BY `code` ASC
    
It looks trivial, but for example call `model.heyReturnMeSomething("[yeah]")` 
will be transformed to:

    HEY RETURN ME SOMETHING `yeah`
    
Which gives big potential. Of sure, escaping, aggregation and chaining 
of chunks for example for `WHERE` directive or another is necessary. 
It's ensured by appropriate *language* (e.g. database) *driver*.

And what a more: order of tokens isn't mandatory, so with exception
of initial world (`SELECT`, `INSERT` etc.) you can add them according to
your needs.

#### Placeholders

Simple translation calls to queries isn't the only functionality. Very
helpful are also *placeholders*. They works principially by the same way
as `#printf` method, but are more suitable for use in queries and 
supports automatic quoting. Available are:

* `%%s` which quotes string,
* `%%i` which quotes integer,
* `%%b` which quotes boolean,
* `%%f` which quotes float,
* `%%d` which quotes date,
* `%%t` which quotes date-time,

And also three special:

* `%%sql` which quotes subquery (expects query object),
* `%%and` which joins input by `AND` operator (expects hash),
* `%%or` which joins input by `OR` operator (expects hash).

An example:

    model.select("[id], [name]") \
      .from("[maintainers]") \
      .where("[id] = %%i AND company = %%s", 5, "Wikia") \
      .where("[language] IN %%l", ["cz", "en"]) \
      .or \
      .where("[active] IS %%b", true)
      
Will be transformed to:
    
    SELECT `id`, `name` FROM `maintainers` 
        WHERE `id` = 5 
            AND `company` = "Wikia"
            AND `language` IN ("cz", "en")
            OR `active` IS TRUE
            
It's way how to write complex or special queries. But **direct values 
assigning is supported**, so for example:

    model.select(:id, :name) \
      .from(:maintainers) \
      .where(:id => 5, :company => "Wikia") \
      .where("[language] IN %%l", ["cz", "en"])   # %l will join items by commas
      .or \
      .where(:active => true)
      
Will give you expected result too and as you can see, it's much more 
readable, flexible, so preferred.    
    
#### Relation to Native Query

You can take Fluent Query object from the Native Query by:

    # Query it!
    query = model.maintainers :name, :code do
        where :active => true
        order :name, :asc
        limit 1
        get.query   # takes the Fluent Query object
    end
    
    query.execute!
    
And if necessary build it by `#build` method to string. Build method is
also available above Native Query object directly. To execute query or 
fetch data is possible through `#do(*args)` or `#execute(*args)`. Result
will be result object similar to Native Query's one.

### Examples

Simple example:

    # Query it!
    records = model.maintainers :name, :code do
        where :active => true
        order :name, :asc
        limit 1
        get.all
    end
    
Will be transformed to:
  
    SELECT `name`, `code` FROM `maintainers` 
        WHERE `active` IS TRUE
        ORDER BY `name` ASC
        LIMIT 1
    
Advanced automatic joining (advanced example):
    
    # here selects two fields from 'projects' table and two other fields from joined 'sites' table
    projects = model.projects :name, :code, :sites_code, :sites_name do
        sites :code, :name, :language_name do
            where :active => true
        end
        
        maintainers do                  # joins 'projects' table with table 'maintainers'
            indirect backward           # ...by indirect way, so M:N
            where :active => true   
            where :id => 10
        end

        where :active => true
        order :code, [:sites, :code]
        
        get.assoc(:code, :sites_code)
    end
    
Will be transformed to:

    SELECT `name`, `code`, `sites`.`code` AS `sites_code`, `sites`.`name` AS `sites_name` 
        FROM `projects`
        JOIN `sites` ON `projects`.`id` = `sites`.`project_id`
        JOIN `maintainers_projects` 
            ON `projects`.`id` = `maintainers_projects`.`project_id`
        JOIN `maintainers` 
            ON `maintainers`.`id` = `maintainers_projects`.`maintainer_id`
        WHERE `sites`.`active` IS TRUE
            AND `maintainers`.`active` IS TRUE
            AND `maintainers`.`id` = 10
            AND `active` IS TRUE
            ORDER BY `code`, `sites`.`code` ASC
  
    
Contributing
------------

1. Fork it.
2. Create a branch (`git checkout -b 20101220-my-change`).
3. Commit your changes (`git commit -am "Added something"`).
4. Push to the branch (`git push origin 20101220-my-change`).
5. Create an [Issue][3] with a link to your branch.
6. Enjoy a refreshing Diet Coke and wait.

Copyright
---------

Copyright &copy; 2010-2011 [Martin Kozák][4]. See `LICENSE.txt` for
further details.

[1]: http://dibiphp.com/
[2]: https://github.com/martinkozak/fluent-query
[3]: http://github.com/martinkozak/native-query/issues
[4]: http://www.martinkozak.net/
