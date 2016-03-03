# Generate DbContext class
Generate DbContext class for EntityFramework by analyzing the SQL table schema.

It will add the attributes (Key, StringLength, Required) on fields and add the navigation properties based on foreign key.

For more detail, please read this post: https://doxakis.com/2015/12/15/SQL-Script-DbContext/

## Customization:
- You can change the table suffix. (by default: it will be "Model")
- You can specify the DbSet suffix.
- You can specify the context name. (by default: it will use the database name)
- You can specify the namespace.

## Conventions:
Foreign key:
- Linked[table name] (one to many)
- [field name without "Id" term] (many to one)

## Limitations:
- Table primary key are: TableName + Id or Id
- Foreign key column end with Id or ID
- Many to 1 are the only supported relationship. (1 to 1 can be simulated with Many to 1)
- Most data type are supported.
- When there are at least two foreign keys from the same table pointing to the same table the generated navigation properties use a different naming convention.
	- It will be: Linked[table name]BasedOn[Foreign key: field name without "Id" term] instead of Linked[table name] because in c# there will be fields with the exact same name.

## Copyright and license
Code released under the MIT license.
