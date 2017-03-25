//
// Created by slanska on 2016-04-28.
//

#include <sqlite3ext.h>
#include <assert.h>
#include "flexi_prop.h"
#include "flexi_db_ctx.h"
#include "../common/common.h"
#include "../misc/regexp.h"

int flexi_prop_create_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

int flexi_prop_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;

}

int flexi_prop_drop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;

}

int flexi_prop_rename_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;

}

/*
 * Allocates new instance of class prop definition
 * Sets class ID, ref count to 1 and status 'ADDED'
 */
struct flexi_PropDef_t *flexi_prop_def_new(sqlite3_int64 lClassID)
{
    struct flexi_PropDef_t *result = sqlite3_malloc(sizeof(struct flexi_PropDef_t));
    if (result)
    {
        memset(result, 0, sizeof(struct flexi_PropDef_t));
        result->lClassID = lClassID;
        result->nRefCount = 1;
        result->eChangeStatus = CHNG_STATUS_ADDED;
    }
    return result;
}

int flexi_prop_def_parse(struct flexi_PropDef_t *pProp, const char *zPropName, const char *zPropDefJson)
{
    assert(pProp && pProp->lClassID && pProp->pCtx);

    const char *zPropParseSQL = "select "
            "coalesce(json_extract(:1, '$.index'), 'none') as index," // 0
            "coalesce(json_extract(:1, '$.subType'), NULL) as subType," // 1
            "coalesce(json_extract(:1, '$.minOccurences'), 0) as minOccurrences," // 2
            "coalesce(json_extract(:1, '$.maxOccurences'), 1) as maxOccurrences," // 3
            "coalesce(json_extract(:1, '$.rules.type'), 'text') as type," // 4
            "coalesce(json_extract(:1, '$.noTrackChanges'), 0) as noTrackChanges," // 5
            "coalesce(json_extract(:1, '$.enumDef'), NULL) as enumDef," // 6
            "coalesce(json_extract(:1, '$.refDef'), NULL) as refDef," // 7
            "coalesce(json_extract(:1, '$.$renameTo'), NULL) as renameTo," // 8
            "coalesce(json_extract(:1, '$.$drop'), 0) as drop," // 9
            "coalesce(json_extract(:1, '$.rules.maxLength'), 0) as maxLength," // 10
            "coalesce(json_extract(:1, '$.rules.minValue'), 0) as minValue," // 11
            "coalesce(json_extract(:1, '$.rules.maxValue'), 0) as maxValue," // 12
            "coalesce(json_extract(:1, '$.rules.regex'), 0) as regex" // 13
            "coalesce(json_extract(:1, '$.enumDef.$id'), 0) as enumDef_id," // 14
            "coalesce(json_extract(:1, '$.enumDef.$name'), NULL) as enumDef_name," // 15
    ;
    int result;

    struct flexi_Context_t *pCtx = pProp->pCtx;
    if (!pCtx->pStmts[STMT_PROP_PARSE])
    {
        CHECK_CALL(sqlite3_prepare_v2(pCtx->db, zPropParseSQL, -1, &pCtx->pStmts[STMT_PROP_PARSE], NULL));
    }

    sqlite3_stmt *st = pCtx->pStmts[STMT_PROP_PARSE];

    CHECK_CALL(sqlite3_reset(st));
    CHECK_CALL(sqlite3_bind_text(st, 0, zPropParseSQL, -1, NULL));
    CHECK_STMT(sqlite3_step(st));
    if (result == SQLITE_DONE)
    {
        CHECK_CALL(getColumnAsText(&pProp->zIndex ,st, 0));
        CHECK_CALL(getColumnAsText(&pProp->zSubType ,st, 1));
        pProp->minOccurences = sqlite3_column_int(st, 2);
        pProp->maxOccurences = sqlite3_column_int(st, 3);
        CHECK_CALL(getColumnAsText(&pProp->zType ,st, 4));
        pProp->bNoTrackChanges = (bool) sqlite3_column_int(st, 5);
        CHECK_CALL(getColumnAsText(&pProp->zEnumDef ,st, 6));
        CHECK_CALL(getColumnAsText(&pProp->zRefDef ,st, 7));
        CHECK_CALL(getColumnAsText(&pProp->zRenameTo ,st, 8));
        if (sqlite3_column_int(st, 9) == 1)
            pProp->eChangeStatus = CHNG_STATUS_DELETED;
        pProp->maxLength = sqlite3_column_int(st, 10);
        pProp->minValue = sqlite3_column_int(st, 11);
        pProp->maxValue = sqlite3_column_int(st, 12);
        CHECK_CALL(getColumnAsText(&pProp->regex ,st, 13));

        // Check enumDef
        if (pProp->zEnumDef)
        {
            flexi_metadata_ref enumName;
            enumName.id = sqlite3_column_int64(st, 14);
            CHECK_CALL(getColumnAsText(&enumName.name ,st, 15));

            // Get items
        }

        // Check refDef
        if (pProp->zRefDef)
        {
            // classRef
            // dynamic
            // rules
            // reverseProperty
            // autoFetchLimit
            // autoFetchDepth
            // rule
        }
    }

    goto EXIT;
    ONERROR:
    EXIT:
    return result;
}

int flexi_prop_def_stringify(struct flexi_PropDef_t *pProp, char **pzPropDefJson)
{
    return 0;
}

int flexi_prop_def_get_changes_needed(struct flexi_PropDef_t *pOldDef,
                                      struct flexi_PropDef_t *pNewDef, int *piResult,
                                      const char **pzError)
{
    return 0;
}

int flexi_prop_to_ref_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;

}

int flexi_ref_to_prop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;

}

/*
 *
 */
void flexi_prop_def_free(struct flexi_PropDef_t *prop)
{
    assert(prop);

    if (--prop->nRefCount == 0)
    {
        sqlite3_value_free(prop->defaultValue);
        sqlite3_free(prop->name.name);

        sqlite3_free(prop->regex);
        if (prop->pRegexCompiled)
            re_free(prop->pRegexCompiled);

        flexi_ref_def_free(prop->pRefDef);
        flexi_enum_def_free(prop->pEnumDef);

        sqlite3_free(prop->zIndex);
        sqlite3_free(prop->zSubType);
        sqlite3_free(prop->zRenameTo);
    }
}

void flexi_ref_def_free(flexi_ref_def *p)
{
    if (p)
    {
        // TODO
        sqlite3_free(p);
    }
}

void flexi_enum_def_free(flexi_enum_def *p)
{
    if (p)
    {
        // TODO
        sqlite3_free(p);
    }

}