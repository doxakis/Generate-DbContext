-- The MIT License (MIT)
-- 
-- Copyright (c) 2015 Philip Doxakis
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

/*
Script Name:
	Auto generate context
Author:
	Philip Doxakis
Customize:
	You can change the table suffix.
	You can specify the context name. (by default it will use the database name)
Description:
	Generate the DbContext class for entity framework.
	It will generate navigation properties based on foreign key.
Limitations:
	- Table primary key are: TableName + Id or Id
	- Foreign key column end with Id or ID
	- Many to 1 are the only supported relationship. (1 to 1 can be simulated with Many to 1)
	- Most data type are supported.
*/

-- Options:
DECLARE @tableSuffix VARCHAR(50) = 'Model' -- Ex: table Product -> class ProductModel
DECLARE @dbSetSuffix VARCHAR(50) = ''
DECLARE @ContextName VARCHAR(255) = ''
DECLARE @Namespace VARCHAR(255) = ''

-- Context name (By default: Database name if not specified)
-- Starting script:
IF LEN(@ContextName) = 0
    SELECT @ContextName = TABLE_CATALOG FROM INFORMATION_SCHEMA.COLUMNS

IF LEN(@Namespace) = 0
	SELECT @Namespace = @ContextName + '.Models'

-- Header.
PRINT 'using System;'
PRINT 'using System.Collections.Generic;'
PRINT 'using System.Linq;'
PRINT 'using System.Web;'
PRINT 'using System.Data.Entity;'
PRINT 'using System.ComponentModel.DataAnnotations;'
PRINT 'using System.ComponentModel.DataAnnotations.Schema;'
PRINT ''

-- Start generate namespace.
PRINT 'namespace ' + @Namespace
PRINT '{'

-- Start generate context class.
print '    public class ' + @ContextName + 'Context : DbContext {'
print '        public ' + @ContextName + 'Context() : base("DefaultConnection") {}'
print ''

-- Add DbSet fields.
DECLARE @CountSameForeignKeyReference INT
DECLARE @TableName VARCHAR(255)
DECLARE MY_CURSOR_FOR_TABLE CURSOR 
  LOCAL STATIC READ_ONLY FORWARD_ONLY
FOR
SELECT DISTINCT TABLE_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE OBJECTPROPERTY(OBJECT_ID(TABLE_CATALOG + '.' + TABLE_SCHEMA + '.' + TABLE_NAME), 'IsView') = 0
OPEN MY_CURSOR_FOR_TABLE
FETCH NEXT FROM MY_CURSOR_FOR_TABLE INTO @TableName
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Ignore some tables
    If @TableName != 'sysdiagrams' AND
        @TableName != 'webpages_Membership' AND
        @TableName != 'webpages_OAuthMembership' AND
        @TableName != 'webpages_Roles' AND
        @TableName != 'webpages_UsersInRoles' AND
        --@TableName != 'UserProfile' AND
        LEFT(@TableName, 7) != 'aspnet_' AND
        @TableName != 'Audit' AND
        @TableName != 'VersionInfo' -- Used by FluentMigrator
    BEGIN
        -- Add DbSet for current table.
        PRINT '        public DbSet<' + REPLACE(@TableName, ' ', '') + @tableSuffix + '> ' + REPLACE(@TableName, ' ', '') + @dbSetSuffix + ' { get; set; }'
    END
    FETCH NEXT FROM MY_CURSOR_FOR_TABLE INTO @TableName
END
CLOSE MY_CURSOR_FOR_TABLE
DEALLOCATE MY_CURSOR_FOR_TABLE

-- Add links between tables
PRINT ''
PRINT '        protected override void OnModelCreating(DbModelBuilder modelBuilder)'
PRINT '        {'
PRINT '            base.OnModelCreating(modelBuilder);'
PRINT ''
PRINT '            // Navigation properties based on foreign keys'
DECLARE @ColumnName VARCHAR(255)
DECLARE @ReferenceTableName VARCHAR(255)
DECLARE @ReferenceColumnName VARCHAR(255)
DECLARE @isColumnNullable BIT
DECLARE MY_CURSOR_FOR_FOREIGN_KEY CURSOR 
  LOCAL STATIC READ_ONLY FORWARD_ONLY
FOR
	-- CTE to get the foreign key relationships
	WITH [ForeignKeyInfo]
	AS
	(
		SELECT
			OBJECT_NAME(f.parent_object_id) AS TableName,
			COL_NAME(fc.parent_object_id, fc.parent_column_id) AS ColumnName,
			OBJECT_NAME (f.referenced_object_id) AS ReferenceTableName,
			COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS ReferenceColumnName,
			(
				SELECT is_nullable
				FROM sys.columns
				WHERE object_id=object_id(OBJECT_NAME(f.parent_object_id))
					AND name = COL_NAME(fc.parent_object_id, fc.parent_column_id)) AS is_nullable
		FROM sys.foreign_keys AS f
		INNER JOIN sys.foreign_key_columns AS fc
		ON f.OBJECT_ID = fc.constraint_object_id
	),
	-- CTE to get the foreign key relationship and count the same foreign key reference
	[ForeignKeyCompleteInfo]
	AS
	(
		SELECT
			*,
			(
				SELECT
					COUNT(1)
				FROM [ForeignKeyInfo] i
				WHERE
					o.ReferenceTableName = i.ReferenceTableName AND
					o.ReferenceColumnName = i.ReferenceColumnName AND
					o.TableName = i.TableName
				GROUP BY ReferenceTableName, ReferenceColumnName
			) AS CountSameForeignKeyReference
		FROM [ForeignKeyInfo] o
	)
	SELECT * FROM [ForeignKeyCompleteInfo]
OPEN MY_CURSOR_FOR_FOREIGN_KEY
FETCH NEXT FROM MY_CURSOR_FOR_FOREIGN_KEY INTO @TableName, @ColumnName, @ReferenceTableName, @ReferenceColumnName, @isColumnNullable, @CountSameForeignKeyReference
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Ignore some tables
    If  @TableName != 'sysdiagrams' AND
		@TableName != 'webpages_Membership' AND
        @TableName != 'webpages_OAuthMembership' AND
        @TableName != 'webpages_Roles' AND
        @TableName != 'webpages_UsersInRoles' AND
        --@TableName != 'UserProfile' AND
        LEFT(@TableName, 7) != 'aspnet_' AND
        @TableName != 'VersionInfo' AND -- Used by FluentMigrator
        @ReferenceTableName != 'sysdiagrams' AND
		@ReferenceTableName != 'webpages_Membership' AND
        @ReferenceTableName != 'webpages_OAuthMembership' AND
        @ReferenceTableName != 'webpages_Roles' AND
        @ReferenceTableName != 'webpages_UsersInRoles' AND
        --@ReferenceTableName != 'UserProfile' AND
        LEFT(@ReferenceTableName, 7) != 'aspnet_' AND
        @ReferenceTableName != 'VersionInfo' -- Used by FluentMigrator
    BEGIN
        PRINT ''
		PRINT '            modelBuilder.Entity<' + REPLACE(@ReferenceTableName, ' ', '') + @tableSuffix + '>()'
		IF @CountSameForeignKeyReference = 1
			PRINT '                .HasMany(m => m.Linked' + REPLACE(@TableName, ' ', '') + ')'
		ELSE
			PRINT '                .HasMany(m => m.Linked' + REPLACE(@TableName, ' ', '') + 'BasedOn' + REPLACE(REPLACE(@ColumnName, 'ID', ''), 'Id', '') + ')'
		IF @isColumnNullable = 0
			PRINT '                .WithRequired(m => m.' + REPLACE(REPLACE(@ColumnName, 'ID', ''), 'Id', '') + ')'
		ELSE
			PRINT '                .WithOptional(m => m.' + REPLACE(REPLACE(@ColumnName, 'ID', ''), 'Id', '') + ')'
		PRINT '                .HasForeignKey(m => m.' + @ColumnName + ');'
    END
    FETCH NEXT FROM MY_CURSOR_FOR_FOREIGN_KEY INTO  @TableName, @ColumnName, @ReferenceTableName, @ReferenceColumnName, @isColumnNullable, @CountSameForeignKeyReference
END
CLOSE MY_CURSOR_FOR_FOREIGN_KEY
DEALLOCATE MY_CURSOR_FOR_FOREIGN_KEY
PRINT '        }'
PRINT '    }'
PRINT ''
-- End generate context class.

-- Start generate tables class.
DECLARE MY_CURSOR_FOR_TABLE CURSOR 
  LOCAL STATIC READ_ONLY FORWARD_ONLY
FOR
SELECT DISTINCT TABLE_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE OBJECTPROPERTY(OBJECT_ID(TABLE_CATALOG + '.' + TABLE_SCHEMA + '.' + TABLE_NAME), 'IsView') = 0
OPEN MY_CURSOR_FOR_TABLE
FETCH NEXT FROM MY_CURSOR_FOR_TABLE INTO @TableName
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Ignore some tables
    If @TableName != 'sysdiagrams' AND
        @TableName != 'webpages_Membership' AND
        @TableName != 'webpages_OAuthMembership' AND
        @TableName != 'webpages_Roles' AND
        @TableName != 'webpages_UsersInRoles' AND
        --@TableName != 'UserProfile' AND
        LEFT(@TableName, 7) != 'aspnet_' AND
        @TableName != 'Audit' AND
        @TableName != 'VersionInfo' -- Used by FluentMigrator
    BEGIN
        -- Start generate table class.
        print '    [Table("' + @TableName + '")]'
        print '    public partial class ' + REPLACE(@TableName, ' ', '') + @tableSuffix + ''
        PRINT '    {'
        
        -- Populate Fields.
        DECLARE @COLUMN_NAME VARCHAR(255); -- Column Name.
        DECLARE @DATA_TYPE VARCHAR(255); -- Data type.
        DECLARE @CHARACTER_MAXIMUM_LENGTH VARCHAR(255); -- Length.
        DECLARE @IS_NULLABLE VARCHAR(255); -- Can be null.
        DECLARE MY_CURSOR_FOR_FIELD CURSOR 
          LOCAL STATIC READ_ONLY FORWARD_ONLY
        FOR
        SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE table_name = @TableName
        ORDER BY ordinal_position
        OPEN MY_CURSOR_FOR_FIELD
        FETCH NEXT FROM MY_CURSOR_FOR_FIELD INTO
        	@COLUMN_NAME, @DATA_TYPE, @CHARACTER_MAXIMUM_LENGTH, @IS_NULLABLE
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- By convention: TableName + Id = Key.
            If @COLUMN_NAME = @TableName + 'Id'
                PRINT '        [Key]'
            If @COLUMN_NAME = 'Id'
                PRINT '        [Key]'
            
            -- DATA_TYPE = varchar or nvarchar = String
            If @DATA_TYPE = 'varchar' OR @DATA_TYPE = 'nvarchar' OR @DATA_TYPE = 'nchar' OR @DATA_TYPE = 'char'
            BEGIN
                -- Enter the max length.
                IF @CHARACTER_MAXIMUM_LENGTH <> -1
	                PRINT '        [StringLength(' + @CHARACTER_MAXIMUM_LENGTH + ')]'
                SET @DATA_TYPE = 'string'
            End
            
            IF @DATA_TYPE = 'uniqueidentifier'
				SET @DATA_TYPE = 'Guid'
            
            IF @DATA_TYPE = 'xml'
				SET @DATA_TYPE = 'string'
            
            IF @DATA_TYPE = 'tinyint'
				SET @DATA_TYPE = 'byte'
            
            IF @DATA_TYPE = 'bigint'
				SET @DATA_TYPE = 'long'
            
            IF @DATA_TYPE = 'smallint'
				SET @DATA_TYPE = 'Int16'
            
            IF @DATA_TYPE = 'time'
				SET @DATA_TYPE = 'TimeSpan'
            
            IF @DATA_TYPE = 'varbinary'
				SET @DATA_TYPE = 'byte[]'
            
            IF @DATA_TYPE = 'money'
				SET @DATA_TYPE = 'decimal'
            
            -- DATA_TYPE = Bit = bool
            If @DATA_TYPE = 'bit'
            BEGIN
                SET @DATA_TYPE = 'bool'
            End
            
            -- DATA_TYPE = date or datetime = DateTime
            If @DATA_TYPE = 'date'
            BEGIN
                SET @DATA_TYPE = 'DateTime'
            End
            If @DATA_TYPE = 'datetime'
            BEGIN
                SET @DATA_TYPE = 'DateTime'
            End
            
            -- If field can be null, add: ? (Ignore String)
            If @IS_NULLABLE = 'YES' AND @DATA_TYPE != 'string' AND @DATA_TYPE != 'byte[]'
                SET @DATA_TYPE = @DATA_TYPE + '?'
            
            -- Add the [Required] where non nullable field,
            -- not the primary key by convention.
            If @IS_NULLABLE = 'NO' AND NOT @COLUMN_NAME = @TableName + 'Id'
            		AND NOT @COLUMN_NAME = 'Id'
                PRINT '        [Required]'
            
            -- Add the field.
            print '        public ' + @DATA_TYPE + ' ' + @COLUMN_NAME + ' { get; set; }'
            print ''
            
            FETCH NEXT FROM MY_CURSOR_FOR_FIELD INTO
            	@COLUMN_NAME, @DATA_TYPE, @CHARACTER_MAXIMUM_LENGTH, @IS_NULLABLE
        END
        CLOSE MY_CURSOR_FOR_FIELD
        DEALLOCATE MY_CURSOR_FOR_FIELD
        
        -- Navigation properties
		DECLARE @TableName2 VARCHAR(255);
        DECLARE MY_CURSOR_FOR_FOREIGN_KEY CURSOR 
		  LOCAL STATIC READ_ONLY FORWARD_ONLY
		FOR
			-- CTE to get the foreign key relationships
			WITH [ForeignKeyInfo]
			AS
			(
				SELECT
					OBJECT_NAME(f.parent_object_id) AS TableName,
					COL_NAME(fc.parent_object_id, fc.parent_column_id) AS ColumnName,
					OBJECT_NAME (f.referenced_object_id) AS ReferenceTableName,
					COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS ReferenceColumnName,
					(
						SELECT is_nullable
						FROM sys.columns
						WHERE object_id=object_id(OBJECT_NAME(f.parent_object_id))
							AND name = COL_NAME(fc.parent_object_id, fc.parent_column_id)) AS is_nullable
				FROM sys.foreign_keys AS f
				INNER JOIN sys.foreign_key_columns AS fc
				ON f.OBJECT_ID = fc.constraint_object_id
			),
			-- CTE to get the foreign key relationship and count the same foreign key reference
			[ForeignKeyCompleteInfo]
			AS
			(
				SELECT
					*,
					(
						SELECT
							COUNT(1)
						FROM [ForeignKeyInfo] i
						WHERE
							o.ReferenceTableName = i.ReferenceTableName AND
							o.ReferenceColumnName = i.ReferenceColumnName AND
							o.TableName = i.TableName
						GROUP BY ReferenceTableName, ReferenceColumnName
					) AS CountSameForeignKeyReference
				FROM [ForeignKeyInfo] o
			)
			SELECT * FROM [ForeignKeyCompleteInfo]
		OPEN MY_CURSOR_FOR_FOREIGN_KEY
		FETCH NEXT FROM MY_CURSOR_FOR_FOREIGN_KEY INTO @TableName2, @ColumnName, @ReferenceTableName, @ReferenceColumnName, @isColumnNullable, @CountSameForeignKeyReference
		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Ignore some tables
			If  @TableName2 != 'sysdiagrams' AND
				@TableName2 != 'webpages_Membership' AND
				@TableName2 != 'webpages_OAuthMembership' AND
				@TableName2 != 'webpages_Roles' AND
				@TableName2 != 'webpages_UsersInRoles' AND
				--@TableName2 != 'UserProfile' AND
				LEFT(@TableName2, 7) != 'aspnet_' AND
				@TableName2 != 'VersionInfo' AND -- Used by FluentMigrator
				@ReferenceTableName != 'sysdiagrams' AND
				@ReferenceTableName != 'webpages_Membership' AND
				@ReferenceTableName != 'webpages_OAuthMembership' AND
				@ReferenceTableName != 'webpages_Roles' AND
				@ReferenceTableName != 'webpages_UsersInRoles' AND
				--@ReferenceTableName != 'UserProfile' AND
				LEFT(@ReferenceTableName, 7) != 'aspnet_' AND
				@ReferenceTableName != 'VersionInfo' -- Used by FluentMigrator
			BEGIN
				IF @ReferenceTableName = @TableName
				BEGIN
					IF @CountSameForeignKeyReference = 1
						PRINT '        public virtual ICollection<' + REPLACE(@TableName2, ' ', '') + @tableSuffix + '> Linked' + REPLACE(@TableName2, ' ', '') + ' { get; set; }'
					ELSE
						PRINT '        public virtual ICollection<' + REPLACE(@TableName2, ' ', '') + @tableSuffix + '> Linked' + REPLACE(@TableName2, ' ', '') + 'BasedOn' + REPLACE(REPLACE(@ColumnName, 'ID', ''), 'Id', '') + ' { get; set; }'
				END
	            IF @TableName2 = @TableName
		            PRINT '        public virtual ' + REPLACE(@ReferenceTableName, ' ', '') + @tableSuffix + ' ' + REPLACE(REPLACE(@ColumnName, 'ID', ''), 'Id', '') + ' { get; set; }'
			END
			FETCH NEXT FROM MY_CURSOR_FOR_FOREIGN_KEY INTO  @TableName2, @ColumnName, @ReferenceTableName, @ReferenceColumnName, @isColumnNullable, @CountSameForeignKeyReference
		END
		CLOSE MY_CURSOR_FOR_FOREIGN_KEY
		DEALLOCATE MY_CURSOR_FOR_FOREIGN_KEY
        
        print '    }'
        print ''
        -- End generate table class.
    END
    FETCH NEXT FROM MY_CURSOR_FOR_TABLE INTO @TableName
END
CLOSE MY_CURSOR_FOR_TABLE
DEALLOCATE MY_CURSOR_FOR_TABLE
-- End generate table class.

PRINT '}'
-- End generate namespace.