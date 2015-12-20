/**
 * Created by slanska on 2015-12-09.
 */

/// <reference path="../../typings/tsd.d.ts"/>


/*
 Defines contract for object data to be inserted or updated.
 */
interface IDataToSave
{
    /*
     Portion of object data which is defined by object's class ("schema" data)
     */
    SchemaData?:any;

    /*
     Portion of object data which is NOT defined by object's class ("non-schema" data)
     */
    ExtData?:any;
}

/*
Defines contract for basic EAV property dataß
 */
interface IEAVBase
{
    /*
     ID of object to be inserted/updated
     */
    objectID:number;

    /*
     Optional property ID corresponding to property name
     */
    propID?:number;

    /*
     Property index (for array of values). For scalar property, it is 0.
     */
    propIndex:number;

    /*
     Property value
     */
    value?: any;
}

/*
Defines contract for data to be saved in .values tableß
 */
interface IEAVItem extends IEAVBase
{
    classID: number;

    /*
     Flags
     */
    ctlv:VALUE_CONTROL_FLAGS;
}

/*
 Declares contract for saving individual property in .values or .objects (A-P columns) table
 */
interface IPropertyToSave extends IEAVBase
{
    /*
     ID of host object
     */
    hostID?: number;

    /*
     Class definition which hold this property.
     Property definition is accessible via classDef.Properties[propName]
     */
    classDef:IClass;

    /*
     Name of property
     */
    propName: string;
}

/*
 ctlv is used for indexing and processing control. Possible values (the same as Values.ctlv):
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
declare const enum VALUE_CONTROL_FLAGS
{
    NONE = 0,
    INDEX = 1,
    REFERENCE = 2,
    REFERENCE_OWN = 4,
    REFERENCE_OWN_REVERSE = 6,
    REFERENCE_OWN_MUTUAL = 8,
    REFERENCE_DEPENDENT_MASTER = 10,
    REFERENCE_DEPENDENT_LINK = 12,
    REFERENCE_DEPENDENT_BOTH = 14,
    FULL_TEXT_INDEX = 16,
    RANGE_INDEX = 32,
    NO_TRACK_CHANGES = 64
}


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

declare const enum OBJECT_CONTROL_FLAGS
{
    NONE = 0,
    WEAK_OBJECT = 1,
    NO_TRACK_CHANGES = 1 << 49,
    SCHEMA_NOT_ENFORCED = 1 << 50
}

interface IDropOptions
{
    table:string;
    properties:[any];
    one_associations:[any];
    many_associations:[any];
}

interface ISyncOptions extends IDropOptions
{
    extension:any;
    id:any;
    allProperties:[string, Flexilite.models.IPropertyDef];
    indexes:[any];
    customTypes:[any];
    extend_associations:[any];
}

// TODO Handle hasOne and extend association

interface IHasManyAssociation
{
}