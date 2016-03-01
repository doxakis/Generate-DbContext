# Generate DbContext class
Generate DbContext class for EntityFramework by analyzing the SQL table schema.

It will generate navigation properties based on foreign key.

For more detail, please read this post: https://doxakis.com/2015/12/15/SQL-Script-DbContext/

## Customization:
- You can change the table suffix.
- You can specify the context name. (by default it will use the database name)

## Limitations:
- Table primary key are: TableName + Id or Id
- Foreign key column end with Id or ID
- Many to 1 are the only supported relationship. (1 to 1 can be simulated with Many to 1)
- Most data type are supported.

## Possible improvements
- When there are at least two foreign keys from the same table pointing to the same table a conflict occurs because the script generate navigation properties and it doesn't handle the case. The generated class contains two fields named: "Linked" + table name.
  - I suggest to use: Linked[table name]BasedOn[Foreign key: field name without "Id" term]

## Copyright and license
Code released under the MIT license.
