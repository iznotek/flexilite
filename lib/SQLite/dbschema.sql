

PRAGMA page_size = 8192;
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = 1;
PRAGMA encoding = 'UTF-8';
PRAGMA recursive_triggers = 1;

------------------------------------------------------------------------------------------
-- .generators
------------------------------------------------------------------------------------------
create table [.generators] (name TEXT primary key, seq integer) without rowid;

/* -- Sample of generating ID
  insert or replace into [.generators] (name, seq) select '.objects',
  coalesce((select seq from [.generators] where name = '.objects') , 0) + 1 ;
*/

------------------------------------------------------------------------------------------
-- .access_rules
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.access_rules] (
  [UserRoleID] GUID NOT NULL,
  [ItemType]   CHAR NOT NULL,
  [Access]     CHAR NOT NULL,
  [ItemID]     INT  NOT NULL,
  CONSTRAINT [sqlite_autoindex_AccessRules_1] PRIMARY KEY ([UserRoleID], [ItemType], [ItemID])
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS [idxAccessRulesByItemID] ON [.access_rules] ([ItemID]);

------------------------------------------------------------------------------------------
-- .change_log
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.change_log] (
  [ID]        INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
  [TimeStamp] DATETIME NOT NULL             DEFAULT (julianday('now')),
  [OldKey],
  [OldValue]  JSON1,

  -- Format for key and oldkey
  -- @classID-schemaID.objectID#propertyID[propertyIndex]
  -- Example: @23-134.188374#345[11]
  [KEY],
  [Value]     JSON1,

  -- TODO Implement function
  [ChangedBy] GUID              -- DEFAULT (GetCurrentUserID())
);

------------------------------------------------------------------------------------------
-- .schemas
------------------------------------------------------------------------------------------
create table if not exists [.schemas]
(
    [SchemaID] INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
    [PreviousSchemaID] integer null CONSTRAINT [fkSchemaToPrevSchemaID]
                                    REFERENCES [.schemas] ([SchemaID]) ON DELETE RESTRICT ON UPDATE RESTRICT,
[Data] JSON1 NOT NULL
);

-- Trigger
-- on update of Data - create copy of old schema if Data has changed
CREATE TRIGGER IF NOT EXISTS [trigSchemasAfterUpdate]
AFTER UPDATE
ON [.schemas]
FOR EACH ROW
WHEN old.[Data] <> new.[Data] and [old.PreviousSchemaID] is null
BEGIN
    insert into [.schemas] ([PreviousSchemaID], [Data]) values (new.[SchemaID], old.[Data]);

    -- Validate Properties for IDs
    select raise_error('Failed constraint: every property ID should match existing class ID')
        from (select key from json_each(new.Data, '$.properties') where atom is null
        and not exists (select ClassID from [.classes] where ClassID = [Key]));


      INSERT INTO [.change_log] ([KEY], [Value], [OldKey], [OldValue]) VALUES (
        printf('-%s', new.SchemaID),
        json_set('{}',
        "$.SchemaID", new.SchemaID,
        "$.PreviousSchemaID", new.PreviousSchemaID,
        "$.Data", new.Data
        ),

        printf('-%s', old.SchemaID),
        json_set('{}',
                "$.SchemaID", old.SchemaID,
                "$.PreviousSchemaID", old.PreviousSchemaID,
                "$.Data", old.Data
                )
      );
END;

CREATE TRIGGER IF NOT EXISTS [trigSchemasAfterUpdate]
AFTER INSERT
ON [.schemas]
FOR EACH ROW
BEGIN
    -- Validate Properties for IDs
    select raise_error('Failed constraint: every property ID should match existing class ID')
        from (select key from json_each(new.Data, '$.properties') where atom is null
        and not exists (select ClassID from [.classes] where ClassID = [Key]));

        -- Update change log
      INSERT INTO [.change_log] ([KEY], [Value]) VALUES (
        printf('-%s', new.SchemaID),
        json_set('{}',
        "$.SchemaID", new.SchemaID,
        "$.PreviousSchemaID", new.PreviousSchemaID,
        "$.Data", new.Data
        )
      );
END;

CREATE TRIGGER IF NOT EXISTS [trigSchemasAfterUpdate]
AFTER DELETE
ON [.schemas]
FOR EACH ROW
BEGIN
      INSERT INTO [.change_log] ([OldKey], [OldValue]) VALUES (
        printf('-%s', old.SchemaID),
        json_set('{}',
        "$.SchemaID", old.SchemaID,
        "$.PreviousSchemaID", old.PreviousSchemaID,
        "$.Data", old.Data
        )
      );
END;

------------------------------------------------------------------------------------------
-- .classes
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.classes] (
  [ClassID]           INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
  [ClassName]         TEXT(64) NOT NULL,
  [SchemaOutdated] BOOL NOT NULL DEFAULT 0,
  [CurrentSchemaID] INTEGER NOT NULL   CONSTRAINT [fkClassesCurrentSchemaID]
    REFERENCES [.schemas] ([SchemaID]) ON DELETE RESTRICT ON UPDATE RESTRICT,


    -- System class is used internally by the system and cannot be changed or deleted by end-user

  [SystemClass] BOOL     NOT NULL             DEFAULT 0,

-- Optional mappings for JSON property shortcuts and/or indexing
  [A] INTEGER NULL,
  [B] INTEGER NULL,
  [C] INTEGER NULL,
  [D] INTEGER NULL,
  [E] INTEGER NULL,
  [F] INTEGER NULL,
  [G] INTEGER NULL,
  [H] INTEGER NULL,
  [I] INTEGER NULL,
  [J] INTEGER NULL,

  -- Control bitmask for objects belonging to this class
  [ctloMask] INTEGER NOT NULL DEFAULT 0,
    [Properties] JSON1 NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS [idxClasses_byClassName] ON [.classes] ([ClassName]);

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterInsert]
AFTER INSERT
ON [.classes]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([KEY], [Value]) VALUES (
    printf('@%s', new.ClassID),
    json_set('{}',
             "$.ClassName" , new.ClassName,
             "$.SystemClass" , new.SystemClass,
             "$.SchemaOutdated" , new.SchemaOutdated,
             "$.CurrentSchemaID", new.CurrentSchemaID,
             "$.ctloMask" , new.ctloMask,

             CASE WHEN new.Properties IS NULL
               THEN NULL
             ELSE "$.Properties" END, new.Properties,

             CASE WHEN new.A IS NULL
               THEN NULL
             ELSE "$.A" END, new.A,

             CASE WHEN new.B IS NULL
               THEN NULL
             ELSE "$.B" END, new.B,

            CASE WHEN new.C IS NULL
            THEN NULL
            ELSE "$.C" END, new.C,

            CASE WHEN new.D IS NULL
            THEN NULL
            ELSE "$.D" END, new.D,

            CASE WHEN new.E IS NULL
            THEN NULL
            ELSE "$.E" END, new.E,

            CASE WHEN new.F IS NULL
            THEN NULL
            ELSE "$.F" END, new.F,

            CASE WHEN new.G IS NULL
            THEN NULL
            ELSE "$.G" END, new.G,

            CASE WHEN new.H IS NULL
            THEN NULL
            ELSE "$.H" END, new.H,

            CASE WHEN new.I IS NULL
            THEN NULL
            ELSE "$.I" END, new.I,

            CASE WHEN new.J IS NULL
            THEN NULL
            ELSE "$.J" END, new.J
    )
  );

  -- Update objects with shortcuts if needed
  update [.objects] set
        [ctlo] = new.[ctloMask],
        [A] = (select json_extract([Data], '$.properties.' || [new.A] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [B] = (select json_extract([Data], '$.properties.' || [new.B] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [C] = (select json_extract([Data], '$.properties.' || [new.C] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [D] = (select json_extract([Data], '$.properties.' || [new.D] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [E] = (select json_extract([Data], '$.properties.' || [new.E] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [F] = (select json_extract([Data], '$.properties.' || [new.F] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [G] = (select json_extract([Data], '$.properties.' || [new.G] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [H] = (select json_extract([Data], '$.properties.' || [new.H] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [I] = (select json_extract([Data], '$.properties.' || [new.I] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [J] = (select json_extract([Data], '$.properties.' || [new.J] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID])

        where [ClassID] = new.ClassID;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterUpdate]
AFTER UPDATE
ON [.classes]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue], [KEY], [Value])
    SELECT
      [OldKey],
      [OldValue],
      [KEY],
      [Value]
    FROM (
      SELECT
        '@' || CAST(nullif(old.ClassID, new.ClassID) AS TEXT)                             AS [OldKey],

        json_set('{}',
             "$.ClassName" , old.ClassName,
             "$.SystemClass" , old.SystemClass,
             "$.SchemaOutdated" , old.SchemaOutdated,
             "$.CurrentSchemaID", old.CurrentSchemaID,
             "$.ctloMask" , old.ctloMask,

             CASE WHEN old.Properties IS NULL
               THEN NULL
             ELSE "$.Properties" END, old.Properties,

             CASE WHEN old.A IS NULL
               THEN NULL
             ELSE "$.A" END, old.A,

             CASE WHEN old.B IS NULL
               THEN NULL
             ELSE "$.B" END, old.B,

            CASE WHEN old.C IS NULL
            THEN NULL
            ELSE "$.C" END, old.C,

            CASE WHEN old.D IS NULL
            THEN NULL
            ELSE "$.D" END, old.D,

            CASE WHEN old.E IS NULL
            THEN NULL
            ELSE "$.E" END, old.E,

            CASE WHEN old.F IS NULL
            THEN NULL
            ELSE "$.F" END, old.F,

            CASE WHEN old.G IS NULL
            THEN NULL
            ELSE "$.G" END, old.G,

            CASE WHEN old.H IS NULL
            THEN NULL
            ELSE "$.H" END, old.H,

            CASE WHEN old.I IS NULL
            THEN NULL
            ELSE "$.I" END, old.I,

            CASE WHEN old.J IS NULL
            THEN NULL
            ELSE "$.J" END, old.J
        ) AS [OldValue],

        '@' || CAST(new.ClassID AS TEXT)                                                  AS [KEY],


                json_set('{}',
             "$.ClassName" , new.ClassName,
             "$.SystemClass" , new.SystemClass,
             "$.SchemaOutdated" , new.SchemaOutdated,
             "$.CurrentSchemaID", new.CurrentSchemaID,
             "$.ctloMask" , new.ctloMask,

             CASE WHEN new.Properties IS NULL
               THEN NULL
             ELSE "$.Properties" END, new.Properties,

             CASE WHEN new.A IS NULL
               THEN NULL
             ELSE "$.A" END, new.A,

             CASE WHEN new.B IS NULL
               THEN NULL
             ELSE "$.B" END, new.B,

            CASE WHEN new.C IS NULL
            THEN NULL
            ELSE "$.C" END, new.C,

            CASE WHEN new.D IS NULL
            THEN NULL
            ELSE "$.D" END, new.D,

            CASE WHEN new.E IS NULL
            THEN NULL
            ELSE "$.E" END, new.E,

            CASE WHEN new.F IS NULL
            THEN NULL
            ELSE "$.F" END, new.F,

            CASE WHEN new.G IS NULL
            THEN NULL
            ELSE "$.G" END, new.G,

            CASE WHEN new.H IS NULL
            THEN NULL
            ELSE "$.H" END, new.H,

            CASE WHEN new.I IS NULL
            THEN NULL
            ELSE "$.I" END, new.I,

            CASE WHEN new.J IS NULL
            THEN NULL
            ELSE "$.J" END, new.J
        )
        AS [Value]
    )
    WHERE [OldValue] <> [Value] OR (nullif([OldKey], [KEY])) IS NOT NULL;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterUpdateOfctloMaskOrColumns]
AFTER UPDATE OF [ctloMask], [A], [B], [C], [D], [E], [F], [G], [H], [I], [J]
ON [.classes]
FOR EACH ROW
BEGIN
  -- Update objects with shortcuts if needed
  update [.objects] set
        [ctlo] = new.[ctloMask],
        [A] = (select json_extract([Data], '$.properties.' || [new.A] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [B] = (select json_extract([Data], '$.properties.' || [new.B] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [C] = (select json_extract([Data], '$.properties.' || [new.C] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [D] = (select json_extract([Data], '$.properties.' || [new.D] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [E] = (select json_extract([Data], '$.properties.' || [new.E] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [F] = (select json_extract([Data], '$.properties.' || [new.F] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [G] = (select json_extract([Data], '$.properties.' || [new.G] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [H] = (select json_extract([Data], '$.properties.' || [new.H] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [I] = (select json_extract([Data], '$.properties.' || [new.I] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID]),
        [J] = (select json_extract([Data], '$.properties.' || [new.J] || '.jsonPath')
            from [.schemas] s where s.[SchemaID] = [SchemaID])

        where [ClassID] = new.ClassID;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterDelete]
AFTER DELETE
ON [.classes]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue]) VALUES (
    printf('@%s', old.ClassID),

    json_set('{}',
              "$.ClassName" , old.ClassName,
              "$.SystemClass" , old.SystemClass,
              "$.SchemaOutdated" , old.SchemaOutdated,
              "$.CurrentSchemaID", old.CurrentSchemaID,
              "$.ctloMask" , old.ctloMask,

              CASE WHEN old.Properties IS NULL
                THEN NULL
              ELSE "$.Properties" END, old.Properties,

              CASE WHEN old.A IS NULL
                THEN NULL
              ELSE "$.A" END, old.A,

              CASE WHEN old.B IS NULL
                THEN NULL
              ELSE "$.B" END, old.B,

             CASE WHEN old.C IS NULL
             THEN NULL
             ELSE "$.C" END, old.C,

             CASE WHEN old.D IS NULL
             THEN NULL
             ELSE "$.D" END, old.D,

             CASE WHEN old.E IS NULL
             THEN NULL
             ELSE "$.E" END, old.E,

             CASE WHEN old.F IS NULL
             THEN NULL
             ELSE "$.F" END, old.F,

             CASE WHEN old.G IS NULL
             THEN NULL
             ELSE "$.G" END, old.G,

             CASE WHEN old.H IS NULL
             THEN NULL
             ELSE "$.H" END, old.H,

             CASE WHEN old.I IS NULL
             THEN NULL
             ELSE "$.I" END, old.I,

             CASE WHEN old.J IS NULL
             THEN NULL
             ELSE "$.J" END, old.J
    )
  );
END;


------------------------------------------------------------------------------------------
-- .full_text_data
------------------------------------------------------------------------------------------
CREATE VIRTUAL TABLE IF NOT EXISTS [.full_text_data] USING fts4 (

  [PropertyID],
  [ClassID],
  [ObjectID],
  [PropertyIndex],
  [Value],

  tokenize=unicode61
);

------------------------------------------------------------------------------------------
-- [.objects]
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.objects] (
  [ObjectID] INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  [ClassID]  INTEGER NOT NULL CONSTRAINT [fkObjectsClassIDToClasses]
    REFERENCES [.classes] ([ClassID]) ON DELETE CASCADE ON UPDATE CASCADE,
[SchemaID] INTEGER not null
-- TODO Need constraint?
CONSTRAINT [fkObjectsSchemaIDToClasses]
                                REFERENCES [.classes] ([ClassID]) ON DELETE RESTRICT ON UPDATE RESTRICT,

  /*
  This is bit mask which regulates index storage.
  Bit 0: this object is a WEAK object and must be auto deleted after last reference to this object gets deleted.
  Bits 1-16: columns A-P should be indexed for fast lookup. These bits are checked by partial indexes
  Bits 17-32: columns A-P should be indexed for full text search
  Bits 33-48: columns A-P should be treated as range values and indexed for range (spatial search) search
  Bit 49: DON'T track changes
  Bit 50: Schema is not validated. Normally, this bit is set when object was referenced in other object
  but it was not defined in the schema

  */
  [ctlo]     INTEGER,
  [A],
  [B],
  [C],
  [D],
  [E],
  [F],
  [G],
  [H],
  [I],
  [J],
 [Data] JSON1 NULL,

 -- If HostID is set, Data is treated as JSONPath in the HostID.Data JSON
 -- In this case, object is MAPPED to the host object
 [HostID] INTEGER NULL
);

CREATE INDEX IF NOT EXISTS [idxObjectsByClassID] ON [.objects] ([ClassID]);

CREATE INDEX IF NOT EXISTS [idxObjectsByHostID] ON [.objects] ([HostID]) where HostID is not null;

CREATE INDEX IF NOT EXISTS [idxObjectsByA] ON [.objects] ([ClassID], [A]) WHERE (ctlo AND (1 << 1)) <> 0 AND [A] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByB] ON [.objects] ([ClassID], [B]) WHERE (ctlo AND (1 << 2)) <> 0 AND [B] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByC] ON [.objects] ([ClassID], [C]) WHERE (ctlo AND (1 << 3)) <> 0 AND [C] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByD] ON [.objects] ([ClassID], [D]) WHERE (ctlo AND (1 << 4)) <> 0 AND [D] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByE] ON [.objects] ([ClassID], [E]) WHERE (ctlo AND (1 << 5)) <> 0 AND [E] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByF] ON [.objects] ([ClassID], [F]) WHERE (ctlo AND (1 << 6)) <> 0 AND [F] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByG] ON [.objects] ([ClassID], [G]) WHERE (ctlo AND (1 << 7)) <> 0 AND [G] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByH] ON [.objects] ([ClassID], [H]) WHERE (ctlo AND (1 << 8)) <> 0 AND [H] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByI] ON [.objects] ([ClassID], [I]) WHERE (ctlo AND (1 << 9)) <> 0 AND [I] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByJ] ON [.objects] ([ClassID], [J]) WHERE (ctlo AND (1 << 10)) <> 0 AND [J] IS NOT NULL;


CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterInsert]
AFTER INSERT
ON [.objects]
FOR EACH ROW
BEGIN
  -- TODO force ctlo. Will it work?
  UPDATE [.objects]
  SET ctlo = coalesce(new.ctlo, (SELECT [ctlo]
                                 FROM [.classes]
                                 WHERE [ClassID] = new.[ClassID]))
  WHERE ObjectID = new.[ObjectID];

  INSERT INTO [.change_log] ([KEY], [Value])
    SELECT
      printf('@%s.%s', new.[ClassID], new.[ObjectID]),
      json_set('{}',
      '$.SchemaID', new.SchemaID,
      '$.Data', new.Data,
     CASE WHEN new.HostID IS NULL THEN NULL ELSE '$.HostID' END, new.HostID,
        CASE WHEN new.A IS NULL THEN NULL ELSE '$.A' END, new.A,
        CASE WHEN new.B IS NULL THEN NULL ELSE '$.B' END, new.B,
        CASE WHEN new.C IS NULL THEN NULL ELSE '$.C' END, new.C,
        CASE WHEN new.D IS NULL THEN NULL ELSE '$.D' END, new.D,
        CASE WHEN new.E IS NULL THEN NULL ELSE '$.E' END, new.E,
        CASE WHEN new.F IS NULL THEN NULL ELSE '$.F' END, new.F,
        CASE WHEN new.G IS NULL THEN NULL ELSE '$.G' END, new.G,
        CASE WHEN new.H IS NULL THEN NULL ELSE '$.H' END, new.H,
        CASE WHEN new.I IS NULL THEN NULL ELSE '$.I' END, new.I,
        CASE WHEN new.J IS NULL THEN NULL ELSE '$.J' END, new.J,
        CASE WHEN new.ctlo IS NULL THEN NULL ELSE '$.ctlo' END, new.ctlo

   )
    WHERE new.[ctlo] IS NULL OR new.[ctlo] & (1 << 49);

  -- Full text and range data using INSTEAD OF triggers of dummy view
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'A', new.[A]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'B', new.[B]
    );

  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'C', new.[C]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'D', new.[D]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'E', new.[E]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'F', new.[F]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'G', new.[G]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'H', new.[H]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'I', new.[I]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'J', new.[J]
    );

END;

CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterUpdate]
AFTER UPDATE
ON [.objects]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue], [KEY], [Value])
    SELECT
      [OldKey],
      [OldValue],
      [KEY],
      [Value]
    FROM
      (SELECT
         '@' || CAST(nullif(old.ClassID, new.ClassID) AS TEXT) || '.' ||
         CAST(nullif(old.ObjectID, new.[ObjectID]) AS TEXT) AS [OldKey],

        json_set('{}',
        '$.SchemaID', new.SchemaID,
              '$.Data', new.Data,
             CASE WHEN new.HostID IS NULL THEN NULL ELSE '$.HostID' END, new.HostID,
          CASE WHEN nullif(new.A, old.A) IS NULL THEN NULL ELSE '$.A' END, new.A,
            CASE WHEN nullif(new.B, old.B) IS NULL THEN NULL ELSE '$.B' END, new.B,
          CASE WHEN nullif(new.C, old.C) IS NULL THEN NULL ELSE '$.C' END, new.C,
            CASE WHEN nullif(new.D, old.D) IS NULL THEN NULL ELSE '$.D' END, new.D,
          CASE WHEN nullif(new.E, old.E) IS NULL THEN NULL ELSE '$.E' END, new.E,
            CASE WHEN nullif(new.F, old.F) IS NULL THEN NULL ELSE '$.F' END, new.F,
          CASE WHEN nullif(new.G, old.G) IS NULL THEN NULL ELSE '$.G' END, new.G,
            CASE WHEN nullif(new.H, old.H) IS NULL THEN NULL ELSE '$.H' END, new.H,
          CASE WHEN nullif(new.I, old.I) IS NULL THEN NULL ELSE '$.I' END, new.I,
            CASE WHEN nullif(new.J, old.J) IS NULL THEN NULL ELSE '$.J' END, new.J,

          CASE WHEN nullif(new.ctlo, old.ctlo) IS NULL THEN NULL ELSE '$.ctlo' END, new.ctlo
         )                                                  AS [OldValue],
         printf('@%s.%s', new.[ClassID], new.[ObjectID])    AS [KEY],
         json_set('{}',
         CASE WHEN nullif(new.SchemaID, old.SchemaID) IS NULL THEN NULL ELSE '$.SchemaID' END, old.SchemaID,
               CASE WHEN nullif(new.Data, old.Data) IS NULL THEN NULL ELSE '$.Data' END, old.Data,
              CASE WHEN nullif(new.HostID, old.HostID) IS NULL THEN NULL ELSE '$.HostID' END, old.HostID,
          CASE WHEN nullif(new.A, old.A) IS NULL THEN NULL ELSE '$.A' END, old.A,
            CASE WHEN nullif(new.B, old.B) IS NULL THEN NULL ELSE '$.B' END, old.B,
          CASE WHEN nullif(new.C, old.C) IS NULL THEN NULL ELSE '$.C' END, old.C,
            CASE WHEN nullif(new.D, old.D) IS NULL THEN NULL ELSE '$.D' END, old.D,
          CASE WHEN nullif(new.E, old.E) IS NULL THEN NULL ELSE '$.E' END, old.E,
            CASE WHEN nullif(new.F, old.F) IS NULL THEN NULL ELSE '$.F' END, old.F,
          CASE WHEN nullif(new.G, old.G) IS NULL THEN NULL ELSE '$.G' END, old.G,
            CASE WHEN nullif(new.H, old.H) IS NULL THEN NULL ELSE '$.H' END, old.H,
          CASE WHEN nullif(new.I, old.I) IS NULL THEN NULL ELSE '$.I' END, old.I,
            CASE WHEN nullif(new.J, old.J) IS NULL THEN NULL ELSE '$.J' END, old.J,

          CASE WHEN nullif(new.ctlo, old.ctlo) IS NULL THEN NULL ELSE '$.ctlo' END, old.ctlo
         )
                                                         AS [Value]
      )
    WHERE (new.[ctlo] IS NULL OR new.[ctlo] & (1 << 49))
          AND ([OldValue] <> [Value] OR (nullif([OldKey], [KEY])) IS NOT NULL);

  -- Update columns' full text and range data using dummy view with INSTEAD OF triggers
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'A', [oldValue] = old.[A],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'A', [Value] = new.[A],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'B', [oldValue] = old.[B],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'B', [Value] = new.[B],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'C', [oldValue] = old.[C],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'C', [Value] = new.[C],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'D', [oldValue] = old.[D],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'D', [Value] = new.[D],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'E', [oldValue] = old.[E],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'E', [Value] = new.[E],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'F', [oldValue] = old.[F],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'F', [Value] = new.[F],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'G', [oldValue] = old.[G],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'G', [Value] = new.[G],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'H', [oldValue] = old.[H],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'H', [Value] = new.[H],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'I', [oldValue] = old.[I],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'I', [Value] = new.[I],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'J', [oldValue] = old.[J],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'J', [Value] = new.[J],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];

END;

CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterUpdateOfClassID_ObjectID]
AFTER UPDATE OF [ClassID], [ObjectID]
ON [.objects]
FOR EACH ROW
BEGIN
  -- Force updating indexes for direct columns
  UPDATE [.objects]
  SET ctlo = new.ctlo
  WHERE ObjectID = new.[ObjectID];

  -- Cascade update values
  UPDATE [.ref-values]
  SET ObjectID = new.[ObjectID], ClassID = new.ClassID
  WHERE ObjectID = old.ObjectID
        AND (new.[ObjectID] <> old.ObjectID OR new.ClassID <> old.ClassID);

  -- and shifted values
  UPDATE [.ref-values]
  SET ObjectID = (1 << 62) | new.[ObjectID], ClassID = new.ClassID
  WHERE ObjectID = (1 << 62) | old.ObjectID
        AND (new.[ObjectID] <> old.ObjectID OR new.ClassID <> old.ClassID);

  -- Update back references
  UPDATE [.ref-values]
  SET [Value] = new.[ObjectID]
  WHERE [Value] = old.ObjectID AND ctlv IN (0, 10) AND new.[ObjectID] <> old.ObjectID;
END;

/*
CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterUpdateOfctlo]
AFTER UPDATE OF [ctlo]
ON [.objects]
FOR EACH ROW
BEGIN
-- A-P: delete from [.full_text_data]

-- A-P: insert into [.full_text_data]

-- A-P: delete from [.range_data]

-- A-P: insert into [.range_data]
END;
*/

CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterDelete]
AFTER DELETE
ON [.objects]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue])
    SELECT
      printf('@%s.%s', old.[ClassID], old.[ObjectID]),
      json_set('{}',
       CASE WHEN old.SchemaID IS NULL THEN NULL ELSE '$.SchemaID' END, old.SchemaID,
                     CASE WHEN old.Data IS NULL THEN NULL ELSE '$.Data' END, old.Data,
                    CASE WHEN old.HostID IS NULL THEN NULL ELSE '$.HostID' END, old.HostID,
        CASE WHEN old.A IS NULL THEN NULL ELSE '$.A' END, old.A,
          CASE WHEN old.B IS NULL THEN NULL ELSE '$.B' END, old.B,
        CASE WHEN old.C IS NULL THEN NULL ELSE '$.C' END, old.C,
          CASE WHEN old.D IS NULL THEN NULL ELSE '$.D' END, old.D,
        CASE WHEN old.E IS NULL THEN NULL ELSE '$.E' END, old.E,
          CASE WHEN old.F IS NULL THEN NULL ELSE '$.F' END, old.F,
        CASE WHEN old.G IS NULL THEN NULL ELSE '$.G' END, old.G,
          CASE WHEN old.H IS NULL THEN NULL ELSE '$.H' END, old.H,
        CASE WHEN old.I IS NULL THEN NULL ELSE '$.I' END, old.I,
          CASE WHEN old.J IS NULL THEN NULL ELSE '$.J' END, old.J,

        CASE WHEN old.ctlo IS NULL THEN NULL ELSE '$.ctlo' END, old.ctlo
      )

    WHERE old.[ctlo] IS NULL OR old.[ctlo] & (1 << 49);

  -- Delete all objects that are referenced from this object and marked for cascade delete (ctlv = 10)
  DELETE FROM [.objects]
  WHERE ObjectID IN (SELECT Value
                     FROM [.ref-values]
                     WHERE ObjectID IN (old.ObjectID, (1 << 62) | old.ObjectID) AND ctlv = 10);

  -- Delete all reversed references
  DELETE FROM [.ref-values]
  WHERE [Value] = ObjectID AND [ctlv] IN (0, 10);

  -- Delete all Values
  DELETE FROM [.ref-values]
  WHERE ObjectID IN (old.ObjectID, (1 << 62) | old.ObjectID);

  -- Delete full text and range data using dummy view with INSTEAD OF triggers
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'A';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'B';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'C';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'D';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'E';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'F';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'G';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'H';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'I';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'J';

END;

------------------------------------------------------------------------------------------
-- .vw_object_column_data
------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS [.vw_object_column_data]
AS
  SELECT
    NULL AS [oldClassID],
    NULL AS [oldObjectID],
    NULL AS [oldctlo],
    NULL AS [oldValue],
    NULL AS [ClassID],
    NULL AS [ObjectID],
    NULL AS [ctlo],
    NULL AS [ColumnAssigned],
    NULL AS [Value];

CREATE TRIGGER IF NOT EXISTS [trigDummyObjectColumnDataInsert]
INSTEAD OF INSERT ON [.vw_object_column_data]
FOR EACH ROW
BEGIN
  INSERT INTO [.full_text_data] ([PropertyID], [ClassID], [ObjectID], [PropertyIndex], [Value])
    SELECT
      printf('#%s#', new.[ColumnAssigned]),
      printf('#%s#', new.[ClassID]),
      printf('#%s#', new.[ObjectID]),
      '#0#',
      new.[Value]
    WHERE new.[ColumnAssigned] IS NOT NULL AND new.ctlo & (1 << (17 + unicode(new.[ColumnAssigned]) - unicode('A'))) AND
          typeof(new.[Value]) = 'text';
END;

CREATE TRIGGER IF NOT EXISTS [trigDummyObjectColumnDataUpdate]
INSTEAD OF UPDATE ON [.vw_object_column_data]
FOR EACH ROW
BEGIN
  -- Process full text data based on ctlo
  DELETE FROM [.full_text_data]
  WHERE
    new.[ColumnAssigned] IS NOT NULL AND
    new.oldctlo & (1 << (17 + unicode(new.[ColumnAssigned]) - unicode('A'))) AND typeof(new.[oldValue]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', new.[ColumnAssigned])
    AND [ClassID] MATCH printf('#%s#', new.[oldClassID])
    AND [ObjectID] MATCH printf('#%s#', new.[oldObjectID])
    AND [PropertyIndex] MATCH '#0#';

  INSERT INTO [.full_text_data] ([PropertyID], [ClassID], [ObjectID], [PropertyIndex], [Value])
    SELECT
      printf('#%s#', new.[ColumnAssigned]),
      printf('#%s#', new.[ClassID]),
      printf('#%s#', new.[ObjectID]),
      '#0#',
      new.[Value]
    WHERE new.[ColumnAssigned] IS NOT NULL AND new.ctlo & (1 << (17 + unicode(new.[ColumnAssigned]) - unicode('A'))) AND
          typeof(new.[Value]) = 'text';
END;

CREATE TRIGGER IF NOT EXISTS [trigDummyObjectColumnDataDelete]
INSTEAD OF DELETE ON [.vw_object_column_data]
FOR EACH ROW
BEGIN
  -- Process full text data based on ctlo
  DELETE FROM [.full_text_data]
  WHERE
    old.[ColumnAssigned] IS NOT NULL AND
    old.oldctlo & (1 << (17 + unicode(old.[ColumnAssigned]) - unicode('A'))) AND typeof(old.[oldValue]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', old.[ColumnAssigned])
    AND [ClassID] MATCH printf('#%s#', old.[oldClassID])
    AND [ObjectID] MATCH printf('#%s#', old.[oldObjectID])
    AND [PropertyIndex] MATCH '#0#';
END;


------------------------------------------------------------------------------------------
-- .range_data
------------------------------------------------------------------------------------------
CREATE VIRTUAL TABLE IF NOT EXISTS [.range_data] USING rtree (
  [id],
  [ClassID0], [ClassID1],
  [ObjectID0], [ObjectID1],
  [PropertyID0], [PropertyID1],
  [PropertyIndex0], [PropertyIndex1],
  [StartValue], [EndValue]
);

------------------------------------------------------------------------------------------
-- Values
-- This table stores EAV individual values in a canonical form - one DB row per value
-- Also, this table keeps list of object-to-object references. Direct reference is ObjectID.PropertyID -> Value
-- where Value is ID of referenced object.
-- Reversed reference is from Value -> ObjectID.PropertyID
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.ref-values] (
  [ObjectID]   INTEGER NOT NULL,
  [PropertyID] INTEGER NOT NULL,
  [PropIndex]  INTEGER NOT NULL DEFAULT 0,
  [Value]              NOT NULL,
  [ClassID]    INTEGER NOT NULL,

  /*
  ctlv is used for index control. Possible values (the same as [.class_properties].ctlv):
      0 - Index
      1-3 - reference
          2(3 as bit 0 is set) - regular ref
          4(5) - ref: A -> B. When A deleted, delete B
          6(7) - when B deleted, delete A
          8(9) - when A or B deleted, delete counterpart
          10(11) - cannot delete A until this reference exists
          12(13) - cannot delete B until this reference exists
          14(15) - cannot delete A nor B until this reference exist

      16 - full text data
      32 - range data
      64 - DON'T track changes
  */
  [ctlv]       INTEGER,
  CONSTRAINT [] PRIMARY KEY ([ObjectID], [ClassID], [PropertyID], [PropIndex])
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS [idxClassReversedRefs] ON [.ref-values] ([Value], [PropertyID]) WHERE [ctlv] & 14;

CREATE INDEX IF NOT EXISTS [idxValuesByClassPropValue] ON [.ref-values] ([PropertyID], [ClassID], [Value]) WHERE ([ctlv] & 1);

CREATE TRIGGER IF NOT EXISTS [trigValuesAfterInsert]
AFTER INSERT
ON [.ref-values]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([KEY], [Value])
    SELECT
      printf('@%s.%s/%s[%s]#%s',
             new.[ClassID], new.[ObjectID], new.[PropertyID], new.PropIndex,
             new.ctlv),
      new.[Value]
    WHERE (new.[ctlv] & 64) <> 64;

  INSERT INTO [.full_text_data] ([PropertyID], [ClassID], [ObjectID], [PropertyIndex], [Value])
    SELECT
      printf('#%s#', new.[PropertyID]),
      printf('#%s#', new.[ClassID]),
      printf('#%s#', new.[ObjectID]),
      printf('#%s#', new.[PropIndex]),
      new.[Value]
    WHERE new.ctlv & 16 AND typeof(new.[Value]) = 'text';

  -- process range data
END;

CREATE TRIGGER IF NOT EXISTS [trigValuesAfterUpdate]
AFTER UPDATE
ON [.ref-values]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue], [KEY], [Value])
    SELECT
      [OldKey],
      [OldValue],
      [KEY],
      [Value]
    FROM
      (SELECT
         /* Each piece of old key is formatted independently so that for cases when old and new value is the same,
         result will be null and will be placed to OldKey as empty string */
         printf('%s%s%s%s%s',
                '@' || CAST(nullif(old.[ClassID], new.[ClassID]) AS TEXT),
                '.' || CAST(nullif(old.[ObjectID], new.[ObjectID]) AS TEXT),
                '/' || CAST(nullif(old.[PropertyID], new.[PropertyID]) AS TEXT),
                '[' || CAST(nullif(old.[PropIndex], new.[PropIndex]) AS TEXT) || ']',
                '#' || CAST(nullif(old.[ctlv], new.[ctlv]) AS TEXT)
         )                                                         AS [OldKey],
         old.[Value]                                               AS [OldValue],
         printf('@%s.%s/%s[%s]%s',
                new.[ClassID], new.[ObjectID], new.[PropertyID], new.PropIndex,
                '#' || CAST(nullif(new.ctlv, old.[ctlv]) AS TEXT)) AS [KEY],
         new.[Value]                                               AS [Value])
    WHERE (new.[ctlv] & 64) <> 64 AND ([OldValue] <> [Value] OR (nullif([OldKey], [KEY])) IS NOT NULL);

  -- Process full text data based on ctlv
  DELETE FROM [.full_text_data]
  WHERE
    old.ctlv & 16 AND typeof(old.[Value]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', old.[PropertyID])
    AND [ClassID] MATCH printf('#%s#', old.[ClassID])
    AND [ObjectID] MATCH printf('#%s#', old.[ObjectID])
    AND [PropertyIndex] MATCH printf('#%s#', old.[PropIndex]);

  INSERT INTO [.full_text_data] ([PropertyID], [ClassID], [ObjectID], [PropertyIndex], [Value])
    SELECT
      printf('#%s#', new.[PropertyID]),
      printf('#%s#', new.[ClassID]),
      printf('#%s#', new.[ObjectID]),
      printf('#%s#', new.[PropIndex]),
      new.[Value]
    WHERE new.ctlv & 16 AND typeof(new.[Value]) = 'text';

  -- Process range data based on ctlv

END;

CREATE TRIGGER IF NOT EXISTS [trigValuesAfterDelete]
AFTER DELETE
ON [.ref-values]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue])
    SELECT
      printf('@%s.%s/%s[%s]',
             old.[ClassID], old.[ObjectID], old.[PropertyID],
             old.PropIndex),
      old.[Value]
    WHERE (old.[ctlv] & 64) <> 64;

  -- Delete weak referenced object in case this Value record was last reference to that object
  DELETE FROM [.objects]
  WHERE old.ctlv IN (3) AND ObjectID = old.Value AND
        (ctlo & 1) = 1 AND (SELECT count(*)
                            FROM [.ref-values]
                            WHERE [Value] = ObjectID AND ctlv IN (3)) = 0;

  -- Process full text data based on ctlv
  DELETE FROM [.full_text_data]
  WHERE
    old.[ctlv] & 16 AND typeof(old.[Value]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', old.[PropertyID])
    AND [ClassID] MATCH printf('#%s#', old.[ClassID])
    AND [ObjectID] MATCH printf('#%s#', old.[ObjectID])
    AND [PropertyIndex] MATCH printf('#%s#', old.[PropIndex]);

  -- TODO Process range data based on ctlv
END;

--------------------------------------------------------------------------------------------
-- .ValuesEasy
--------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS [.ValuesEasy] AS
  SELECT
    NULL AS [ClassName],
    NULL AS [HostID],
    NULL AS [ObjectID],
    NULL AS [PropertyName],
    NULL AS [PropertyIndex],
    NULL AS [Value];

CREATE TRIGGER IF NOT EXISTS trigValuesEasy_Insert INSTEAD OF INSERT
ON [.ValuesEasy]
FOR EACH ROW
BEGIN
  INSERT OR REPLACE INTO [.objects] (ClassID, ObjectID, ctlo, A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P)
    SELECT
      c.ClassID,
      (new.HostID << 31) | new.[ObjectID],

      ctlo = c.ctloMask,

      A = (CASE WHEN p.[ColumnAssigned] = 'A'
        THEN new.[Value]
           ELSE A END),

      B = (CASE WHEN p.[ColumnAssigned] = 'B'
        THEN new.[Value]
           ELSE B END),

      C = (CASE WHEN p.[ColumnAssigned] = 'C'
        THEN new.[Value]
           ELSE C END),

      D = (CASE WHEN p.[ColumnAssigned] = 'D'
        THEN new.[Value]
           ELSE D END),

      E = (CASE WHEN p.[ColumnAssigned] = 'E'
        THEN new.[Value]
           ELSE E END),

      F = (CASE WHEN p.[ColumnAssigned] = 'F'
        THEN new.[Value]
           ELSE F END),

      G = (CASE WHEN p.[ColumnAssigned] = 'G'
        THEN new.[Value]
           ELSE G END),

      H = (CASE WHEN p.[ColumnAssigned] = 'H'
        THEN new.[Value]
           ELSE H END),

      I = (CASE WHEN p.[ColumnAssigned] = 'I'
        THEN new.[Value]
           ELSE I END),

      J = (CASE WHEN p.[ColumnAssigned] = 'J'
        THEN new.[Value]
           ELSE J END)

    FROM [.classes] c, [.vw_class_properties] p
    WHERE c.[ClassID] = p.[ClassID] AND c.ClassName = new.ClassName AND p.PropertyName = new.PropertyName
          AND (p.[ctlv] & 14) = 0 AND p.ColumnAssigned IS NOT NULL AND new.PropertyIndex = 0;

  INSERT OR REPLACE INTO [.ref-values] (ObjectID, ClassID, PropertyID, PropIndex, [Value], ctlv)
    SELECT
      CASE WHEN new.PropertyIndex > 20
        THEN new.[ObjectID] | (1 << 62)
      ELSE new.[ObjectID] END,
      c.ClassID,
      p.PropertyID,
      new.PropertyIndex,
      new.[Value],
      p.[ctlv]
    FROM [.classes] c, [.vw_class_properties] p
    WHERE c.[ClassID] = p.[ClassID] AND c.ClassName = new.ClassName AND p.PropertyName = new.PropertyName AND
          p.ColumnAssigned IS NULL;
END;

--------------------------------------------------------------------------------------------
-- .values_view - wraps access to .values table by providing separate HostID and ObjectID columns
--------------------------------------------------------------------------------------------
create view if not exists [.ref-values_view] as
select ClassID, [ObjectID] >> 31 as HostID,
                    ([ObjectID] & 2147483647) as ObjectID, ctlv, PropertyID, PropIndex, [Value]
from [.ref-values];

create trigger if not exists values_view_Insert instead of insert on [.ref-values_view]
for each row
begin
    insert into [.ref-values]
    (
    ClassID, [ObjectID], ctlv, PropertyID, PropIndex, [Value]
    )
    values (
    new.ClassID, new.[ObjectID] << 31 | (new.[ObjectID] & 2147483647), new.ctlv,
    new.PropertyID, new.PropIndex, new.[Value]
    );
end;

create trigger if not exists values_view_Update instead of update on [.ref-values_view]
for each row
begin
    update [.ref-values] set
    ClassID = new.ClassID,
     [ObjectID] = new.[ObjectID] << 31 | (new.[ObjectID] & 2147483647),
     ctlv = new.ctlv,
    PropertyID = new.PropertyID, PropIndex = new.PropIndex, [Value] = new.[Value]
    where [ObjectID] = old.[ObjectID] << 31 | (old.[ObjectID] & 2147483647)
    and [PropertyID] = old.[PropertyID] and [PropIndex] = old.[PropIndex];
end;

create trigger if not exists values_view_Delete instead of delete on [.ref-values_view]
for each row
begin
    delete from [.ref-values]
   where [ObjectID] = old.[ObjectID] << 31 | (old.[ObjectID] & 2147483647)
       and [PropertyID] = old.[PropertyID] and [PropIndex] = old.[PropIndex];
end;

--------------------------------------------------------------------------------------------
-- .vw_objects - Access to objects data, with handling JSONPath & HostID cases
--------------------------------------------------------------------------------------------
create view if not exists [.vw_objects] as select
[ObjectID],
[SchemaID],
[HostID],
[ClassID],
[ctlo],
[A],
[B],
[C],
[D],
[E],
[F],
[G],
[H],
[I],
[J],
[Data] = (case when HostID is null then [Data] else (select h.[Data] from [.vw_objects] h where h.ObjectID = HostID limit 1) end)

from [.objects];

--------------------------------------------------------------------------------------------
-- .vw_objects_full - Access to full objects data, with handling JSONPath & HostID cases
-- AND shortcut fields
--------------------------------------------------------------------------------------------
create view if not exists [.vw_objects] as select
o.[ObjectID],
o.[SchemaID],
o.[HostID],
o.[ClassID],
o.[ctlo],
[Data] = json_set(o.Data,
case when o.A is null or c.A is null then null else json_extract( s.Data, '$.properties.' || c.A || '.jsonPath') end, o.A,
case when o.B is null or c.B is null then null else json_extract( s.Data, '$.properties.' || c.B || '.jsonPath') end, o.B,
case when o.C is null or c.C is null then null else json_extract( s.Data, '$.properties.' || c.C || '.jsonPath') end, o.C,
case when o.D is null or c.D is null then null else json_extract( s.Data, '$.properties.' || c.D || '.jsonPath') end, o.D,
case when o.E is null or c.E is null then null else json_extract( s.Data, '$.properties.' || c.E || '.jsonPath') end, o.E,
case when o.F is null or c.F is null then null else json_extract( s.Data, '$.properties.' || c.F || '.jsonPath') end, o.F,
case when o.G is null or c.G is null then null else json_extract( s.Data, '$.properties.' || c.G || '.jsonPath') end, o.G,
case when o.H is null or c.H is null then null else json_extract( s.Data, '$.properties.' || c.H || '.jsonPath') end, o.H,
case when o.I is null or c.I is null then null else json_extract( s.Data, '$.properties.' || c.I || '.jsonPath') end, o.I,
case when o.J is null or c.J is null then null else json_extract( s.Data, '$.properties.' || c.J || '.jsonPath') end, o.J
)
from [.vw_objects] o join [.schemas] s on o.SchemaID = s.SchemaID
join [.classes] c on o.ClassID = c.ClassID;


