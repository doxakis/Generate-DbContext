# Generate-DbContext
Generate DbContext for EntityFramework by analyzing the SQL table schema.
It will generate navigation properties based on foreign key.

## Customization:
- You can change the table suffix.
- You can specify the context name. (by default it will use the database name)

## Limitations:
- Table primary key are: TableName + Id or Id
- Foreign key column end with Id or ID
- Many to 1 are the only supported relationship. (1 to 1 can be simulated with Many to 1)
- Most data type are supported.

## Copyright and license
Code released under the MIT licence.
