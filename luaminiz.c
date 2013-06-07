#include <ctype.h>
#include <lauxlib.h>
#include <lua.h>
#include <stdlib.h>
#include <string.h>
#include <miniz.h>

/*
 * ** compatibility with Lua 5.2
 * */
#if (LUA_VERSION_NUM == 502)
#undef luaL_register
#define luaL_register(L,n,f) \
               { if ((n) == NULL) luaL_setfuncs(L,f,0); else luaL_newlib(L,f); }

#endif

// static int lmz_inflate(lua_State *L);

static int lmz_inflate(lua_State *L) {
    
    size_t decomp_len;
    size_t comp_len;
    void *pDecomp_data;
    const char* pComp_data;
    
    comp_len = 0;
    pComp_data = luaL_checklstring(L, 1, &comp_len);

    pDecomp_data = tinfl_decompress_mem_to_heap(pComp_data, comp_len, &decomp_len, 0);
    
    lua_pop(L, 1);
    
    if (!pDecomp_data) {
        lua_pushnil(L);
        return 1;
    }
    
    lua_pushlstring(L, (char*)pDecomp_data, decomp_len);
    
    free(pDecomp_data);
    
    return 1;
}

static mz_zip_archive *checkzip(lua_State *L) {
      void *pZip = luaL_checkudata(L, 1, "lmz.zip_writer");
      luaL_argcheck(L, pZip != NULL, 1, "'zip_writer' expected");
      return (mz_zip_archive*)pZip;
}

static int lmz_new_zip_writer(lua_State *L) {

    const char *pZip_filename;
    mz_zip_archive *pZip;

    pZip_filename = luaL_checklstring(L, 1, NULL);

    lua_pop(L, 1);

    // размещаем в стеке указатель на структуру
    pZip = (mz_zip_archive*)lua_newuserdata(L, sizeof(mz_zip_archive));
    memset(pZip, 0, sizeof(mz_zip_archive));

    if (!mz_zip_writer_init_file(pZip, pZip_filename, 0)) {
        lua_pushnil(L);
        lua_pushstring(L, "Failed creating zip archive");
        return 2;
    }

    luaL_getmetatable(L, "lmz.zip_writer");
    lua_setmetatable(L, -2);

    return 1;  
}

static int lmz_zip_writer_write(lua_State *L) {

    const char *dpath;
    const char *data;
    size_t dsize;
    mz_zip_archive *pZip;
    mz_uint level;

    dsize = 0;

    // при вызове метода zip:write()
    // первым в стек помещается 'zip'
    pZip = checkzip(L);

    dpath = luaL_checklstring(L, 2, NULL);
    data  = luaL_checklstring(L, 3, &dsize);
    level = luaL_checkint(L, 4);

    lua_pop(L, 4);

    if (!mz_zip_writer_add_mem(pZip, dpath, data, dsize, level)) {
        mz_zip_writer_end(pZip);
        lua_pushnil(L);
        lua_pushstring(L, "Failed add to zip archive");
        return 2;
    }

    lua_pushboolean(L, 1);

    return 1;  
}

// финализатор архива
static int lmz_zip_writer_finalize(lua_State *L) {

    mz_zip_archive *pZip;

    // при вызове метода zip:finalize()
    // первым в стек помещается 'zip'
    pZip = checkzip(L);

    if (!mz_zip_writer_finalize_archive(pZip)) {
        mz_zip_writer_end(pZip);
        lua_pushnil(L);
        lua_pushstring(L, "Failed creating zip archive");
        return 2;
    }

    mz_zip_writer_end(pZip);

    lua_pop(L, 1);

    lua_pushboolean(L, 1);

    return 1;  
}

// функции библиотеки
static const luaL_Reg miniz_functions[] = {
    { "inflate", lmz_inflate },
    { "new_zip_writer", lmz_new_zip_writer },
    { NULL, NULL }
};

// методы zip_writer 
static const luaL_Reg miniz_zip_writer_methods[] = {
    { "write", lmz_zip_writer_write },
    { "finalize", lmz_zip_writer_finalize },
    { NULL, NULL }
};


LUALIB_API int luaopen_lmz(lua_State * const L) {

    // метатаблица для объекта zip_writer
    luaL_newmetatable(L, "lmz.zip_writer");
    lua_pushstring(L, "__index");
    lua_pushvalue(L, -2);  /* pushes the metatable */
    lua_settable(L, -3);  /* metatable.__index = metatable */
    
    // регистрируем в метатаблице методы zip_writer
    luaL_register(L, NULL, miniz_zip_writer_methods);
    
    // регистрируем функции библиотеки
    luaL_register(L, "lmz", miniz_functions);

    return 1;
}
